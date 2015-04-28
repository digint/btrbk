#!/bin/sh

export PATH=

if [ "$1" = "-l" ]; then
    enable_log=1
fi

reject_and_die()
{
    if [ -n "$enable_log" ]; then
        /usr/bin/logger -p auth.err -t ssh_filter_btrbk.sh "$LOGNAME $SSH_CLIENT REJECT: $SSH_ORIGINAL_COMMAND"
    fi
    /bin/echo "ssh command rejected" 1>&2;
    exit 1;
}

run_cmd()
{
    if [ -n "$enable_log" ]; then
        /usr/bin/logger -p auth.info -t ssh_filter_btrbk.sh "$LOGNAME $SSH_CLIENT ALLOW: $SSH_ORIGINAL_COMMAND"
    fi
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
    /sbin/btrfs\ subvolume\ show\ *)      run_cmd ;;   # mandatory
    /sbin/btrfs\ subvolume\ list\ *)      run_cmd ;;   # mandatory
    /sbin/btrfs\ subvolume\ snapshot\ *)  run_cmd ;;   # mandatory if this host is backup source
    /sbin/btrfs\ send\ *)                 run_cmd ;;   # mandatory if this host is backup source
    /sbin/btrfs\ receive\ *)              run_cmd ;;   # mandatory if this host is backup target
    /sbin/btrfs\ subvolume\ delete\ *)    run_cmd ;;   # mandatory if scheduling is active
    /sbin/btrfs\ subvolume\ find-new\ *)  run_cmd ;;   # needed for "btrbk diff"
    /sbin/btrfs\ filesystem\ usage\ *)    run_cmd ;;   # needed for "btrbk info"
    *) reject_and_die ;;
esac
