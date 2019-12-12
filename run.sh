#!/bin/sh

#
# Copyright (2019) Petr Ospalý <petr@ospalax.cz>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

set -e

#
# globals
#

DOCKER_IMAGE=onecfg-testing

#
# functions
#

help()
{
    cat <<EOF
USAGE:
    ${0} [-h|--help|help]
        This help

    ${0} init <test-dir>
        It will copy the untouched configuration from the current build into
        the 'test-dir/one-conf' directory (so we can start to edit it and
        create a patch from it later).

    ${0} diff <test-dir> <patch>
        It will compare the edited config dir in 'test-dir/one-conf' and the
        configuration in the current build to create the 'test-dir/patch'.

    ${0} test|run <test-dir> <patch>
        It will build and run container based on the 'build.env' inside the
        'test-dir' and with a configuration in a patch: 'test-dir/patch'.

        'test-dir' will also serve as a docker tag for '${DOCKER_IMAGE}'.

        If the 'run' argument is used then it drops you inside the container
        with updated opennebula repo but before opennebula update is started
        and before onecfg upgrade is executed (configuration was already
        patched) - it is intended for an interactive testing.

        Otherwise with the 'test' argument (non-interactively) the container
        starts running and it will automatically update opennebula to the
        version set in 'build.env', following by 'onecfg upgrade' and printing
        diff of the initial (tested) config directory and the resulted one.
        Test output is saved into a log: 'test-dir/log/patch.log'.

EXAMPLE:
    % ${0} init ./tests/centos7-one5.4
        This copies the OpenNebula's 5.4 configuration from the CentOS7
        container into: ./tests/centos7-one-5.4/one-conf

    % ${0} diff ./tests/centos7-one5.4 test1.patch
        This creates a patch file which can be used in the next step.

        Here we expect that you made some changes in:
        ./tests/centos7-one-5.4/one-conf

    % ${0} test ./tests/centos7-one5.4 test1.patch
        Now we finally update OpenNebula and test onecfg upgrade. The output
        of test is shown in the stdout and also stored in:
        ./tests/centos7-one-5.4/log/test1.patch.log

    % ${0} run ./tests/centos7-one5.4 test1.patch
        By using this command we can do update and onecfg upgrade (or anything
        else) manually. The configuration was already patched and OpenNebula's
        repo file updated (but update of packages was not yet done).

NOTES:
    Test directory must contain a 'build.env' file so the image can be build.
    The content of the file are a few environment variables:

        DOCKER_BASE: must be equal to something under 'docker' directory
        DOCKER_TAG: together with DOCKER_BASE must be a valid docker image
        ONE_VERSION: OpenNebula's (initial) version which will be installed
        OPENNEBULA_REPO_URL: Or use some specific repo
        UPDATED_ONE_VERSION: This is the version to which we will update
        UPDATED_OPENNEBULA_REPO_URL: Or again by using some specific repo
        ONESCAPE_REPO_URL: This must be set to onescape repo (not released yet)

    For an example look into some test dirs under 'tests'.

EOF
}

# arg: <test-dir>
return_docker_image()
{
    printf "${DOCKER_IMAGE}:$(basename ${1})"
}

# arg: <docker>
build_docker()
{
    _docker_image="$1"

    set -x
    docker build \
        --network=host \
        --build-arg DOCKER_BASE="${DOCKER_BASE}" \
        --build-arg DOCKER_TAG="${DOCKER_TAG}" \
        --build-arg ONE_VERSION="${ONE_VERSION}" \
        --build-arg OPENNEBULA_REPO_URL="${OPENNEBULA_REPO_URL}" \
        --build-arg UPDATED_ONE_VERSION="${UPDATED_ONE_VERSION}" \
        --build-arg UPDATED_OPENNEBULA_REPO_URL="${UPDATED_OPENNEBULA_REPO_URL}" \
        --build-arg ONESCAPE_REPO_URL="${ONESCAPE_REPO_URL}" \
        -t "${_docker_image}" \
        -f "docker/${DOCKER_BASE}/Dockerfile" \
        "docker/"
    set +x
}

# args: <test-dir> [<dirname>]
run_init()
{
    _test_dir="$1"
    _one_conf="${2:-one-conf}"

    set -x
    _container=$(docker create $(return_docker_image "${_test_dir}"))

    docker cp -a ${_container}:/one-conf-distribution.tgz "$_test_dir"
    docker rm -f ${_container}

    rm -rf "${_test_dir}/${_one_conf}"
    mkdir -p "${_test_dir}/${_one_conf}"
    tar -C "${_test_dir}/${_one_conf}" --strip 1 \
        -xf "${_test_dir}/one-conf-distribution.tgz"
    set +x
}

# arg: <test-dir> <patch>
run_diff()
{
    _test_dir="$1"
    _test_patch="$2"

    if ! [ -d "${_test_dir}/one-conf" ] ; then
        echo "ERROR: missing '${_test_dir}/one-conf' directory - did you init?" >&2
        exit 1
    fi

    # extract configuration again so we can make a patch
    run_init "$_test_dir" one-conf-distribution

    set -x
    cd "$_test_dir"
    # BEWARE: diff returns non-zero value when files are different...
    diff -Naur --color one-conf-distribution one-conf | tee "$_test_patch"
    rm -rf one-conf-distribution
    cd -
    set +x
}

