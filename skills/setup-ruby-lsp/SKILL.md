---
name: setup-ruby-lsp
description: "Make the LSP tool actually work in this repository: check that the ruby-lsp server can start, that no other plugin claims the same extensions, and write the project's own docs/agents/ruby-lsp.md. Run once after installing the ruby-lsp-hint package."
disable-model-invocation: true
---

# Set up ruby-lsp for this repository

The package declares the server and denies symbol-name text search. What it cannot carry is anything
that depends on this repository: whether the server binary starts here, which plugin already claims
`.rb`, and what this project's code does that the server cannot resolve. That is what this run
settles.

Go through the steps in order. Report what you found and what you changed; where something is
missing, name the exact fix rather than fixing it silently in a way the repository cannot reproduce.

## 1. The server has to be able to start

1. `command -v ruby-lsp` — if nothing answers, the tool stays silent with no error of its own: Claude
   Code shuts a server down after three failed starts and does not try again for the rest of the
   session.
2. Look at how the gem is declared: a `ruby-lsp` entry in a development group of the `Gemfile`, or an
   explicit statement in the setup documentation that it is installed globally. A gem installed by
   hand and written down nowhere is a repair that dies at the next environment change.

Report each missing piece with the line that declares it, and stop here if the binary cannot run:
the remaining steps have nothing to check.

## 2. Only one server may claim `.rb`

`claude plugin list` — if another enabled plugin declares a Ruby language server (the official
`ruby-lsp@claude-plugins-official` is the usual one), the extension is taken by whichever server
registered first and the other one never starts. Disable the one this repository does not want:

```sh
claude plugin disable ruby-lsp@claude-plugins-official
```

Say which server stays, and that a per-extension collision is silent — nothing reports it except a
tool call that comes back with no server.

## 3. The declaration has to reach Claude Code

- Installed with APM: `.claude/skills/apm-lsp/.claude-plugin/plugin.json` must exist and list the
  server. If instead there is an `.lsp.json` in the project root, the APM that wrote it is older than
  0.29.1 and that path is one Claude Code ignores: update APM and install again.
- Installed as a plugin: the plugin has to be enabled, and `/plugin` must show it without errors.
- Either way the plugin is project-scoped, so the session must have accepted the workspace-trust
  dialog and must have started at the repository root — a project plugin does not load from a
  subdirectory. After the install, `/reload-plugins` or a restart.

## 4. The notes become the project's own file

1. If `docs/agents/ruby-lsp.md` does not exist, copy `ruby-lsp.md` from this skill's folder there.
2. Check each claim in it against this repository with actual `LSP` calls, and delete what does not
   hold here.
3. Fill the last section with what is true only for this project: which gems build constants at
   runtime, which code is reachable through symlinks and therefore answers with several paths, where
   the generated schema dump lives, which directories the server does not see. A claim nobody
   checked does not belong in the file.
4. Commit the file. From here on it is the project's, and the package never overwrites it: the hook
   points at this path as soon as it exists.

## 5. The repository's instructions point at the tool

Add one line to `CLAUDE.md`, or to `AGENTS.md` when that is the file this repository keeps — edit
whichever exists and never create the other: looking for a symbol in ruby code goes through the `LSP`
tool, and what not to expect from the server is in `docs/agents/ruby-lsp.md`.

## 6. The hook is checked in a new session

The hook stays silent until the end of a session once `LSP` has been called, and this run has almost
certainly called it. So the check belongs to the next session: type `grep for User` there and expect
a deny mentioning LSP.

Feeding the hook's input to it directly works right away, with the script where the install put it —
`.claude/hooks/ruby-lsp-hint/hooks/lsp-hint.sh` after an APM install, the plugin's own directory after
a plugin install:

```sh
printf '%s' '{"hook_event_name":"PreToolUse","tool_name":"Grep","session_id":"smoke","tool_input":{"pattern":"User"}}' | .claude/hooks/ruby-lsp-hint/hooks/lsp-hint.sh
```

Done when the server answers an `LSP` call in this repository, `docs/agents/ruby-lsp.md` is committed
with the project's own notes in it, and the deny text names that path.
