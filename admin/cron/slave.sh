#!/bin/bash

cd `dirname $0`/../..
eval `./admin/ShowDBDefs`
. ./admin/config.sh

X=${SLAVE_LOG:=$MB_SERVER_ROOT/slave.log}
X=${LOGROTATE:=/usr/sbin/logrotate --state $MB_SERVER_ROOT/.logrotate-state}

./admin/replication/LoadReplicationChanges >> $SLAVE_LOG 2>&1 || {
    RC=$?
    echo `date`" : LoadReplicationChanges failed (rc=$RC) - see $SLAVE_LOG"
}

$LOGROTATE /dev/stdin <<EOF
$SLAVE_LOG {
    daily
    rotate 30
}
EOF

# eof
