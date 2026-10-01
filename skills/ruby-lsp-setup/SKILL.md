---
name: ruby-lsp-setup
description: "Make the LSP tool actually work in this repository: check that the ruby-lsp server can start, that no other plugin claims the same extensions, and put the server's notes in docs/agents/ruby-lsp.md. Run once after installing the ruby-lsp package."
disable-model-invocation: true
---

# Set up ruby-lsp for this repository

The package declares the server and denies symbol-name text search. What it cannot carry is whether
the server starts here and which plugin already claims `.rb`. That is what this run settles — and
nothing else.

**This is a fixed checklist, not a survey.** Each step is one or two commands, and the whole run is
about half a dozen. How the server behaves is a property of `ruby-lsp`, the same in every project, and
it is already written in the notes you are about to copy, so the run reads neither the repository's
models nor the server's answers beyond the one call step 1 makes.

**This run writes exactly one file in the project**: `docs/agents/ruby-lsp.md`, in step 4. Everything
else it produces is a report — the instruction file, the `Makefile`, the `Gemfile` and the setup
scripts stay as they are, and no gem is installed, `ruby-lsp` included. How a project installs and
documents its tooling is its owner's decision.

## 1. The server starts

1. `command -v ruby-lsp` — if nothing answers, stop here and say so, and name `ruby-lsp-feedback` as
   what turns it into an issue. The failure is silent otherwise, because Claude Code shuts a server
   down after three failed starts and does not try again for the rest of the session.
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
  `.lsp.json` in the project root instead means the APM that wrote it is below the floor in the
  README and wrote a path Claude Code ignores: update APM and install again.
- **Plugin**: `claude plugin list` shows it enabled and without errors.

Either way the plugin is project-scoped, so the session must have accepted the workspace-trust dialog
and must have started at the repository root — a project plugin does not load from a subdirectory.
After an install, `/reload-plugins` or a restart.

## 4. The notes become the project's file

1. Pick the language. This skill's folder holds the same seed twice, `ruby-lsp.md` and
   `ruby-lsp.ru.md`; the one to copy is the one written in the language of the repository's own
   instruction file — `AGENTS.md` or `CLAUDE.md`, whichever it has, and the language of this session
   when it has neither. One look at that file, not a survey of the repository.
2. Copy the seed you picked to `docs/agents/ruby-lsp.md` — that path either way, because the hook's
   deny text names it — unless the file already exists, and then leave it alone. Copy it as it is: its
   claims are the server's, not this project's, and checking them here would only re-derive what the
   file already says.
3. Leave the last section empty. It is for blind spots specific to this project, and those get written
   down when somebody meets one — not hunted for now.
4. The file belongs to the project from here on: the package never overwrites it, and the hook's deny
   text names it as soon as it exists. That is what the closing line of the report says, and
   committing the file is the person's call, not a step of this run.

## The live check belongs to the next session

The hook stays silent for the rest of a session once `LSP` has been called, and step 1 called it. So
there is no fifth step to carry out here: the check is something the person does next session, and the
report hands it to them as its closing line.

Feeding the hook its input directly works right away; the payload is in `lsp-hint.md`, next to the
script where the install put it — `.claude/hooks/ruby-lsp/hooks/` after an APM install, the plugin's
own directory after a plugin install.

## The report is one line per step

A checklist run reports like a checklist: the step's number and name, the outcome, and the one detail
that shows the outcome was observed rather than assumed. Nothing else — no retelling of what a check
means, no command output that said nothing, no closing summary of a report the person has just read.
Write the lines in the language of the session; `ok` below stands for whatever that language says.

```text
1. The server starts — ok (documentSymbol on app/models/user.rb, 14 symbols)
2. One server claims .rb — ok (the official plugin was on, disabled it)
3. The declaration reached Claude Code — ok (.claude/skills/apm-lsp/…/plugin.json)
4. The notes — written to docs/agents/ruby-lsp.md (the ru seed, CLAUDE.md is in Russian)
```

A step that found trouble gets the same single line, with what is wrong in place of `ok`: what to do
about it belongs in the next sentence only if the person cannot work it out from that line. Step 1 is
the one that ends the run instead of continuing it.

Any step that did not end in `ok` is followed by one more line, naming where the trouble goes — a
silent failure is the package's problem, not the person's puzzle:

> The server does not start, or the `LSP` tool stays silent — run `ruby-lsp-feedback`: it works out
> which of the handful of causes it was and writes the issue for
> [xronos-i-am/ruby-lsp](https://github.com/xronos-i-am/ruby-lsp), ready to send.

Then the file, as a link, with one sentence of what it is:

> [docs/agents/ruby-lsp.md](docs/agents/ruby-lsp.md) — what this project's `ruby-lsp` does not
> resolve, and the hook's deny text points at it. The file is the repository's own: edit it as new
> blind spots turn up, the package never overwrites it.

And the last line of all is the one thing the person has to do themselves, so it is the one line the
report sets apart — its own paragraph, in bold, after everything else:

> **In the next session, type `grep for User` — a deny naming the `LSP` tool means the hook is
> alive.** It cannot be checked in this one: step 1 called `LSP`, and that silences the hook until the
> session ends.

Done when the server answered one `LSP` call, one server claims `.rb`, and `docs/agents/ruby-lsp.md`
is in place.
