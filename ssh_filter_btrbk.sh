#!/bin/sh


# initialise and sanitise the shell execution environment
unset -v IFS
export LC_ALL=C
export PATH='/usr/bin:/bin'

set -e -u

enable_log=
restrict_path_list=
allow_list=
allow_exact_list=
allow_rate_limit=1
allow_stream_buffer=1
allow_compress=1
compress_list='gzip|pigz|bzip2|pbzip2|bzip3|xz|lzop|lz4|zstd'

# note that the backslash is NOT a metacharacter in a POSIX bracket expression!
option_match='-[a-zA-Z0-9=-]+'   # matches short as well as long options
file_match_sane='/[0-9a-zA-Z_@+./-]*' # matches file path (equal to ${file_match} in btrbk < 0.32.0)
file_match="/[^']*" # btrbk >= 0.32.0 quotes file arguments: match all but single quote
file_arg_match="('${file_match}'|${file_match_sane})" # support btrbk < 0.32.0

print_normalised_pathname()
{
    # Normalises a pathname given via the positional parameter #1 as follows:
    # * Folds any >=3 leading `/` into 1.
    #   POSIX specifies that implementations may treat exactly 2 leading `//`
    #   specially and therefore such are not folded here.
    # * Folds any >=2 non-leading `/` into 1.
    # * Strips any trailing `/`.

    local pathname="$1"

    printf '%s' "${pathname}" | sed -E 's%^///+%/%; s%(.)//+%\1/%g; s%/+$%%'
}

log_cmd()
{
    local priority="$1"
    local authorisation_decision="$2"
    local reason="${3-}"

    if [ -n "${enable_log}" ]; then
        logger -p "${priority}" -t ssh_filter_btrbk.sh "${authorisation_decision} (Name: ${LOGNAME:-<unknown>}; Connection: ${SSH_CONNECTION:-<unknown>})${reason:+: ${reason}}: ${SSH_ORIGINAL_COMMAND}"
    fi
}

allow_cmd()
{
    local cmd="$1"

    allow_list="${allow_list}|${cmd}"
}

allow_exact_cmd()
{
    local cmd="$1"

    allow_exact_list="${allow_exact_list}|${cmd}"
}

reject_and_die()
{
    local reason="$1"

    log_cmd 'auth.err' 'btrbk REJECT' "${reason}"
    printf 'ERROR: ssh_filter_btrbk.sh: ssh command rejected: %s: %s\n' "${reason}" "${SSH_ORIGINAL_COMMAND}" >&2
    exit 1
}

run_cmd()
{
    log_cmd 'auth.info' 'btrbk ACCEPT'
    eval " ${SSH_ORIGINAL_COMMAND}"
}

