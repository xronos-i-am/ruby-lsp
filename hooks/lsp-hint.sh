#!/usr/bin/env bash
# Denies text search for a Ruby symbol name and redirects it to the LSP tool.
# Design and reasons — lsp-hint.md next to this file, cases — test/lsp-hint_test.rb
set -euo pipefail

payload=$(cat)
event=$(jq -r '.hook_event_name // ""' <<< "$payload")
tool=$(jq -r '.tool_name // ""' <<< "$payload")
session=$(jq -r '.session_id // "unknown"' <<< "$payload" | tr -cd '[:alnum:]-')

# The mark lives in the temp directory and dies with it: the knowledge is per session
seen="${TMPDIR:-/tmp}/lsp-seen.${session}"

# Which request reached the LSP tool does not matter: it was reached, so the agent knows it
if [[ $event == PostToolUse ]]; then
  [[ $tool == LSP ]] || exit 0
  : > "$seen"
  exit 0
fi

# The hook speaks once per session
[[ ! -e $seen ]] || exit 0

# A command starts after more than a space: a separator, a substitution and a path all stand
# flush against the name, and `cat x;grep Name`, `ls&&grep Name`, `/usr/bin/grep Name` all
# walked past the hook
start='(^|[[:space:]|(&;`/])'
searcher=$start'(grep|egrep|fgrep|rg|ack|ag)([[:space:]]|$)'
# `git log -S` and `-G` look for a commit by an occurrence of a symbol — same search, other verb
pickaxe='(^|[[:space:]])git([[:space:]].*)?[[:space:]]-[SG]'
scanner=$start'(awk|sed|perl)([[:space:]]|$)'

# Quoted arguments, pulled out in pairs from the left. A regexp over the whole command line cannot
# do it: the closing quote of one argument and the opening quote of the next look like a pair to it,
# so `grep "User" --include="*.rb"` read as one quoted argument with a space inside
quoted_args() {
  grep -oE "'[^']*'|\"[^\"]*\"" <<< "$1" || true
}

# A space inside one argument: `grep 'GROUP BY total'` names a phrase, not a symbol
names_a_phrase() {
  local arg
  while IFS= read -r arg; do
    if [[ $arg == *[[:space:]]* ]]; then return 0; fi
  done < <(quoted_args "$1")
  return 1
}

# One command per line, cut at the shell separators. Quotes are honoured, so a separator inside a
# pattern — `grep 'a; b' .` — does not cut anything. Everything below asks its questions of one
# command's own arguments: judged by the whole line, a label in a neighbouring command answered them
# instead, and `grep -rn "User" . ; echo "done here"` passed for a phrase search
commands() {
  local rest=$1 part='' head char inside
  # A jump from one special character to the next, not a walk over every one: a heredoc body is
  # thousands of characters, and walking them cost a second on every call
  local special=$'[;|&()`\x27"\\\\\n]'
  while [[ -n $rest ]]; do
    head=${rest%%$special*}
    if [[ $head == "$rest" ]]; then
      part+=$rest
      break
    fi
    part+=$head
    char=${rest:${#head}:1}
    rest=${rest:${#head}+1}
    case $char in
      \'|\")
        # A quoted span is copied over whole, with its separators: they belong to the pattern
        inside=${rest%%"$char"*}
        if [[ $inside == "$rest" ]]; then
          part+=$char$rest
          rest=''
        else
          part+=$char$inside$char
          rest=${rest:${#inside}+1}
        fi
        ;;
      '\')
        part+=$char${rest:0:1}
        rest=${rest:1}
        ;;
      *)
        printf '%s\n' "$part"
        part=''
        ;;
    esac
  done
  printf '%s\n' "$part"
}

case $tool in
  Grep)
    # The pattern is a field here, and the symbolic form is an alternative without a space:
    # one is enough, neighbouring prose adds no legitimacy to grepping for a name
    pattern=$(jq -r '.tool_input.pattern // ""' <<< "$payload")
    IFS='|' read -r -a pieces <<< "${pattern//\\|/|}"
    symbolic=''
    for piece in "${pieces[@]}"; do
      [[ -n $piece && $piece != *[[:space:]]* ]] || continue
      symbolic=yes
    done
    [[ -n $symbolic ]] || exit 0
    ;;

  Bash)
    # The pattern is not pulled out of the command: the fact of searching is what gets denied.
    # Argument parsing was there to name the symbols, and the hook speaks once and names none
    command=$(jq -r '.tool_input.command // ""' <<< "$payload")

    # One searching command in the line is enough: the others are nobody's business here
    searching=''
    while IFS= read -r part; do
      if [[ $part =~ $searcher || $part =~ $pickaxe ]]; then
        if ! names_a_phrase "$part"; then searching=yes; break; fi
      elif [[ $part =~ $scanner ]]; then
        # A line processor both searches and reads; addressing tells them apart: a slash pattern
        # is a search, a line number is a read. It is looked for inside quotes: a path argument
        # is full of slashes and would match outside them every time
        quoted=$(quoted_args "$part")
        if [[ $quoted =~ /[^/]*[A-Za-z_][^/]*/ ]]; then searching=yes; break; fi
      fi
    done < <(commands "$command")
    [[ -n $searching ]] || exit 0
    ;;

  *) exit 0 ;;
esac

# What this server does not know is a property of the project as much as of the server, so the
# notes are the project's own file. Until it exists, the deny text names the skill that writes it
root=${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // "."' <<< "$payload")}
notes=docs/agents/ruby-lsp.md
if [[ -f $root/$notes ]]; then
  where="What not to expect from the server — $notes"
else
  where="The server's blind spots are not written down here yet: the skill ruby-lsp-setup puts them in $notes"
fi

# A deny, not a comment: additionalContext would arrive together with the output of that very grep
jq -n --arg where "$where" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: (
      "A Ruby symbol name is checked with the LSP tool (ToolSearch select:LSP), not with grep. " +
      "After any LSP call this hook stays silent until the end of the session, including on an " +
      "empty answer from the tool. " + $where
    )
  }
}'
