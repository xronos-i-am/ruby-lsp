# ruby-lsp-hint

[По-русски](README.ru.md)

Ruby code intelligence for Claude Code as an installable package: it declares the `ruby-lsp` language
server, and it denies text search for a symbol name until the session has asked the `LSP` tool at
least once.

Two halves of one habit. Declaring the server makes the `LSP` tool answer; the hook is what makes an
agent reach for it, because a pointer in `CLAUDE.md` loses to the reflex of typing `grep`. The deny
fires on the first step of navigation, before the first file is opened, and it lifts for the rest of
the session as soon as any `LSP` call is made — including a call that comes back empty.

## What the package does

The language server itself is not part of it: `ruby-lsp` is a gem you install, and the package only
tells Claude Code how to start the binary you already have.

| Piece | Effect |
| --- | --- |
| The server declaration, `lspServers.ruby-lsp` | Claude Code starts your `ruby-lsp` binary, and the `LSP` tool answers for `.rb`, `.rake`, `.gemspec`, `.ru` and `.erb`: definitions, references, hover, document and workspace symbols |
| `hooks/lsp-hint.sh` | `grep`, `rg`, `ack`, `ag`, `git log -S`, a `sed`/`awk`/`perl` slash pattern and the `Grep` tool are denied while the pattern is a bare symbol name; a quoted phrase passes |
| `skills/setup-ruby-lsp` | A one-off setup run: checks the server can start, finds a plugin that claims the same extensions, and writes the project's own `docs/agents/ruby-lsp.md` |

## Requirements

| What | Minimum | What happens below it |
| --- | --- | --- |
| Ruby | 3.0 | `ruby-lsp`'s own floor |
| `ruby-lsp` gem | reachable as the `ruby-lsp` command | The `LSP` tool answers nothing and the server reports no error of its own |
| `jq`, `bash` | any | The hook is a bash script that parses its input with `jq`; without them every hook call fails |
| Claude Code | 2.1.157 | A plugin directory under `.claude/skills/` is not auto-discovered, so the server declaration an APM install writes is never read |
| Claude Code | 2.1.275 | Only for the one-command `/plugin install … --marketplace …` form below; the two-step form has no such floor |
| APM | 0.29.1 | Only for the APM route: older versions write the LSP configuration to a project-root `.lsp.json`, a path Claude Code ignores, and the tool stays silent with nothing to show for it |

Check and raise the two that have a floor:

```sh
claude --version
apm --version && apm self-update    # the APM route only
```

Two more conditions, neither of which announces itself when unmet:

- **Declare the gem where a routine command restores it** — a development group of your `Gemfile` —
  rather than installing it by hand:

  ```ruby
  group :development do
    gem "ruby-lsp", require: false
  end
  ```

  The point is to keep the server on the ruby version the project actually uses. A version manager
  keeps a separate gem set per ruby version, so a gem installed by hand belongs to whichever version
  was active at the time: the moment the project moves to another one, the command is gone from that
  version's set and the server stops starting. `bundle install` brings it back after a version bump,
  a hand-installed gem does not. The failure is silent — Claude Code shuts a server down after three
  failed starts and does not try again, so the only symptom is an `LSP` call that finds no server.
- **A project-scope plugin needs workspace trust and a session started at the repository root.** It
  does not load from a subdirectory, and it does not load until you accept the trust dialog for the
  folder.

## Install with APM

1. Declare the dependency:

   ```yaml
   # apm.yml
   dependencies:
     apm:
       - xronos-i-am/ruby-lsp-hint
   ```

2. `apm install`. It reports `Configured 1 LSP server` and the hook entries it merged.
3. `/reload-plugins`, or start the next session. Hooks are read at session start, so the deny begins
   working in the next session either way.
4. Run the `setup-ruby-lsp` skill once, and commit the `docs/agents/ruby-lsp.md` it writes.

What lands in the project:

```
.claude/skills/apm-lsp/.claude-plugin/plugin.json   the server declaration, auto-discovered
.claude/settings.json                               the hook entries, merged by APM
.claude/hooks/ruby-lsp-hint/hooks/                  the hook script and its design notes
.claude/skills/setup-ruby-lsp/                      the setup skill and the seed notes
```

APM owns those files and rewrites them on the next install, so edits belong in the package or in the
project's own files — never in the deployed copies.

## Install as a Claude Code plugin

The repository is also a one-plugin marketplace, so APM is not required. Nothing is copied into the
project on this route: Claude Code runs the plugin from its own directory and resolves
`${CLAUDE_PLUGIN_ROOT}` itself.

1. **Add the marketplace.** In your shell:

   ```sh
   claude plugin marketplace add xronos-i-am/ruby-lsp-hint
   ```

   In a session the same source works as `/plugin marketplace add xronos-i-am/ruby-lsp-hint`. Add
   `#<ref>` to pin a branch or tag. While the repository is private, Claude Code clones it with the
   git credentials already on your machine and never prompts: for the `owner/repo` shorthand it
   probes whether your SSH key authenticates to `github.com` and clones over SSH when it does.

2. **Install it, choosing who gets it.** From your shell, where the default scope is yourself on this
   machine:

   ```sh
   claude plugin install ruby-lsp-hint@xronos-i-am                   # you, every project
   claude plugin install ruby-lsp-hint@xronos-i-am --scope project   # everyone in this repository
   claude plugin install ruby-lsp-hint@xronos-i-am --scope local     # you, this repository only
   ```

   In a session, `/plugin install ruby-lsp-hint@xronos-i-am` opens the plugin's details so you can
   review what it adds and pick the scope there. On Claude Code 2.1.275 or later the two steps
   collapse into one, with the plugin named without its `@marketplace` half:

   ```text
   /plugin install ruby-lsp-hint --marketplace xronos-i-am/ruby-lsp-hint
   ```

3. **For a repository, mind what `--scope project` does and does not do.** It writes the entry to
   `.claude/settings.json`, which you commit, and that turns the plugin on for your collaborators —
   but it does not download it to their machines. Each of them runs the install command once too.

4. **Activate.** `/reload-plugins`, or start the next session.

5. **Check it arrived.** `claude plugin list` prints the plugin with its version, scope and status,
   and typing `/` shows its skill as `/ruby-lsp-hint:setup-ruby-lsp`. Run that skill once, and commit
   the `docs/agents/ruby-lsp.md` it writes.

## One server per extension

If another enabled plugin declares a Ruby language server — `ruby-lsp@claude-plugins-official` is the
common one — the extension goes to whichever server registered first and the other never starts.
Nothing reports the collision. Disable the one you do not want:

```sh
claude plugin disable ruby-lsp@claude-plugins-official
```

## The project's notes are the project's file

The deny text ends by naming `docs/agents/ruby-lsp.md`, and that file belongs to the repository, not
to this package: what the server fails to resolve depends on the project's gems, on how its files are
laid out, and on what lies outside the workspace root. The `setup-ruby-lsp` skill seeds the file from
a template and the project edits it from there; the package keeps no second copy, so an install never
overwrites it. While the file is missing, the deny text names the skill instead of a path.

That file is the only one the skill writes. It reports what it finds and changes nothing else in the
repository — not the instruction file, not the `Makefile` or `Gemfile`, and it installs no gem: how a
project sets up and documents its tooling is a decision for whoever owns it.

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
