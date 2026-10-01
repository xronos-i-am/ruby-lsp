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
# Quotes with a space inside: `grep 'GROUP BY total'` names a phrase, not a symbol
phrase="('[^']*[[:space:]][^']*'|\"[^\"]*[[:space:]][^\"]*\")"

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

    if [[ $command =~ $searcher || $command =~ $pickaxe ]]; then
      ! [[ $command =~ $phrase ]] || exit 0
    elif [[ $command =~ $scanner ]]; then
      # A line processor both searches and reads; addressing tells them apart: a slash pattern
      # is a search, a line number is a read. It is looked for inside quotes: a path argument
      # is full of slashes and would match outside them every time
      quoted=$(grep -oE "'[^']*'|\"[^\"]*\"" <<< "$command" || true)
      [[ $quoted =~ /[^/]*[A-Za-z_][^/]*/ ]] || exit 0
    else
      exit 0
    fi
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
  where="The server's blind spots are not written down here yet: the skill setup-ruby-lsp puts them in $notes"
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
