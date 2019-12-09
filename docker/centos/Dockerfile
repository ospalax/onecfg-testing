#
# Copyright (2019) Petr Ospalý <petr@ospalax.cz>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

ARG DOCKER_BASE
ARG DOCKER_TAG

FROM ${DOCKER_BASE:-centos}:${DOCKER_TAG:-centos7}
LABEL maintainer="Petr Ospalý (osp) <petr@ospalax.cz>"

# update first to cut the build time and safe a little of space...
RUN yum -y update && \
    yum -y install epel-release && \
    yum clean all

# build args (with defaults)
ARG ONE_VERSION
ARG OPENNEBULA_REPO_URL
ARG ONESCAPE_REPO_URL

ENV ONE_VERSION "${ONE_VERSION:-5.4}"
ENV OPENNEBULA_REPO_URL "${OPENNEBULA_REPO_URL:-https://downloads.opennebula.org/repo/${ONE_VERSION}/CentOS/7/\$basearch}"

# create opennebula repo file
RUN { \
    echo "[opennebula]" ; \
    echo "name=opennebula" ; \
    echo "baseurl=${OPENNEBULA_REPO_URL}" ; \
    echo "enabled=1" ; \
    echo "gpgkey=https://downloads.opennebula.org/repo/repo.key" ; \
    echo "gpgcheck=1" ; \
    echo "#repo_gpgcheck=1" ; \
    } > /etc/yum.repos.d/opennebula.repo

# create onescape repo file
RUN { \
    echo "[onescape]" ; \
    echo "name=onescape" ; \
    echo "baseurl=${ONESCAPE_REPO_URL}" ; \
    echo "enabled=1" ; \
    echo "gpgkey=https://downloads.opennebula.org/repo/repo.key" ; \
    echo "gpgcheck=1" ; \
    echo "#repo_gpgcheck=1" ; \
    } > /etc/yum.repos.d/onescape.repo

# install opennebula and onescape
RUN yum -y install \
        opennebula-server \
        opennebula-sunstone \
        opennebula-ruby \
        opennebula-gate \
        opennebula-flow \
        onescape \
    && \
    yum clean all

# save configuration from fresh installation
RUN cd /etc && tar -cvzf /one-conf-distribution.tgz one

#
# at this point we have a clean fresh installation
#

# entrypoint
COPY centos/entrypoint-functions.sh /
COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]

