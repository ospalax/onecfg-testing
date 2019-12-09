#!/bin/sh

#
# Copyright (2019) Petr Ospalý <petr@ospalax.cz>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

update_repo()
{
    echo "INFO: try to update repo"
    if [ -z "$UPDATED_ONE_VERSION" ] && [ -z "$UPDATED_OPENNEBULA_REPO_URL" ] ; then
        echo "WARNING: neither 'UPDATED_ONE_VERSION' or 'UPDATED_OPENNEBULA_REPO_URL' was set" >&2
        return
    fi

    cat > /etc/yum.repos.d/opennebula.repo <<EOF
[opennebula]
name=opennebula
baseurl=${UPDATED_OPENNEBULA_REPO_URL:-https://downloads.opennebula.org/repo/${UPDATED_ONE_VERSION}/CentOS/7/\$basearch}
enabled=1
gpgkey=https://downloads.opennebula.org/repo/repo.key
gpgcheck=1
#repo_gpgcheck=1
EOF
}

update_opennebula()
{
    echo "INFO: update opennebula/system"
    yum -y update
}

fix_problems()
{
    echo "IMPORTANT: FIX: missing patch command"
    yum -y install patch

    echo "IMPORTANT: FIX: ensure that tee command is present"
    yum -y install coreutils
}
