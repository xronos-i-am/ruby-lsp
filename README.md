# ruby-lsp

[По-русски](README.ru.md)

Ruby language server for Claude Code: code navigation and analysis.

Anthropic's [official `ruby-lsp` plugin](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/ruby-lsp)
goes no further than one declaration of the [ruby-lsp](https://github.com/Shopify/ruby-lsp) language server, and that is not enough.
The system prompt tells the agent to search with `grep`. On top of that the LSP server's tools initialize lazily,
and the lookup path through them loses to `grep`, which is in the tool list from the first second of the session.
Because of that the `LSP` tool gets called only if you ask for it in so many words. This plugin solves that problem.

## Supported Extensions

`.rb`, `.rake`, `.gemspec`, `.ru`, `.erb`

## Installation

### Via Bundler (recommended)

Add to your Gemfile:

```ruby
gem 'ruby-lsp', group: :development
```

Then run:

```sh
bundle install
```

Installing through `bundler` keeps `ruby-lsp` on the `ruby` version the project uses.
Left out of sync, the two drift apart. The failure is
silent: Claude Code shuts the lsp server down after three failed starts and does not bring it up again.

### Via gem

```sh
gem install ruby-lsp
```

## How it works

Which tool gets called is not deterministic in agentic development. The LLM decides for itself whether to call one at any
given moment. That is why instructions of the "use LSP" kind in CLAUDE.md work poorly. For strict execution
there are [hooks](https://code.claude.com/docs/en/hooks-guide).

### A hook on the Bash/Grep tools

A `PreToolUse` hook on the Bash and Grep tools runs the `lsp-hint.sh` script. Its job is to
tell whether the input is a command searching for **symbols** in ruby code. The script has two outcomes: stay silent,
and then the ordinary text search runs as it is, or refuse the call
(`permissionDecision: deny`). In the latter case the agent gets the reason for the refusal,
pointing at the LSP tool and at `docs/agents/ruby-lsp.md`, where the server's quirks in your project are written down.

A `PostToolUse` hook sets a session mark after LSP has been used, and on later `PreToolUse` calls that mark saves
going through the choice again and again. Our goal is to remind the agent that LSP is there, and doing that twice is not required.

### What counts as a symbol

The `lsp-hint.sh` script, which decides what a symbol is (a class, method or constant name), has to be as simple and as fast as possible.
Elaborate heuristics or parsing the command's syntax tree are out of the question here. Hence a simple convention:
**a symbol is text with no space in it**. For instance, `grep User` is a search by
symbol, which LSP intercepts. `grep 'GROUP BY total'` is what ordinary text search handles.

## Requirements

- Ruby >= 3.0 — `ruby-lsp`'s own floor
- Claude Code >= 2.1.157
- APM >= 0.29.1 — for installing through APM (optional)
- `bash` and `jq` — the hook is written in bash and parses its input with `jq`

## Installing the package

If the [official `ruby-lsp` plugin](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/ruby-lsp) is enabled,
it has to be turned off to rule out a collision of declarations.

### Turn off the official `ruby-lsp`

```sh
claude plugin disable ruby-lsp@claude-plugins-official
```

### Add the package through [Agent Package Manager](https://microsoft.github.io/apm/)

Declare the dependency in `apm.yml`:

```yaml
dependencies:
 apm:
   - xronos-i-am/ruby-lsp
```

```sh
apm install
```

or

```sh
apm update
```

if `apm` has already locked the package set (`apm.lock.yaml`)

### Reload the plugins, or open a new session

```
/reload-plugins
```

### Run the setup in the agent

Run the `/ruby-lsp-setup` skill once. It checks that the installation is correct, and it also adds the `docs/agents/ruby-lsp.md` notes.
There you can additionally describe what is particular about using LSP in your own project.

### Check that it works

Open a new agent session and give it the prompt:

```prompt
grep User
```

If the setup went well, you will see a mention of LSP, whose call overrides the search with `grep`.

## Installing as a Claude Code plugin

```sh
claude plugin marketplace add xronos-i-am/ruby-lsp
claude plugin install ruby-lsp@xronos-i-am --scope project
```

On this route the skills carry the plugin's prefix: `/ruby-lsp:ruby-lsp-setup` and `/ruby-lsp:ruby-lsp-feedback`.

## Removal

```sh
apm uninstall xronos-i-am/ruby-lsp
apm install
```

The second command is not to be skipped here: `apm uninstall` leaves the server declaration behind. The hook is gone, and the server keeps starting.

```sh
claude plugin uninstall ruby-lsp@xronos-i-am --scope project
claude plugin marketplace remove xronos-i-am
```

## Troubleshooting

If you see no mention of the LSP tools in a session, you can run the `/ruby-lsp-feedback` skill to diagnose it.
It collects what is needed, and that can then go into [issues](https://github.com/xronos-i-am/ruby-lsp/issues).

## Development

```sh
test/lsp-hint_test.rb                 # the whole suite
test/lsp-hint_test.rb -n /pickaxe/    # cases by a substring of the name
```

What each decision costs and what the hook lets through on purpose — [`hooks/lsp-hint.md`](hooks/lsp-hint.md).

## License

MIT, see [LICENSE](LICENSE).
