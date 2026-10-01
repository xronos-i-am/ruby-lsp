---
name: setup-ruby-lsp
description: "Make the LSP tool actually work in this repository: check that the ruby-lsp server can start, that no other plugin claims the same extensions, and put the server's notes in docs/agents/ruby-lsp.md. Run once after installing the ruby-lsp-hint package."
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

`claude plugin list` — if another enabled plugin declares a Ruby language server (the official
`ruby-lsp@claude-plugins-official` is the usual one), the extension goes to whichever server
registered first and the other never starts. Disable the one this repository does not want:

```sh
claude plugin disable ruby-lsp@claude-plugins-official
```

Say which server stays. The collision is silent: nothing reports it except a tool call that comes back
with no server.

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
3. Tell the person the file is theirs from here on: the package never overwrites it, and the hook's
   deny text names it as soon as it exists. Committing it is their call, not a step of this run.

## 5. The hook gets checked in the next session

The hook stays silent for the rest of a session once `LSP` has been called, and step 1 called it. So
the live check belongs to the next session: type `grep for User` there and expect a deny mentioning
LSP.

Feeding the hook's input to it directly works right away, with the script where the install put it —
`.claude/hooks/ruby-lsp-hint/hooks/lsp-hint.sh` after an APM install, the plugin's own directory after
a plugin install:

```sh
printf '%s' '{"hook_event_name":"PreToolUse","tool_name":"Grep","session_id":"smoke","tool_input":{"pattern":"User"}}' | .claude/hooks/ruby-lsp-hint/hooks/lsp-hint.sh
```

Done when the server answered one `LSP` call, one server claims `.rb`, and `docs/agents/ruby-lsp.md`
is in place.
