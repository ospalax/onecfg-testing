# onecfg-testing

Simple testing framework for OpenNebula's onescape/onecfg configuration migratin tool.

## Usage

**You will need [`docker`](https://www.docker.com) and scripts here expect to be able running docker command directly.**

1. `git clone https://github.com/ospalax/onecfg-testing.git`
1. `cd onecfg-testing`
1. `./run.sh --help`
1. `./run.sh init tests/centos7-one5.4/`
1. `./run.sh diff tests/centos7-one5.4/ test1.patch`
1. `./run.sh test tests/centos7-one5.4/ test1.patch`

## Description

### Test directory

Firstly you must have created directory with `build.env` in it. An example is included in this repo:

```
./tests/centos7-one5.4/
```

The name in this case helps to designate the base system and OpenNebula's version but the name can be anything - the only function it has is that it serves as a docker image tag...

### build.env

`build.env` contains a few environment variables to direct image building and upgrade. It will be sourced into the shell script - so it should be a valid shell - don't abuse this unless you know what you are doing...

It should contain these variables:

```
# base system
DOCKER_BASE=
DOCKER_TAG=

# initial opennebula system (FROM which we do upgrade)
ONE_VERSION=

# or instead use this repo for the initial version
OPENNEBULA_REPO_URL=

# updated opennebula system (TO which we do upgrade)
UPDATED_ONE_VERSION=

# or instead an opennebula repo with the updated version
UPDATED_OPENNEBULA_REPO_URL=

# onescape repo (as of now an explicit repo is mandatory - onescape is still WIP)
ONESCAPE_REPO_URL=
```

### Options

- `init` extracts `/etc/one` config dir from the image to the test directory (`one-conf`) so the user can edit it
- `diff` creates a patch file based on the changes in `one-conf` and the fresh one in the image
- `test` applies the patch and tries to do upgrade - uninteractively
- `run` does almost the same but stops before updating OpenNebula packages and upgrading config with `onecfg`

### onecfg

**DISCLAIMER**: I am not the `onescape/onecfg` developer - this repo will not fix any problems with it - it serves only as a set of tools to help to test it systematically.

You can play with config upgrade like this:

```
% ./run.sh run tests/centos7-one5.4/ test2.patch
% bash
% yum -y update
% onecfg upgrade --help # in this test2 example a simple upgrade does not work
% onecfg upgrade --modes skip # also does not work
```

