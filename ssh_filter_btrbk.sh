#!/bin/bash

set -e
set -u

export PATH=/sbin:/bin:/usr/sbin:/usr/bin

enable_log=
restrict_path_list=
allow_list=
allow_exact_list=
allow_rate_limit=1
allow_stream_buffer=1
allow_compress=1
compress_list="gzip|pigz|bzip2|pbzip2|xz|lzop|lz4"

# note that the backslash is NOT a metacharacter in a POSIX bracket expression!
option_match='-[a-zA-Z0-9=-]+'   # matches short as well as long options
file_match='[0-9a-zA-Z_@+./-]*'  # matches file path (equal to $file_match in btrbk)

log_cmd()
{
    if [[ -n "$enable_log" ]]; then
        logger -p $1 -t ssh_filter_btrbk.sh "$2 (Name: ${LOGNAME:-<unknown>}; Remote: ${SSH_CLIENT:-<unknown>})${3:+: $3}: $SSH_ORIGINAL_COMMAND"
    fi
}

allow_cmd()
{
    allow_list="${allow_list}|$1"
}

allow_exact_cmd()
{
    allow_exact_list="${allow_exact_list}|$1"
}

reject_and_die()
{
    local reason=$1
    log_cmd "auth.err" "btrbk REJECT" "$reason"
    echo "ERROR: ssh_filter_btrbk.sh: ssh command rejected: $reason: $SSH_ORIGINAL_COMMAND" 1>&2
    exit 255
}

run_cmd()
{
    log_cmd "auth.info" "btrbk ACCEPT"
    eval " $SSH_ORIGINAL_COMMAND"
}

reject_filtered_cmd()
{
    if [[ -n "$restrict_path_list" ]]; then
	# match any of restrict_path_list with or without trailing slash,
	# or any file/directory (matching file_match) below restrict_path
	path_match="(${restrict_path_list})(/${file_match})?"
    else
	# match any absolute file/directory (matching file_match)
	path_match="/${file_match}"
    fi

    if [[ -n "$allow_compress" ]]; then
        decompress_match="(${compress_list}) -d -c( -[pT][0-9]+)?"
        compress_match="(${compress_list}) -c( -[0-9])?( -[pT][0-9]+)?"
    else
        decompress_match=
        compress_match=
    fi

    # rate_limit_remote and stream_buffer_remote use combined
    # "mbuffer" as of btrbk-0.29.0
    if [[ -n "$allow_stream_buffer" ]] || [[ -n "$allow_rate_limit" ]]; then
        mbuffer_match="mbuffer -v 1 -q( -s [0-9]+[kmgKMG]?)?( -m [0-9]+[kmgKMG]?)?( -[rR] [0-9]+[kmgtKMGT]?)?"
    else
        mbuffer_match=
    fi

    # allow multiple paths (e.g. "btrfs subvolume snapshot <src> <dst>")
    allow_cmd_match="(${allow_list})( ${option_match})*( ${path_match})+"
    stream_in_match="(${decompress_match} \| )?(${mbuffer_match} \| )?"
    stream_out_match="( \| ${mbuffer_match})?( \| ${compress_match}$)?"

    allow_stream_match="^${stream_in_match}${allow_cmd_match}${stream_out_match}"
    if [[ $SSH_ORIGINAL_COMMAND =~ $allow_stream_match ]] ; then
        return 0
    fi

    exact_cmd_match="^${allow_exact_list}$";
    if [[ $SSH_ORIGINAL_COMMAND =~ $exact_cmd_match ]] ; then
        return 0
    fi

    reject_and_die "disallowed command${restrict_path_list:+ (restrict-path: \"${restrict_path_list//|/\", \"}\")}"
}


# check for "--sudo" option before processing other options
sudo_prefix=
for key; do
    [[ "$key" == "--sudo" ]] && sudo_prefix="sudo -n "
done

while [[ "$#" -ge 1 ]]; do
    key="$1"

    case $key in
      -l|--log)
          enable_log=1
          ;;

      --sudo)
          # already processed above
          ;;

      -p|--restrict-path)
          restrict_path_list="${restrict_path_list}|${2%/}"  # add to list while removing trailing slash
          shift # past argument
          ;;

      -s|--source)
          allow_cmd "${sudo_prefix}btrfs subvolume snapshot"
          allow_cmd "${sudo_prefix}btrfs send"
          ;;

      -t|--target)
          allow_cmd "${sudo_prefix}btrfs receive"
          allow_cmd "${sudo_prefix}mkdir"
          ;;

      -c|--compress)
          # deprecated option, compression is always allowed
          ;;

      -d|--delete)
          allow_cmd "${sudo_prefix}btrfs subvolume delete"
          ;;

      -i|--info)
          allow_cmd "${sudo_prefix}btrfs subvolume find-new"
          allow_cmd "${sudo_prefix}btrfs filesystem usage"
          ;;

      --snapshot)
          allow_cmd "${sudo_prefix}btrfs subvolume snapshot"
          ;;

      --send)
          allow_cmd "${sudo_prefix}btrfs send"
          ;;

      --receive)
          allow_cmd "${sudo_prefix}btrfs receive"
          ;;

      *)
          echo "ERROR: ssh_filter_btrbk.sh: failed to parse command line option: $key" 1>&2
          exit 255
          ;;
    esac
    shift
done

# NOTE: subvolume queries are NOT affected by "--restrict-path":
# btrbk also calls show/list on the mount point of the subvolume
allow_exact_cmd "${sudo_prefix}btrfs subvolume (show|list)( ${option_match})* ${file_match}";
allow_cmd "${sudo_prefix}readlink"                    # resolve symlink
allow_exact_cmd "${sudo_prefix}test -d ${file_match}" # check directory (only for compat=busybox)
allow_exact_cmd "cat /proc/self/mountinfo"            # resolve mountpoints
allow_exact_cmd "cat /proc/self/mounts"               # legacy, for btrbk < 0.27.0

# remove leading "|" on alternation lists
allow_list=${allow_list#\|}
allow_exact_list=${allow_exact_list#\|}
restrict_path_list=${restrict_path_list#\|}

case "$SSH_ORIGINAL_COMMAND" in
    *\.\./*)  reject_and_die 'directory traversal'  ;;
    *\$*)     reject_and_die 'unsafe character "$"' ;;
    *\&*)     reject_and_die 'unsafe character "&"' ;;
    *\(*)     reject_and_die 'unsafe character "("' ;;
    *\{*)     reject_and_die 'unsafe character "{"' ;;
    *\;*)     reject_and_die 'unsafe character ";"' ;;
    *\<*)     reject_and_die 'unsafe character "<"' ;;
    *\>*)     reject_and_die 'unsafe character ">"' ;;
    *\`*)     reject_and_die 'unsafe character "`"' ;;
    *\|*)     [[ -n "$allow_compress" ]] || [[ -n "$allow_rate_limit" ]] || [[ -n "$allow_stream_buffer" ]] || reject_and_die 'unsafe character "|"' ;;
esac

reject_filtered_cmd
run_cmd
