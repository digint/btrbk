_btrbk()
{
  local cur prev words cword split
  _init_completion -s || return

  $split && return

  if [[ $cur == -* ]]; then
    COMPREPLY=($(compgen -W '$(_parse_help "$1")' -- "$cur"))
    [[ $COMPREPLY == *= ]] && compopt -o nospace
  fi
} && complete -F _btrbk btrbk

# ex: filetype=bash