# arg: <test-dir> <patch>
run_test()
{
    _action="$1"
    _test_dir=$(realpath "$2")
    _test_patch="$3"

    if ! [ -f "${_test_dir}/${_test_patch}" ] ; then
        echo "ERROR: missing patch '${_test_dir}/${_test_patch}'" >&2
        exit 1
    fi

    set -x
    mkdir -p "${_test_dir}/log"
    touch "${_test_dir}/log/${_test_patch}.log"
    touch "${_test_dir}/log/${_test_patch}.diff"
    docker run --rm -it \
        --network=host \
        -e UPDATED_ONE_VERSION="$UPDATED_ONE_VERSION" \
        -e UPDATED_OPENNEBULA_REPO_URL="$UPDATED_OPENNEBULA_REPO_URL" \
        -v "${_test_dir}/${_test_patch}:/test.patch:ro" \
        -v "${_test_dir}/log/${_test_patch}.log:/one-conf-test.log" \
        -v "${_test_dir}/log/${_test_patch}.diff:/one-conf-test.diff" \
        $(return_docker_image "${_test_dir}") \
        "$_action"
    set +x
}

#
# arguments
#

if [ -z "$1" ] ; then
    help
    exit 0
fi

ACTION=
TEST_DIR=
TEST_PATCH=
case "$1" in
    -h|--help|help)
        help
        exit 0
        ;;
    init)
        ACTION=init
        if [ -z "$2" ] ; then
            echo "ERROR: missing test directory argument" >&2
            exit 1
        else
            TEST_DIR="$2"
        fi
        ;;
    diff|test|run)
        ACTION="$1"
        if [ -z "$2" ] ; then
            echo "ERROR: missing test directory argument" >&2
            exit 1
        else
            TEST_DIR="$2"
        fi
        if [ -z "$3" ] ; then
            echo "ERROR: missing the name of the patch" >&2
            exit 1
        else
            TEST_PATCH="$3"
        fi
        ;;
    *)
        echo "ERROR: unknown action argument: ${1}" >&2
        exit 1
        ;;
esac

#
# sanity checks
#

echo "INFO: check if tools are present..."
for tool in tar realpath diff patch docker tee ; do
    which ${tool} || exit 1
done

# check if test dir exists
if [ -n "$TEST_DIR" ] ; then
    if echo "$TEST_DIR" | grep -q '[[:space:]]' ; then
        echo "ERROR: '${TEST_DIR}' contains a whitespace characters" >&2
        exit 1
    fi

    if ! [ -d "$TEST_DIR" ]; then
        echo "ERROR: '${TEST_DIR}' must be a directory" >&2
        exit 1
    else
        # check if build.env exists
        if ! { [ -f "$TEST_DIR"/build.env ] && [ -s "$TEST_DIR"/build.env ] ; } ; then
            echo "ERROR: '${TEST_DIR}/build.env' does not exist or is empty" >&2
            exit 1
        fi

        # source it
        . "$TEST_DIR"/build.env

        # check if all was provided...
        for _var in \
            DOCKER_BASE \
            DOCKER_TAG \
            ONESCAPE_REPO_URL \
        ; do
            _value=$(eval echo "\$${_var}")
            if [ -z "$_value" ] ; then
                echo "ERROR: missing '${_var}' in '${TEST_DIR}/build.env'" >&2
                exit 1
            fi
        done
        if [ -z "$ONE_VERSION" ] && [ -z "$OPENNEBULA_REPO_URL" ] ; then
            echo "ERROR: missing 'ONE_VERSION' or 'OPENNEBULA_REPO_URL' in '${TEST_DIR}/build.env'" >&2
            exit 1
        fi
        if [ -z "$UPDATED_ONE_VERSION" ] && [ -z "$UPDATED_OPENNEBULA_REPO_URL" ] ; then
            echo "ERROR: missing 'UPDATED_ONE_VERSION' or 'UPDATED_OPENNEBULA_REPO_URL' in '${TEST_DIR}/build.env'" >&2
            exit 1
        fi
    fi
else
    # this should be checked during argument parsing
    echo "ERROR: missing test directory argument" >&2
    exit 1
fi

#
# main
#

# let's first build the image - it is needed for all actions...
build_docker "$(return_docker_image ${TEST_DIR})"

# execute action
case "$ACTION" in
    init)
        echo "INFO: initialize '${TEST_DIR}'"
        run_init "$TEST_DIR"
        ;;
    diff)
        echo "INFO: create patch '${TEST_DIR}/${TEST_PATCH}'"
        run_diff "$TEST_DIR" "$TEST_PATCH"
        ;;
    test|run)
        echo "INFO: run test '${TEST_DIR}/${TEST_PATCH}'"
        run_test "$ACTION" "$TEST_DIR" "$TEST_PATCH"
        ;;
esac

exit 0