reject_filtered_cmd()
{
    if [ -n "${restrict_path_list}" ]; then
	# match any of restrict_path_list,
	# or any file/directory (matching file_match) below restrict_path
	path_match="'(${restrict_path_list})(${file_match})?'"
	path_match_legacy="(${restrict_path_list})(${file_match_sane})?"
    else
	# match any absolute file/directory (matching file_match)
	path_match="'${file_match}'"
	path_match_legacy="${file_match_sane}"
    fi
    # btrbk >= 0.32.0 quotes files, allow both (legacy)
    path_match="(${path_match}|${path_match_legacy})"

    if [ -n "${allow_compress}" ]; then
        decompress_match="(${compress_list}) -d -c( -[pT][0-9]+)?"
        compress_match="(${compress_list}) -c( -[0-9])?( -[pT][0-9]+)?"
    else
        decompress_match=
        compress_match=
    fi

    # rate_limit_remote and stream_buffer_remote use combined
    # "mbuffer" as of btrbk-0.29.0
    if [ -n "${allow_stream_buffer}" ] || [ -n "${allow_rate_limit}" ]; then
        mbuffer_match='mbuffer -v 1 -q( -s [0-9]+[kmgKMG]?)?( -m [0-9]+[kmgKMG]?)?( -[rR] [0-9]+[kmgtKMGT]?)?'
    else
        mbuffer_match=
    fi

    # allow multiple paths (e.g. "btrfs subvolume snapshot <src> <dst>")
    allow_cmd_match="(${allow_list})( ${option_match})*( ${path_match})+"
    stream_in_match="(${decompress_match} \| )?(${mbuffer_match} \| )?"
    stream_out_match="( \| ${mbuffer_match})?( \| ${compress_match}$)?"

    # `grep`’s `-q`-option is not used as it may cause an exit status of `0` even
    # when an error occurred.

    allow_stream_match="^${stream_in_match}${allow_cmd_match}${stream_out_match}"
    if printf '%s' "${SSH_ORIGINAL_COMMAND}" | grep -E "${allow_stream_match}" >/dev/null 2>/dev/null; then
        return 0
    fi

    exact_cmd_match="^(${allow_exact_list})$";
    if printf '%s' "${SSH_ORIGINAL_COMMAND}" | grep -E "${exact_cmd_match}" >/dev/null 2>/dev/null; then
        return 0
    fi

    local formatted_restrict_path_list="$(printf '%s' "${restrict_path_list}" | sed 's/|/", "/g')"
    reject_and_die "disallowed command${restrict_path_list:+ (restrict-path: \"${formatted_restrict_path_list}\")}"
}


# check for "--sudo" option before processing other options
sudo_prefix=
for key in "$@"; do
    if [ "${key}" = '--sudo' ]; then
        sudo_prefix='sudo -n '
    fi
    if [ "${key}" = '--doas' ]; then
        sudo_prefix='doas -n '
    fi
done

while [ "$#" -ge 1 ]; do
    key="$1"

    case "${key}" in
      -l|--log)
          enable_log=1
          ;;

      --sudo|--doas)
          # already processed above
          ;;

      -p|--restrict-path)
          restrict_path_list="${restrict_path_list}|$(print_normalised_pathname "$2")"
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
          printf 'ERROR: ssh_filter_btrbk.sh: failed to parse command line option: %s\n' "${key}" >&2
          exit 2
          ;;
    esac
    shift
done

# NOTE: subvolume queries are NOT affected by "--restrict-path":
# btrbk also calls show/list on the mount point of the subvolume
allow_exact_cmd "${sudo_prefix}btrfs subvolume (show|list)( ${option_match})* ${file_arg_match}";
allow_cmd "${sudo_prefix}readlink"                    # resolve symlink
allow_exact_cmd "${sudo_prefix}test -d ${file_arg_match}" # check directory (only for compat=busybox)
allow_exact_cmd 'cat /proc/self/mountinfo'            # resolve mountpoints
allow_exact_cmd 'cat /proc/self/mounts'               # legacy, for btrbk < 0.27.0

# remove leading "|" on alternation lists
allow_list="${allow_list#\|}"
allow_exact_list="${allow_exact_list#\|}"
restrict_path_list="${restrict_path_list#\|}"

case "${SSH_ORIGINAL_COMMAND}" in
    *\.\./*)  reject_and_die 'directory traversal'  ;;
    *\$*)     reject_and_die 'unsafe character "$"' ;;
    *\&*)     reject_and_die 'unsafe character "&"' ;;
    *\(*)     reject_and_die 'unsafe character "("' ;;
    *\{*)     reject_and_die 'unsafe character "{"' ;;
    *\;*)     reject_and_die 'unsafe character ";"' ;;
    *\<*)     reject_and_die 'unsafe character "<"' ;;
    *\>*)     reject_and_die 'unsafe character ">"' ;;
    *\`*)     reject_and_die 'unsafe character "`"' ;;
    *\|*)     [ -n "${allow_compress}" ] || [ -n "${allow_rate_limit}" ] || [ -n "${allow_stream_buffer}" ] || reject_and_die 'unsafe character "|"' ;;
esac

reject_filtered_cmd
run_cmd
