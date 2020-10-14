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

  if [[ $cur == -* ]]; then
    COMPREPLY=($(compgen -W '$(_parse_help "$1")' -- "$cur"))
    [[ $COMPREPLY == *= ]] && compopt -o nospace
  fi
} && complete -F _btrbk btrbk

# ex: filetype=bash
