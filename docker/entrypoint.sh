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
# functions
#

. /entrypoint-functions.sh

apply_patch()
{
    echo "INFO: try to patch the configuration with our test"
    set -x
    cat /test.patch | patch -d /etc/one
    set +x
}

copy_patched_config()
{
    echo "INFO: copy patched configuration to /one-conf-test"
    set -x
    cp -a /etc/one /one-conf-test
    set +x
}

update_config()
{
    echo "INFO: run onecfg tool"
    set -x
    onecfg status || true
    onecfg init || true
    onecfg status || true
    onecfg upgrade || true
    set +x
}

check_patch()
{
    echo "INFO: try to reapply the test patch"
    if cat /test.patch | patch -R --dry-run -d /etc/one ; then
        echo "DONE: SUCCESS: test seems to be successfull"
    else
        echo "DONE: UNKNOWN: we cannot validate test - try to explore log and diff"
    fi
}

#
# main
#

fix_problems

case "$1" in
    run)
        update_repo
        apply_patch
        copy_patched_config
        exec sh -l
        ;;
    test)
        update_repo
        apply_patch
        copy_patched_config
        update_opennebula

        {
            update_config 2>&1 ;
            echo "INFO: save diff between initial configuration and the updated" ;
            diff -Naur /one-conf-test /etc/one > /one-conf-test.diff || true;
            check_patch 2>&1 ;
        } | tee /one-conf-test.log
        ;;
    *)
        exec "$@"
        ;;
esac

exit 0
