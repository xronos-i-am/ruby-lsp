---
name: setup-ruby-lsp
description: "Make the LSP tool actually work in this repository: check that the ruby-lsp server can start, that no other plugin claims the same extensions, and put the server's notes in docs/agents/ruby-lsp.md. Run once after installing the ruby-lsp package."
disable-model-invocation: true
---

# Set up ruby-lsp for this repository

The package declares the server and denies symbol-name text search. What it cannot carry is whether
the server starts here and which plugin already claims `.rb`. That is what this run settles — and
nothing else.

**This is a fixed checklist, not a survey.** Each step is one or two commands, and the whole run is
about half a dozen. Nothing here asks you to explore the repository, read its models, or confirm how
the server behaves: how the server behaves is a property of `ruby-lsp`, the same in every project, and
it is already written in the notes you are about to copy. Do not re-derive it with `LSP` calls.

**This run writes exactly one file in the project**: `docs/agents/ruby-lsp.md`, in step 4. Everything
else it produces is a report. Do not touch the repository's instruction file (`AGENTS.md`,
`CLAUDE.md`), its `Makefile`, its `Gemfile`, or any setup script, and do not add a gem — not even
`ruby-lsp` itself. How a project installs and documents its tooling is its owner's decision, and a
setup run that slips a line into it leaves a change nobody asked for.

## 1. The server starts

1. `command -v ruby-lsp` — if nothing answers, stop here and say so: the remaining steps have nothing
   to check. The failure is silent otherwise, because Claude Code shuts a server down after three
   failed starts and does not try again for the rest of the session.
2. One `LSP` call — `documentSymbol` on any one ruby file in this repository. Symbols back means the
   server runs here. An empty answer on the first call of a session means the index is not built yet,
   so repeat that same call once; a second empty answer is the thing to report. This is the only `LSP`
   call this run needs.

## 2. Only one server claims `.rb`

`claude plugin list` — the official `ruby-lsp@claude-plugins-official` declares the same server as
this package, so with both enabled they claim the same extensions, whichever registered first serves
them, and the other is unused. This package's declaration is the one this repository ships, so the
official plugin goes:

```sh
claude plugin disable ruby-lsp@claude-plugins-official
```

The collision is quiet: apart from a row in the `/plugin` **Errors** tab, nothing announces it — so
this step's line in the report names the declaration you turned off.

## 3. The declaration reached Claude Code

One check, whichever route installed the package:

- **APM**: `.claude/skills/apm-lsp/.claude-plugin/plugin.json` exists and lists the server. An
  `.lsp.json` in the project root instead means the APM that wrote it is older than 0.29.1 and wrote a
  path Claude Code ignores: update APM and install again.
- **Plugin**: `claude plugin list` shows it enabled and without errors.

Either way the plugin is project-scoped, so the session must have accepted the workspace-trust dialog
and must have started at the repository root — a project plugin does not load from a subdirectory.
After an install, `/reload-plugins` or a restart.

## 4. The notes become the project's file

1. Copy `ruby-lsp.md` from this skill's folder to `docs/agents/ruby-lsp.md`, unless that file already
   exists — then leave it alone. Copy it as it is: its claims are the server's, not this project's,
   and checking them here would only re-derive what the file already says.
2. Leave the last section empty. It is for blind spots specific to this project, and those get written
   down when somebody meets one — not hunted for now.
3. The file belongs to the project from here on: the package never overwrites it, and the hook's deny
   text names it as soon as it exists. That is what the closing line of the report says, and
   committing the file is the person's call, not a step of this run.

## 5. The hook gets checked in the next session

The hook stays silent for the rest of a session once `LSP` has been called, and step 1 called it. So
the live check belongs to the next session: type `grep for User` there and expect a deny mentioning
LSP.

Feeding the hook's input to it directly works right away, with the script where the install put it —
`.claude/hooks/ruby-lsp/hooks/lsp-hint.sh` after an APM install, the plugin's own directory after
a plugin install:

```sh
printf '%s' '{"hook_event_name":"PreToolUse","tool_name":"Grep","session_id":"smoke","tool_input":{"pattern":"User"}}' | .claude/hooks/ruby-lsp/hooks/lsp-hint.sh
```

## The report is one line per step

A checklist run reports like a checklist: the step's number and name, the outcome, and the one detail
that shows the outcome was observed rather than assumed. Nothing else — no retelling of what a check
means, no command output that said nothing, no closing summary of a report the person has just read.
Write the lines in the language of the session; `ok` below stands for whatever that language says.

```text
1. The server starts — ok (documentSymbol on app/models/user.rb, 14 symbols)
2. One server claims .rb — ok (the official plugin was on, disabled it)
3. The declaration reached Claude Code — ok (.claude/skills/apm-lsp/…/plugin.json)
4. The notes — written to docs/agents/ruby-lsp.md
5. The hook — checked in the next session: `grep for User`
```

A step that found trouble gets the same single line, with what is wrong in place of `ok`: what to do
about it belongs in the next sentence only if the person cannot work it out from that line. Step 1 is
the one that ends the run instead of continuing it.

The last thing printed is the file, as a link, with one sentence of what it is:

> [docs/agents/ruby-lsp.md](docs/agents/ruby-lsp.md) — what this project's `ruby-lsp` does not
> resolve, and the hook's deny text points at it. The file is the repository's own: edit it as new
> blind spots turn up, the package never overwrites it.

Done when the server answered one `LSP` call, one server claims `.rb`, and `docs/agents/ruby-lsp.md`
is in place.
