_btrbk_init_cmds()
{
  # set $cmds to an array of the commands so far
  #
  # for example, for this command:
  #
  #     btrbk -v list config
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
}

_btrbk()
{
  local cur prev words cword split
  _init_completion -s || return

  case "$prev" in
    '-c' | '--config')
      _filedir
      return
      ;;
    '--exclude')
      return
      ;;
    '-l' | '--loglevel')
      COMPREPLY=($(compgen -W 'error warn info debug trace' -- "$cur"))
      return
      ;;
    '--format')
      COMPREPLY=($(compgen -W 'table long raw' -- "$cur"))
      return
      ;;
    '--lockfile')
      _filedir
      return
      ;;
    '--override')
      return
      ;;
  esac

  $split && return

  local cmds
  _btrbk_init_cmds

  case "${cmds[0]}" in
    'archive')
      # <source>
      if [[ ! -v 'cmds[1]' ]]; then
        _filedir -d
        return
      fi
      # <target>
      if [[ ! -v 'cmds[2]' ]]; then
        _filedir -d
        return
      fi
      # [--raw]
      if [[ $cur == -* ]]; then
        COMPREPLY=($(compgen -W '--raw' -- "$cur"))
        return
      fi
      ;;
    'list')
      if [[ ! -v 'cmds[1]' ]]; then
        COMPREPLY=($(compgen -W 'backups snapshots latest config source volume target' -- "$cur"))
        return
      fi
      ;;
    'origin')
      # <subvolume>
      if [[ ! -v 'cmds[1]' ]]; then
        _filedir -d
        return
      fi
      ;;
    'ls')
      # <path>|<url>...
      _filedir -d
      return
      ;;
  esac

  if [[ $cur == -* ]]; then
    # only complete options before commands
    if [[ ! -v 'cmds[0]' ]]; then
      COMPREPLY=($(compgen -W '$(_parse_help "$1")' -- "$cur"))
      [[ $COMPREPLY == *= ]] && compopt -o nospace
      return
    fi
  else
    if [[ ! -v 'cmds[0]' ]]; then
      COMPREPLY=($(compgen -W 'run dryrun snapshot resume prune archive clean stats list usage origin diff ls' -- "$cur"))
      return
    fi
  fi
} && complete -F _btrbk btrbk

_lsbtr()
{
  local cur prev words cword split
  _init_completion -s || return

  case "$prev" in
    '-c' | '--config')
      _filedir
      return
      ;;
    '--override')
      return
      ;;
  esac

  $split && return

  if [[ $cur == -* ]]; then
    COMPREPLY=($(compgen -W '$(_parse_help "$1")' -- "$cur"))
    [[ $COMPREPLY == *= ]] && compopt -o nospace
    return
  else
    # <path>|<url>...
    _filedir -d
    return
  fi
} && complete -F _lsbtr lsbtr

# ex: filetype=bash
