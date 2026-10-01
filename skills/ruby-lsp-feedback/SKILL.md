---
name: ruby-lsp-feedback
description: "Work out why this session did not reach the LSP tool, and write the issue about it. Run it when a symbol search went through without a deny, when the deny arrived but LSP answered nothing, or when a deny arrived for something that was not a symbol search. It composes the issue text and sends nothing."
disable-model-invocation: true
---

# Report a session where the LSP tool was not reached

The package has one failure that matters and never announces itself: a symbol name was looked for as
text, and the `LSP` tool was not asked. A hole in the hook shows up only this way — in a live session,
after the search has already walked past the deny — so a session that went wrong is the package's only
source of coverage. This run turns one such session into an issue text, and sends nothing.

**The evidence is this session, not the repository.** Which calls were made, whether a deny arrived,
what `LSP` answered — that lives in the transcript you are holding and nowhere else: the hook keeps no
log, and its session mark is an empty file. So write the sequence out from the transcript first, before
running a single command, and do not reconstruct it later from what the files suggest.

**Two commands of this run would be judged by the hook under investigation.** A `grep` of the lockfile
and a `sed -n '/…/p'` of a settings file are a search and a slash pattern, and they get denied — read
those files with the `Read` tool instead. And an `LSP` call made now sets the session mark, which
silences the hook until the session ends: harmless for a diagnosis that looks backwards, fatal for any
further live check. Leave it for last, if at all.

## 1. The three facts from the session

In this order, from the transcript:

1. The searching calls — the exact command lines, or the exact `Grep` patterns, that went looking for a
   symbol name. Exact: a quote, a flag or a neighbouring command in the same line is the whole
   difference between a deny and silence.
2. Whether a deny arrived, and for which of those calls.
3. Whether `LSP` was called, and what came back: symbols, an empty answer, or no server at all.

If none of the three describes a symbol search — the search was for a phrase, a string literal, a
config key — stop here and say so. Text search for those is legitimate and the hook is right to stay
out of it.

## 2. Which installation is in play

- The route and the script's path: `.claude/hooks/ruby-lsp/hooks/lsp-hint.sh` after an APM install, the
  plugin's own directory after a plugin install. `claude plugin list` names what is enabled, including
  whether the official `ruby-lsp@claude-plugins-official` is competing for `.rb`.
- The package revision: `resolved_commit` in `apm.lock.yaml` on the APM route, the version in
  `claude plugin list` on the plugin route. A fix already pushed upstream is not an issue — on the APM
  route `apm install` reproduces the lockfile, so a project can sit on an old revision until
  `apm update`.
- `claude --version` and, on the APM route, `apm --version`: both have floors, and the README's
  requirements table says what happens below them.
- The hook's own entries, in `.claude/settings.json`. Read the file; their absence explains everything
  else at once.

## 3. The hook's decision, measured

Replay each call from step 1 against the script, rather than reasoning about what it should have done:

1. Write the payload with the `Write` tool — not with a heredoc. A heredoc is part of the command line,
   so the command under investigation would end up inside the very call being checked, and the hook
   would decide about the diagnosis instead of the case:

   ```json
   {"hook_event_name":"PreToolUse","tool_name":"Bash","session_id":"feedback","tool_input":{"command":"grep -rn \"User\" ."}}
   ```

   A `Grep`-tool case is the same shape with `"tool_name":"Grep"` and `"tool_input":{"pattern":"User"}`.

2. Feed it with a redirection and a temporary directory of its own, so no mark from the live session
   answers for the script:

   ```sh
   TMPDIR=$(mktemp -d) .claude/hooks/ruby-lsp/hooks/lsp-hint.sh < payload.json
   ```

   A JSON deny, or no output at all. Record which, per call.

## 4. The cause, from a short list

| What was measured | The cause | Where it belongs |
| --- | --- | --- |
| The search passed in the session, and the replay passes too | A hole in the hook's coverage | An issue here — this is the case the package exists to fix |
| The search passed in the session, but the replay denies | The hook never ran: a session older than the install, a session started outside the repository root, workspace trust not accepted, `/reload-plugins` not run, or the mark already set by an earlier `LSP` call | Not an issue until those are ruled out; the report names which one it was |
| A deny arrived, `LSP` was called, nothing answered, and `command -v ruby-lsp` finds nothing | The gem is missing on the ruby version in play | The project's own setup — the README says why the `Gemfile` is where it belongs |
| A deny arrived, `LSP` answered nothing, the command exists, and the official plugin is enabled | Two declarations claim `.rb`, and the losing one is never used | Step 2 of `ruby-lsp-setup`; an issue only if disabling it changes nothing |
| `LSP` answered, the answer was empty, and the search followed | Expected behaviour: an empty answer makes text search legitimate | The project's `docs/agents/ruby-lsp.md`, as one more blind spot |
| A deny arrived for a phrase, a path or a command that was not a search | A false deny, the expensive kind of mistake | An issue here, with the payload |

## 5. The issue text

Write the body to a file so it can be sent as it is, and print it in the session too. Title: the cause
in one line, not the symptom — `grep "User" --include="*.rb" passes the deny`, not `hook does not work`.

```markdown
## What happened
One or two sentences: the call that was made, what the hook did, what the LSP tool did.

## Measured decision
The payload, and the script's answer to it in a clean TMPDIR. Both, verbatim.

## Expected
Which of the two decisions — deny or silence — should have come, and why.

## Environment
Route (APM or plugin), package revision, Claude Code version, APM version, ruby-lsp version,
whether the official plugin is enabled.
```

Then the command that sends it, for the person to run — this run does not send:

```sh
gh issue create --repo xronos-i-am/ruby-lsp --title "<title>" --body-file <path to the body>
```

The issue carries the shape of the call, not the repository's contents: a symbol name only where it is
the point, no file bodies, no output of the search. Say in one line that reading it before sending is
the person's part, not this run's.

## The report is one line per step

The same shape the other skill's report has: step number, name, outcome, and the one detail that shows
it was observed. The cause from step 4 gets its own line, in full, because it is the answer the run was
for. Then the body file as a link, and last of all, set apart:

> **Nothing has been sent.** The issue goes out when you run the `gh` command above.
