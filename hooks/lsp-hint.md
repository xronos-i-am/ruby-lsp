# The `lsp-hint.sh` hook

[По-русски](lsp-hint.ru.md)

Denies text search for a symbol name until the session has called the `LSP` tool. What it denies and
by which signal is in the [README](../README.md), and the rest follows from the script; this file holds
what neither of them says — what each decision costs and what the hook lets through on purpose. The
cases live in `test/lsp-hint_test.rb`.

## The deny speaks in place of the output, not next to it

`additionalContext` arrives together with the result of that very grep — in the second when the answer
is already in hand and there is nothing left to redirect. A denied call does not run, the reason
arrives where the output would have been, and the only way forward is a different call.

The deny text is therefore a miniature instruction rather than a comment, and it answers one question:
what to check a name with. How to ask is in the tool's own schema; what not to expect from the server
is in the project's notes, which a section below is about.

The text also says in so many words that an empty answer from LSP confirms text search is legitimate.
Read the other way round, it sends the agent back to the tool for a name the server does not have.

## The mark is set by reaching the tool, not by a useful answer

Requiring a non-empty answer loops the agent on everything the server does not know: gems are not
indexed, framework dynamics and constants built by metaprogramming do not resolve at all. The correct
conclusion from an empty answer is "this is not in the index, text search is legitimate", so the hook
looks neither at the tool's answer nor at the shape of the request — `PostToolUse` on `LSP` is all it
needs to know.

The price is chosen deliberately: one `LSP` call opens the road to every later search in that session.
Knowing which name a call asked about costs a mark per name and a read of the file a positional request
points at — a third of the hook's code for a deny that lasts until the session ends anyway.

## A false deny is the more expensive of the two mistakes

A pass costs one un-denied grep, and the hook goes on waiting for the next call; a deny on something
that was not a symbol search costs the only way forward there was. So the gaps below are kept rather
than closed:

- which argument of a command is the pattern is not worked out. Finding the target on disk would cost
  a directory walk on every `Bash` call and stay approximate;
- a search inside a double-quoted command substitution — `echo "$(grep Name .)"` — stays silent,
  because the quoted span is one argument with spaces inside it. Cutting inside double quotes would
  buy that case at the price of false denials on `grep "cost $(price) x" .`;
- the quotes-with-a-space rule is not applied to the line-processor branch, or
  `perl -ne 'print if /Name/'` would walk past the deny on its own quotes;
- the shape of the name is not checked. An anchor, a word boundary, a bracket and an escaped dot do
  not stop a name from being one, and a pattern that insists on a proper name loses the deny on each
  of them.

A path argument is full of slashes, so the line processors' slash pattern is looked for inside the
quotes of their own command only.

## Anything that touches the command line is measured on a long one

The hook runs on every `Bash` call, so its cost is the session's cost. Cutting the line into commands
honours quote state, which a regexp cannot carry, so the cut is a loop — and the loop jumps from one
special character to the next with `${rest%%[…]*}` rather than walking character by character: a
per-character walk over a heredoc body of 12 000 characters costs 1.2 s per call against 5 ms for the
jump.

## The notes the deny text points at belong to the project

What the server fails to resolve is a property of the project as much as of the server: it depends on
the project's gems, on how its files are laid out, and on what lies outside the workspace root. So the
notes are the project's own file, `docs/agents/ruby-lsp.md` — seeded by the `ruby-lsp-setup` skill and
edited by the project, as the [README](../README.md) describes. The hook names that path as soon as the
file exists and names the skill while it does not: a pointer into a file that is not there is worse
than no pointer at all.

## Whether the hook is alive is checked with one phrase

In a new session:

```
grep for User
```

A deny mentioning LSP is expected. Silence means one of three things: the hook is not installed
(`apm install`, or the plugin is not enabled), the session mark is already set
(`ls "${TMPDIR:-/tmp}"/lsp-seen.*`), or the agent went to LSP on its own and never got to the grep.

Without a session, straight into the hook's input:

```sh
printf '%s' '{"hook_event_name":"PreToolUse","tool_name":"Grep","session_id":"smoke","tool_input":{"pattern":"User"}}' | hooks/lsp-hint.sh
```

## An edit is checked by a run

The command is in the README's Development section. A case there is one line: one hook input and one
`assert` or `refute` expectation. The hook has two decisions — deny or silence — so apart from the two
cases that read a path out of the deny text, the wording is free to be rewritten without touching the
suite.

Two rakes belong to the hook itself:

- `A && B` with a false `A` under `set -e` kills the hook silently — the condition is written with
  `|| exit` and `if`;
- the hook reads the whole command line, so a file with such a grep in its text is written with the
  `Write` tool: a heredoc is part of the command, and the write denies itself until the session has
  called LSP.
