# The `lsp-hint.sh` hook

Denies text search for a symbol name until the session has called the `LSP` tool. The rule fires on
the first step of navigation, before the first file is opened, and against a tool that is always in
the list but is reached for last: a pointer in `CLAUDE.md` was not enough for that.

What the hook does follows from its code; what follows below is what the code does not say — why
each decision is the way it is and what it costs. The cases live in `test/lsp-hint_test.rb`, and the
command that runs them is at the bottom of this file.

## The hook hangs on two events and speaks once per session

`PreToolUse` on `Bash|Grep` denies the search. `PostToolUse` on `LSP` sets a mark, and from then on
the hook stays silent until the session ends. The deny is lifted by an observable event rather than
by the agent's promise — but the bare fact of reaching for the tool is the whole condition: which
request got there, and which name it asked about, the hook does not examine.

The mark is an empty file, `$TMPDIR/lsp-seen.<session>`: the knowledge is per session and dies with
the directory.

The price is known and chosen deliberately: one LSP call opens the road to every later search. An
earlier layout kept a mark per name and read a line of the file to learn which name a positional
request was about — accuracy cost a third of the hook's code.

## The deny speaks in place of the output, not next to it

`additionalContext` would arrive together with the result of that very grep — in the second when the
answer is already in hand and there is nothing left to redirect. A denied call does not run, the
reason arrives where the output would have been, and the only way forward is a different call.

The deny text is therefore not a comment but a miniature instruction, and it answers one question:
what to check a name with. How to ask is in the tool's own schema; what not to expect from the
server is in the project's notes, which the last section of this file is about.

One caveat in the text was added after an agent read an earlier version the other way round: an
empty answer from LSP confirms that text search is legitimate, it does not mean "ask again".

## The mark is set by reaching the tool, not by a useful answer

Require a non-empty answer and you loop the agent on everything the server does not know: gems are
not indexed, framework dynamics and constants built by metaprogramming do not resolve at all. The
correct conclusion from an empty answer is "this is not in the index, text search is legitimate".

So the hook looks neither at the tool's answer nor at the shape of the request: `PostToolUse` on the
`LSP` tool is all it needs to know.

## The pattern is not pulled out of the command

What gets denied is the fact of searching: a searcher in the line, the `git log -S` pickaxe, a line
processor with a slash pattern. Which argument is the pattern, the hook does not work out.

Argument parsing was needed for exactly two things: to tell a phrase from a symbol, and to name the
symbols in the deny text. The names are no longer named — the agent wrote them itself, and the hook
speaks once per session — so the parsing went away whole: fifty lines with a list of
value-carrying flags, three loops over words, and quote-aware word splitting. What came back later is
quote-aware scanning of a different kind, and for a different purpose: cutting the line into commands,
which the next section is about.

A system library does not help here, and that was measured: `getopt` parses by a specification you
write yourself and knows nothing about `rg`, `ack` or `git -S`; ruby's bundled `Shellwords` gives
only quote-aware splitting and leaves the question "which argument is the pattern" to the caller.
The one thing that knows for certain is `grep` itself, and it cannot be asked: the deny has to
happen before the run.

What is still not worked out is which argument of a command is the pattern. Looking for the target on
disk would cost a walk on every grep and would still be approximate, while a false pass costs one
un-denied grep: the hook goes on waiting for the next one.

## The line is judged one command at a time

A compound call is cut into commands first, and every question below is asked of one command's own
arguments. The cut happens at `;`, `|`, `&`, `(`, `)`, a backtick and a newline, with quotes honoured
— so a separator inside a pattern, `grep 'a; b' .`, cuts nothing. A regexp cannot do it, because it
cannot carry the quote state, so the cut is a loop; and the loop jumps from one special character to
the next with `${rest%%[…]*}` instead of walking character by character. That is not a flourish but a
measurement: the hook runs on every `Bash` call, and a walk over a 12 000-character heredoc body cost
1.2 s per call against 5 ms for the jump.

Judging the whole line instead was a hole, and a wide one: a human-readable label in a neighbouring
command answered the phrase question for the search. `grep -rn "User" . ; echo "done here"` and
`git grep -c "User" -- . ; echo "---TOTAL FILES---"` both passed, because somewhere in the line there
were quotes with a space between them. Gluing several commands into one call and labelling their output
is ordinary practice, so the deny was lost exactly where an agent is most comfortable.

The same cut earns accuracy the earlier layout had written off as its price: `grep 'two words' . &&
grep Name .` is now denied for the second command, while the phrase search in the first one is nobody's
business. One searching command in the line is enough, and the hook stops at it.

