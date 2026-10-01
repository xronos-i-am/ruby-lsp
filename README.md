# ruby-lsp

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
| `skills/ruby-lsp-setup` | A one-off setup run: checks the server can start, finds a plugin that claims the same extensions, and writes the project's own `docs/agents/ruby-lsp.md` |

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

Three more conditions, none of which announces itself when unmet:

- **Anthropic's official `ruby-lsp` plugin has to be off.** It declares the same server as this
  package, so with both enabled two declarations claim the same extensions and one of them is never
  used. [Turn off the official plugin](#turn-off-the-official-ruby-lsp-plugin) has the command.
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

  A project with no `Gemfile` installs it globally instead, `gem install ruby-lsp`, and writes that
  down where its setup is described. The server is [Shopify's
  ruby-lsp](https://github.com/Shopify/ruby-lsp); its [documentation](https://shopify.github.io/ruby-lsp/)
  covers the addons, the `.ruby-lsp/` bundle it generates, and the editor features behind each request.
- **A project-scope plugin needs workspace trust and a session started at the repository root.** It
  does not load from a subdirectory, and it does not load until you accept the trust dialog for the
  folder.

## Install with APM

1. Declare the dependency:

   ```yaml
   # apm.yml
   dependencies:
     apm:
       - xronos-i-am/ruby-lsp
   ```

2. `apm install`. It reports `Configured 1 LSP server` and the hook entries it merged.
3. Turn the official plugin off if it is on — `claude plugin list` says, and
   [the section below](#turn-off-the-official-ruby-lsp-plugin) says why.
4. `/reload-plugins`, or start the next session. Hooks are read at session start, so the deny begins
   working in the next session either way.
5. Run the `ruby-lsp-setup` skill once, and commit the `docs/agents/ruby-lsp.md` it writes.

What lands in the project:

```
.claude/skills/apm-lsp/.claude-plugin/plugin.json   the server declaration, auto-discovered
.claude/settings.json                               the hook entries, merged by APM
.claude/hooks/ruby-lsp/hooks/                  the hook script and its design notes
.claude/skills/ruby-lsp-setup/                      the setup skill and the seed notes
```

APM owns those files and rewrites them on the next install, so edits belong in the package or in the
project's own files — never in the deployed copies.

A later `apm install` reproduces `apm.lock.yaml` instead of looking for new commits: with `apm.yml`
unchanged it does not reach the remote at all. It clones the commit the lockfile records and
reconciles the deployed copies against it — a hand-edited `.claude/hooks/ruby-lsp/hooks/lsp-hint.sh`
is restored, a newer revision of the package is not fetched. That one comes from `apm update`
(`--dry-run` for the plan, `--yes` outside an interactive shell). `apm outdated` does not help here: a
dependency tracked by branch prints `Latest: -` and `Status: unknown`.

## Install as a Claude Code plugin

The repository is also a one-plugin marketplace, so APM is not required. Nothing is copied into the
project on this route: Claude Code runs the plugin from its own directory and resolves
`${CLAUDE_PLUGIN_ROOT}` itself.

1. **Add the marketplace.** In your shell:

   ```sh
   claude plugin marketplace add xronos-i-am/ruby-lsp
   ```

   In a session the same source works as `/plugin marketplace add xronos-i-am/ruby-lsp`. Add
   `#<ref>` to pin a branch or tag. While the repository is private, Claude Code clones it with the
   git credentials already on your machine and never prompts: for the `owner/repo` shorthand it
   probes whether your SSH key authenticates to `github.com` and clones over SSH when it does.

2. **Install it, choosing who gets it.** From your shell, where the default scope is yourself on this
   machine:

   ```sh
   claude plugin install ruby-lsp@xronos-i-am                   # you, every project
   claude plugin install ruby-lsp@xronos-i-am --scope project   # everyone in this repository
   claude plugin install ruby-lsp@xronos-i-am --scope local     # you, this repository only
   ```

   In a session, `/plugin install ruby-lsp@xronos-i-am` opens the plugin's details so you can
   review what it adds and pick the scope there. On Claude Code 2.1.275 or later the two steps
   collapse into one, with the plugin named without its `@marketplace` half:

   ```text
   /plugin install ruby-lsp --marketplace xronos-i-am/ruby-lsp
   ```

3. **For a repository, mind what `--scope project` does and does not do.** It writes the entry to
   `.claude/settings.json`, which you commit, and that turns the plugin on for your collaborators —
   but it does not download it to their machines. Each of them runs the install command once too.

4. **Turn the official plugin off** if it is on: it declares the same server, and
   [the section below](#turn-off-the-official-ruby-lsp-plugin) says what happens when both are on.

5. **Activate.** `/reload-plugins`, or start the next session.

6. **Check it arrived.** `claude plugin list` prints the plugin with its version, scope and status,
   and typing `/` shows its skill as `/ruby-lsp:ruby-lsp-setup`. Run that skill once, and commit
   the `docs/agents/ruby-lsp.md` it writes.

## Removal

The APM route is two commands, and the second one is not optional:

```sh
apm uninstall xronos-i-am/ruby-lsp
apm install
```

`apm uninstall` takes the entry out of `apm.yml`, the copy out of `apm_modules/`, the deployed hook
and skill files out of `.claude/`, and the hook entries it had merged out of `.claude/settings.json`.
What it leaves behind is the server declaration: on APM 0.32.0 it ends with
`Uninstall incomplete: … LSP cleanup failed`, and `.claude/skills/apm-lsp/.claude-plugin/plugin.json`
still declares `ruby-lsp`, as does `apm.lock.yaml`. The `apm install` that follows reconciles it —
`Removed 1 stale LSP server (ruby-lsp)` — and removes the `apm-lsp` directory with it. Skip that step
and the hook is gone while the server keeps starting: the one combination nothing reports. The
`apm_modules/` line the install added to `.gitignore` stays either way.

`--dry-run` prints the removal plan without touching anything, and `-g` removes a package installed
into user scope, `~/.apm/`, instead of the project's.

On the plugin route the scope is spelled out, because `uninstall` defaults to `user` while the entry
that makes the plugin a repository's own sits in `.claude/settings.json`:

```sh
claude plugin uninstall ruby-lsp@xronos-i-am --scope project
claude plugin marketplace remove xronos-i-am                   # once no plugin is left using it
```

Nothing was copied into the project on that route, so there is nothing else to clean up.

Two things stay behind on purpose, whichever route you used: `docs/agents/ruby-lsp.md` is the
repository's own file and was never the package's to delete, and the official plugin stays disabled
until you turn it back on with `claude plugin enable ruby-lsp@claude-plugins-official`.

## Turn off the official ruby-lsp plugin

```sh
claude plugin disable ruby-lsp@claude-plugins-official
```

`ruby-lsp@claude-plugins-official` is a declaration, not a server: its plugin directory holds a
LICENSE and a README, and everything else is the `lspServers` block in the marketplace entry. This
package declares the same thing — the same `ruby-lsp` command, the same five extensions — so the two
do not complement each other, they compete for `.rb`.

With both enabled, whichever registered first serves those files and the other is not used for them.
The `/plugin` **Errors** tab shows `LSP server "ruby-lsp" is not used for .rb files`, nothing else
reports it, and which of the two answered a given call cannot be told apart. `claude plugin list`
shows what is enabled.

What this package gives in its place is where the declaration lives: in the repository, in `apm.yml`,
so `apm install` restores it on any machine, while the official plugin is installed machine by
machine. That is the whole trade — the server binary is the same gem either way.

## The project's notes are the project's file

The deny text ends by naming `docs/agents/ruby-lsp.md`, and that file belongs to the repository, not
to this package: what the server fails to resolve depends on the project's gems, on how its files are
laid out, and on what lies outside the workspace root. The `ruby-lsp-setup` skill seeds the file from
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
