_btrbk_init_cmds()
{
  # set $cmds to an array of the commands so far
  #
  # for example, for this command:
  #
  #     btrbk -v list config --long
  #
  # then $cmds is:
  #
  #     cmds=(list config)
  #
  cmds=()

  local i
  for ((i = 1; i < cword; i++)); do
    [[ ${words[i]} != -* ]] && cmds+=(${words[i]})
  done

  return 0
}

_btrbk()
{
  local cur prev words cword split cmds
  _init_completion -s || return
  _btrbk_init_cmds || return

  case "$prev" in
    '-c' | '--config')
      _filedir
      ;;
    '--exclude')
      ;;
    '-l' | '--loglevel')
      COMPREPLY=($(compgen -W 'error warn info debug trace' -- "$cur"))
      ;;
    '--format')
      COMPREPLY=($(compgen -W 'table long raw' -- "$cur"))
      ;;
    '--lockfile')
      _filedir
      ;;
    '--override')
      ;;
  esac
  $split && return

  if [[ $cur == -* ]]; then
    COMPREPLY=($(compgen -W '$(_parse_help "$1")' -- "$cur"))
    [[ $COMPREPLY == *= ]] && compopt -o nospace
  else
    if [[ ! -v 'cmds[0]' ]]; then
      COMPREPLY=($(compgen -W 'run dryrun snapshot resume prune archive clean stats list usage origin diff extents ls' -- "$cur"))
    fi
  fi

  case "${cmds[0]}" in
    'archive')
      # <source>
      if [[ ! -v 'cmds[1]' ]]; then
        _filedir -d
      # <target>
      elif [[ ! -v 'cmds[2]' ]]; then
        _filedir -d
      # [--raw]
      elif [[ $cur == -* ]]; then
        COMPREPLY+=($(compgen -W '--raw' -- "$cur"))
      fi
      ;;
    'list')
      if [[ ! -v 'cmds[1]' ]]; then
        COMPREPLY=($(compgen -W 'all snapshots backups latest config source volume target' -- "$cur"))
      fi
      ;;
    'origin')
      # <subvolume>
      if [[ ! -v 'cmds[1]' ]]; then
        _filedir -d
      fi
      ;;
    'ls')
      # <path>|<url>...
      _filedir -d
      ;;
    'extents')
      # [diff] <path>... [exclusive] <path>...
      if [[ ! -v 'cmds[1]' ]]; then
          COMPREPLY+=($(compgen -W 'diff' -- "$cur"))
      elif [[ ! ${cmds[*]} =~ (^|[[:space:]])"exclusive"($|[[:space:]]) ]]; then
          COMPREPLY+=($(compgen -W 'exclusive' -- "$cur"))
      fi
      _filedir -d
      ;;
  esac
} && complete -F _btrbk btrbk

_lsbtr()
{
  local cur prev words cword split
  _init_completion -s || return

  case "$prev" in
    '-c' | '--config')
      _filedir
      ;;
    '--override')
      ;;
  esac
  $split && return

  if [[ $cur == -* ]]; then
    COMPREPLY=($(compgen -W '$(_parse_help "$1")' -- "$cur"))
    [[ $COMPREPLY == *= ]] && compopt -o nospace
  else
    # <path>|<url>...
    _filedir -d
  fi
} && complete -F _lsbtr lsbtr

# ex: filetype=bash
