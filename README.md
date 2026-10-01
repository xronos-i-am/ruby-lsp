# ruby-lsp-hint

[По-русски](README.ru.md)

Ruby code intelligence for Claude Code as an installable package: it declares the `ruby-lsp` language
server, and it denies text search for a symbol name until the session has asked the `LSP` tool at
least once.

Two halves of one habit. Declaring the server makes the `LSP` tool answer; the hook is what makes an
agent reach for it, because a pointer in `CLAUDE.md` loses to the reflex of typing `grep`. The deny
fires on the first step of navigation, before the first file is opened, and it lifts for the rest of
the session as soon as any `LSP` call is made — including a call that comes back empty.

## What it gives you

| Piece | Effect |
| --- | --- |
| `lspServers.ruby-lsp` | The `LSP` tool answers for `.rb`, `.rake`, `.gemspec`, `.ru` and `.erb`: definitions, references, hover, document and workspace symbols |
| `hooks/lsp-hint.sh` | `grep`, `rg`, `ack`, `ag`, `git log -S`, a `sed`/`awk`/`perl` slash pattern and the `Grep` tool are denied while the pattern is a bare symbol name; a quoted phrase passes |
| `skills/setup-ruby-lsp` | A one-off setup run: checks the server can start, finds a plugin that claims the same extensions, and writes the project's own `docs/agents/ruby-lsp.md` |

## Prerequisites

**ruby-lsp.** The package configures the server, it does not install it.

- Ruby 3.0 or later, and the `ruby-lsp` gem reachable as the `ruby-lsp` command.
- Declare it where a routine command restores it — a development group of your `Gemfile` — rather than
  installing it by hand:

  ```ruby
  group :development do
    gem "ruby-lsp", require: false
  end
  ```

- If ruby comes from a version manager's shim (mise, rbenv, asdf), the server is started from the
  workspace root, so that root needs the version file the shim reads. Without it the shim exits with
  `No version is set for shim`, and Claude Code gives up on a server after three failed starts — the
  only symptom is an `LSP` call that finds no server.
- `jq` and `bash` on `PATH`: the hook is a bash script that parses its input with `jq`.

**Claude Code.**

- v2.1.157 or later, which is when a plugin directory under `.claude/skills/` became
  auto-discoverable. That is how the server declaration reaches Claude Code at project scope, with no
  `enabledPlugins` entry to maintain.
- A project-scope plugin loads only after you accept the workspace-trust dialog for the folder, and
  only when the session's primary working directory is the repository root. Started from a
  subdirectory, it does not load.
- `/reload-plugins` (or a restart) after the install; hooks are read at session start, so the deny
  begins working in the next session.

**APM**, for the APM route: version 0.29.1 or later. Older versions write the LSP configuration to a
project-root `.lsp.json`, a path Claude Code ignores, and the tool stays silent with nothing to show
for it.

## Install with APM

```yaml
# apm.yml
dependencies:
  apm:
    - xronos-i-am/ruby-lsp-hint
```

```sh
apm install
```

Then `/reload-plugins` and, once, the `setup-ruby-lsp` skill.

What lands in the project:

```
.claude/skills/apm-lsp/.claude-plugin/plugin.json   the server declaration, auto-discovered
.claude/settings.json                               the hook entries, merged by APM
.claude/hooks/ruby-lsp-hint/hooks/           the hook script and its design notes
.claude/skills/setup-ruby-lsp/                      the setup skill and the seed notes
```

APM owns those files and rewrites them on the next install, so edits belong in the package or in the
project's own files — never in the deployed copies.

## Install as a Claude Code plugin

The repository is also a one-plugin marketplace, so APM is not required:

```sh
claude plugin marketplace add xronos-i-am/ruby-lsp-hint
claude plugin install ruby-lsp-hint@xronos-i-am
```

Here Claude Code runs the plugin from its own directory and resolves `${CLAUDE_PLUGIN_ROOT}` itself;
nothing is copied into the project.

## One server per extension

If another enabled plugin declares a Ruby language server — `ruby-lsp@claude-plugins-official` is the
common one — the extension goes to whichever server registered first and the other never starts.
Nothing reports the collision. Disable the one you do not want:

```sh
claude plugin disable ruby-lsp@claude-plugins-official
```

## The project's notes are the project's file

The deny text ends by naming `docs/agents/ruby-lsp.md`, and that file belongs to the repository, not
to this package: what the server fails to resolve depends on which gems build constants at runtime,
which code is reachable through symlinks, where the generated schema lives. The `setup-ruby-lsp`
skill seeds the file from a template and the project edits it from there; the package keeps no second
copy, so an install never overwrites it. While the file is missing, the deny text names the skill
instead of a path.

## Development

```sh
test/lsp-hint_test.rb                 # the whole suite
test/lsp-hint_test.rb -n /pickaxe/    # cases by a substring of the name
```

Neither Bundler nor a framework is needed: minitest comes with ruby, and the hook runs as a process
with its own `TMPDIR`, so the suite depends on no application and no live session.

How the hook is built and why each decision is the way it is — [`hooks/lsp-hint.md`](hooks/lsp-hint.md).
Its coverage was gathered by measurement in live sessions, so the test suite is also the inventory of
what once looked covered and was not.

## License

MIT, see [LICENSE](LICENSE).