What still passes is a search inside a double-quoted command substitution — `echo "$(grep Name .)"`
stays silent, because the quoted span is one argument with spaces inside it. Cutting inside double
quotes would buy that case at the price of false denials on `grep "cost $(price) x" .`, and a false
deny is the more expensive of the two mistakes.

## Quotes with a space inside give a phrase away

`grep 'GROUP BY total'` names a phrase, and looking for it as text is legitimate. That is the only
thing that decides: a quote on its own belongs to the command, not to the pattern, so `grep 'User'`
is denied just like `grep User`.

The space is looked for inside one argument of that one command, and the arguments are pulled out in
pairs from the left
— `grep -oE "'[^']*'|\"[^\"]*\""`, the same way the line-processor branch does it. A regexp over the
whole command line cannot tell a pair of quotes from a gap between two of them: for
`grep "User" --include="*.rb"` it matched the closing quote of the name together with the opening
quote of the next argument, found a space between them and read the whole thing as a phrase. Any
search with two or more quoted arguments passed that way — `rg "Name" -g "*.rb"`,
`grep "Name" "app/models"` — which is the mass case, not an edge one.

For the `Grep` tool the pattern is a field, and there the alternation is taken apart: one branch
without a space is enough — `Name\|SCAN orders` is denied for the sake of the name, while
`SCAN orders\|USING INDEX` passes. The exact shape of the name is not checked: an anchor, a word
boundary, a bracket and an escaped dot do not stop a name from being one, and a regexp over "a
proper name" lost the deny on each of them.

## A line processor is told apart by its addressing

A slash pattern is a search, a line number is a read, and `sed -n '10,20p'` beats any LSP call at a
range. The pattern is looked for inside the quotes of that command only: a path argument is full of
slashes and would match outside them every time, and a quoted path in a neighbouring command —
`echo '/tmp/probe/' && sed -n '10,20p' f.rb` — used to read as a slash pattern. The
quotes-with-a-space rule is not applied to this branch — otherwise `perl -ne 'print if /Name/'` would
walk past the deny.

## The coverage was measured, not enumerated

Every hole was found in a live session, that is, after a search had already walked past the deny. In
the test suite a case stands under each of them, and the list is worth reading as an inventory of
what looked covered:

- `egrep` and `fgrep` — they carry a letter before `grep`, and a word boundary let them through;
- `cat x;grep Name`, `ls&&grep Name`, a grep in backticks — the separator stands flush against the
  command name;
- `/usr/bin/grep Name` — a path stands flush in the same way a separator does;
- `git log -S` and `-G`, including `-SName` flush — the pickaxe looks for a commit by an occurrence
  of a symbol;
- `sed`, `awk`, `perl` — they search no worse than grep, and the same commands are used to read a
  file;
- `grep "Name" --include="*.rb"` — a second quoted argument looked like a phrase to a regexp that
  read the whole command line instead of the arguments one by one;
- `grep -rn "Name" . ; echo "done here"` — a label in a neighbouring command answered the phrase
  question for the search, until the line began to be cut into commands.

Everything that stands flush is collected in one `start` class: the hole was one, and writing it off
would have taken three patterns.

## The notes the deny text points at belong to the project

What the server fails to resolve is a property of the project as much as of the server: it depends on
the project's gems, on how its files are laid out, and on what lies outside the workspace root. So the
notes are the project's own file, `docs/agents/ruby-lsp.md`, and the hook names it as soon as it
exists.

The skill `setup-ruby-lsp` puts the seed there, and the project edits it afterwards; the package
keeps no second copy and so overwrites nothing on the next install. While the file is missing, the
deny text names the skill instead of a path — a pointer into a file that is not there is worse than
no pointer at all.

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

```sh
test/lsp-hint_test.rb                 # the whole suite
test/lsp-hint_test.rb -n /pickaxe/    # cases by a substring of the name
```

Neither Bundler nor a framework is needed: minitest comes with ruby, and the hook is called as a
process with its own `TMPDIR`, so the run depends on no application and no live session. The suite
lives outside `hooks/` on purpose: APM deploys that directory into the consuming project, and a test
suite has no business being there.

A case is one line: one hook input and one `assert` or `refute` expectation. The hook has two
decisions — deny or silence — so apart from the two cases that read a path out of the deny text,
there is nothing in the wording for a test to hold on to, and the text can be rewritten without
touching the suite.

Two rakes when editing the hook itself:

- `A && B` with a false `A` under `set -e` kills the hook silently — the condition is written with
  `|| exit` and `if`;
- the hook reads the whole command line, so a file with such a grep in its text is written with the
  `Write` tool: a heredoc is part of the command, and the write denies itself until the session has
  called LSP;
- the hook runs on every `Bash` call, so anything that touches the command line is measured on a long
  one: a heredoc body of a few thousand characters turns a per-character loop into a second of latency
  on every call.
