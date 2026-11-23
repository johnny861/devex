#!/bin/zsh
#
# Pick one value from piped input and print it, pass it to a command, or store it with mise.
#
#   <command> | selectoptions <variable> [--delimiter D] [--index N] [--mise] [<action>]
#
#   az account list ... | selectoptions AZ_ACCOUNT_DEV --delimiter $'\t' --index 1 --mise
#   <command> | selectoptions BRANCH git switch
#   export AWS_PROFILE=$(<command> | selectoptions AWS_PROFILE)
#
# Uses fzf when available, otherwise a numbered `select` menu on the terminal.
# Menu output goes to stderr; the selected value goes to stdout so it can be piped.

selectoptions() {
  local option_type="" delimiter="" index=""
  local use_mise=false show_help=false verbose=false
  local -a items action
  local line opt="" choice opt_val split_items

  # First positional is the target name; the remaining positionals form the action to run
  # with the selected value appended (e.g. `selectoptions BRANCH git switch`).
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--delimiter) delimiter="${2:-}"; shift 2 ;;
      -i|--index)     index="${2:-}";     shift 2 ;;
      -m|--mise)      use_mise=true;      shift ;;
      -h|--help)      show_help=true;     shift ;;
      -v|--verbose)   verbose=true;       shift ;;
      --)
        shift
        if [[ -z $option_type && $# -gt 0 ]]; then option_type="$1"; shift; fi
        action=("$@")
        break
        ;;
      -*)             print -u2 "Unknown flag: $1"; shift ;;
      *)
        if [[ -z $option_type ]]; then
          option_type="$1"
          shift
        else
          # Everything from here on is the action; stop parsing options.
          action=("$@")
          break
        fi
        ;;
    esac
  done

  if [[ $show_help == true ]]; then
    cat <<'EOF' >&2
Usage: <command> | selectoptions <variable> [options] [<action>]

  <variable>            Name of the value being selected (used in the prompt and by --mise)
  <action...>           Optional command and arguments; the selected value is appended
  -d, --delimiter <d>   Split the selected line into fields on <d>
  -i, --index <n>       Field to use, 1-based (0 or out-of-range keeps the whole line)
  -m, --mise            Store the value with `mise set <variable>=<value>`
  -v, --verbose         Print parsing details to stderr
  -h, --help            Show this help

Without --mise or <action>, the selected value is printed to stdout.
EOF
    return 0
  fi

  if [[ -z $option_type ]]; then
    print -u2 "Error: missing <variable> argument. Try: selectoptions --help"
    return 1
  fi

  # Read piped values. An interactive stdin means "no pipe" and yields no items.
  if [[ ! -t 0 ]]; then
    while IFS= read -r line; do
      [[ -n $line ]] && items+=("$line")
    done
  fi

  if (( ${#items} == 0 )); then
    print -u2 "Error: no data received from stdin."
    return 1
  fi

  if [[ $verbose == true ]]; then
    print -u2 -- "verbose:    $verbose"
    print -u2 -- "delimiter:  $delimiter"
    print -u2 -- "index:      $index"
    print -u2 -- "use_mise:   $use_mise"
    print -u2 -- "variable:   $option_type"
    print -u2 -- "action:     ${action[*]}"
    print -u2 -- "items:      ${items[*]}"
    print -u2 -- "item count: ${#items}"
  fi

  print -u2 -- ""
  print -u2 -- "--- Select [type: $option_type] ---"

  if (( $+commands[fzf] )); then
    choice=$(print -rl -- "${items[@]}" | fzf --prompt="Select $option_type " --height=40% --layout=reverse --border)
    if [[ -z $choice ]]; then
      print -u2 "Selection canceled."
      return 0
    fi
    opt="$choice"
  else
    local PS3="Choose an option [1-${#items[@]}]: " fallback_opt
    select fallback_opt in "${items[@]}"; do
      if [[ -n $fallback_opt ]]; then
        opt="$fallback_opt"
        break
      fi
      print -u2 "Invalid choice. Please pick 1-${#items[@]}."
    done < /dev/tty
  fi

  opt_val="$opt"

  if [[ -n $delimiter ]]; then
    # 1-based, matching zsh array indexing; index 0 leaves the line intact.
    IFS="$delimiter" read -r -A split_items <<< "$opt"
    if [[ -n $index && -n ${split_items[$index]:-} ]]; then
      opt_val="${split_items[$index]}"
    fi
  fi

  print -u2 -- "Selected option: $opt"
  print -u2 -- "Selected value:  $opt_val"

  if [[ $use_mise == true ]]; then
    if (( ! $+commands[mise] )); then
      print -u2 "Error: 'mise' command not found."
      return 1
    fi
    mise set "$option_type=$opt_val"
    # Apply immediately instead of waiting for the next prompt's activate hook.
    eval "$(mise hook-env 2>/dev/null)"
    return 0
  fi

  if (( ${#action} > 0 )); then
    "${action[@]}" "$opt_val"
    return $?
  fi

  print -r -- "$opt_val"
}
