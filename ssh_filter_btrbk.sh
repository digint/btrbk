#!/bin/sh

set -e
set -u

export PATH=/sbin:/bin:/usr/sbin:/usr/bin

enable_log=
if [ "$#" -ge 1 ] && [ "$1" = "-l" ]; then
    enable_log=1
fi

log_cmd()
{
    if [ -n "$enable_log" ]; then
        logger -p $1 -t ssh_filter_btrbk.sh "$2 (Name: ${LOGNAME:-<unknown>}; Remote: ${SSH_CLIENT:-<unknown>}): $SSH_ORIGINAL_COMMAND"
    fi
}

reject_and_die()
{
    log_cmd "auth.err" "btrbk REJECT"
    /bin/echo "ERROR: ssh command rejected" 1>&2
    exit 1
}

run_cmd()
{
    log_cmd "auth.info" "btrbk ACCEPT"
    $SSH_ORIGINAL_COMMAND
}

case "$SSH_ORIGINAL_COMMAND" in
    *\$*) reject_and_die ;;
    *\&*) reject_and_die ;;
    *\(*) reject_and_die ;;
    *\{*) reject_and_die ;;
    *\;*) reject_and_die ;;
    *\<*) reject_and_die ;;
    *\>*) reject_and_die ;;
    *\`*) reject_and_die ;;
    *\|*) reject_and_die ;;
    btrfs\ subvolume\ show\ *)      run_cmd ;;   # mandatory
    btrfs\ subvolume\ list\ *)      run_cmd ;;   # mandatory
    btrfs\ subvolume\ snapshot\ *)  run_cmd ;;   # mandatory if this host is backup source
    btrfs\ send\ *)                 run_cmd ;;   # mandatory if this host is backup source
    btrfs\ receive\ *)              run_cmd ;;   # mandatory if this host is backup target
    btrfs\ subvolume\ delete\ *)    run_cmd ;;   # mandatory if scheduling is active
    btrfs\ subvolume\ find-new\ *)  run_cmd ;;   # needed for "btrbk diff"
    btrfs\ filesystem\ usage\ *)    run_cmd ;;   # needed for "btrbk info"
    *) reject_and_die ;;
esac
