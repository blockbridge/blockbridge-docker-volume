#!/bin/bash
##############################################################################
# Attempt to disable the host iscsid in order to use iscsid as a container.
# This script detects what commands are available and then runs the disable
# commands. It should work on RHEL7/CentOS7, RHEL6/CentOS6, Ubuntu 14.04.
##############################################################################
SYSTEMCTL="/usr/bin/systemctl"
CHKCONFIG="/sbin/chkconfig"
UPDATERCD="/usr/sbin/update-rc.d"

# disable via systemd
function disable_systemd()
{
    sudo $SYSTEMCTL disable iscsid.socket
    sudo $SYSTEMCTL disable iscsiuio.socket
    sudo $SYSTEMCTL disable iscsid.service
    sudo $SYSTEMCTL stop iscsid.socket
    sudo $SYSTEMCTL stop iscsiuio.socket
    sudo $SYSTEMCTL stop iscsid.service
}

# disable via chkconfig
function disable_chkconfig()
{
    sudo service iscsi stop
    sudo service iscsid stop
    sudo $CHKCONFIG iscsi off
    sudo $CHKCONFIG iscsid off
    sudo $CHKCONFIG --del iscsi
    sudo $CHKCONFIG --del iscsid
}

# disable via rc.d
function disable_rcd()
{
    sudo $UPDATERCD open-iscsi disable
    sudo service open-iscsi stop
}

# find best way to disable and disable it
if [ -e $SYSTEMCTL ]; then
    disable_systemd

elif [ -e $CHKCONFIG ]; then
    disable_chkconfig

elif [ -e $UPDATERCD ]; then
    disable_rcd
fi
