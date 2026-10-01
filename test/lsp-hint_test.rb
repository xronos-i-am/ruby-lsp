#!/usr/bin/env ruby
# frozen_string_literal: true

# The hook gets edited more often than it gets checked, and every hole it ever had — a search
# behind a separator standing flush, a call by path, a pickaxe flush against the name — was found
# by measurement in a live session, that is, after a search had already walked past the deny.
# The cases stand here as a list so that an edit is checked by a run: below, one hook input is
# one expectation.
#
# Run: test/lsp-hint_test.rb [-n /substring/]
# Neither Bundler nor a framework is needed: minitest comes with ruby, and the hook is called as
# a process with its own TMPDIR, so the run depends on no application and no live session.

require "minitest/autorun"
require "json"
require "open3"
require "tmpdir"
require "fileutils"

class LspHintTest < Minitest::Test
  HOOK = File.expand_path("../hooks/lsp-hint.sh", __dir__)

  # The mark lives in TMPDIR, and every test gets its own: a mark left by one case would silence
  # the hook in the next one. The session id in the input is therefore one for the whole file
  def setup
    @marks = Dir.mktmpdir("lsp-marks")
  end

  def teardown
    FileUtils.remove_entry(@marks)
  end

  # ── Symbol search is denied ────────────────────────────────────────────────────────────────

  def test_searcher_by_name_is_denied
    assert denied?("grep User app")
    assert denied?("rg User")
    assert denied?("git grep User")
    assert denied?("ack User app")
    assert denied?("ag User app")
  end

  # These two carry a letter before `grep`, so a word boundary let them through — measurement
  # showed both walking past the hook
  def test_egrep_and_fgrep_are_denied
    assert denied?("egrep User app")
    assert denied?("fgrep User app")
  end

  # A command name lives as the tail after the last slash
  def test_searcher_called_by_path_is_denied
    assert denied?("/usr/bin/grep User app")
  end

  # The target of the command is not parsed at all, and a recursive search with no extension in
  # the line is exactly the case the former target parsing leaked on
  def test_recursive_search_without_extension_is_denied
    assert denied?("grep -rn User .")
  end

  # Flags hide no pattern, because the pattern is not looked for: the fact of searching is denied
  def test_flags_do_not_hide_the_search
    assert denied?("grep -e User app")
    assert denied?("grep -rn --include=*.rb User .")
    assert denied?("grep -A 3 User app/models")
    assert denied?("rg -m 5 User")
  end

  # A quote belongs to the command, not to the pattern: a quoted name stays a name
  def test_quoted_symbol_is_denied
    assert denied?("grep 'User' app")
    assert denied?('grep "User" app')
    assert denied?("grep -e 'User' app")
    assert denied?("git log -S 'User'")
  end

  # A separator and a substitution stand flush against the command name: all three forms of
  # `cat x;grep Name` walked past the hook
  def test_command_start_after_separator_and_substitution
    assert denied?("cat x;grep User app")
    assert denied?("ls&&grep User app")
    assert denied?("cat x|grep User")
    assert denied?("echo $(grep User app)")
    assert denied?("echo `grep User app`")
  end

  # ── The git pickaxe ────────────────────────────────────────────────────────────────────────

  # Three forms of the flag, one command: the name stands behind a space, behind `=` and flush
  def test_pickaxe_is_a_search
    assert denied?("git log -S User")
    assert denied?("git log -S=User")
    assert denied?("git log -SUser")
    assert denied?("git diff -G User")
  end

  def test_git_log_without_pickaxe_passes
    refute denied?("git log --oneline -15")
    refute denied?("git log -p app/models/user.rb")
  end

  # ── Line processors: addressing decides, not the command name ──────────────────────────────

  def test_scanner_with_slash_pattern_is_denied
    assert denied?("sed -n '/User/p' app/models/user.rb")
    assert denied?("awk '/User/' app/models/user.rb")
    assert denied?("perl -ne 'print if /User/' user.rb")
  end

  # A line range is reading a file, and `sed -n '10,20p'` beats any LSP call at it
  def test_scanner_addressed_by_line_number_passes
    refute denied?("sed -n '10,20p' app/models/user.rb")
    refute denied?("sed -n 1,200p README.md")
  end

  # ── Text search the hook leaves alone ──────────────────────────────────────────────────────

  # Quotes with a space inside give a phrase away: `def average_price` names a phrase, not a symbol
  def test_phrase_with_space_passes
    refute denied?("grep 'GROUP BY total' db/schema.rb")
    refute denied?('grep "GROUP BY total" db/schema.rb')
    refute denied?("grep -rn 'def average_price' app")
  end

  def test_non_searching_command_passes
    refute denied?("ls app/models")
    refute denied?("cat app/models/user.rb")
  end

  # ── The Grep tool: the pattern is a field ──────────────────────────────────────────────────

  # An anchor, a word boundary, a bracket and an escaped dot do not stop a name from being one,
  # while the former regexp over "a proper name" lost the deny on each of them
  def test_grep_tool_pattern_field
    assert pattern_denied?("User")
    assert pattern_denied?('\bUser\b')
    assert pattern_denied?('^User\.new')
  end

  # One symbolic alternative is enough: neighbouring prose adds no legitimacy to the grep
  def test_alternation_with_a_symbol_is_denied
    assert pattern_denied?('User\|Order')
    assert pattern_denied?("User|Order")
    assert pattern_denied?('User\|SCAN orders')
  end

  def test_alternation_of_phrases_passes
    refute pattern_denied?('SCAN orders\|USING INDEX')
  end

  # ── The mark: an LSP call silences the hook until the session ends ─────────────────────────

  # Which request reached the tool does not matter, and neither does which name it asked about:
  # it was reached, so text search is legitimate from here on
  def test_lsp_call_silences_the_hook
    assert denied?("grep User app")

    lsp_query("User")

    refute denied?("grep User app")
    refute denied?("grep Order app")
    refute pattern_denied?('User\|Order')
  end

  # A request by cursor position carries no name in its input at all, and the mark no longer needs one
  def test_position_request_silences_the_hook_too
    lsp_cursor("app/models/user.rb", line: 2, character: 12)

    refute denied?("grep Order app")
  end

  # ── The notes the deny text points at ──────────────────────────────────────────────────────

  # The two cases below are the only ones that read the wording, and they read one path out of it:
  # which file the agent is sent to is a decision of the hook, not a turn of phrase

  def test_project_notes_are_named_when_they_exist
    Dir.mktmpdir("lsp-project") do |project|
      FileUtils.mkdir_p("#{project}/docs/agents")
      File.write("#{project}/docs/agents/ruby-lsp.md", "# notes\n")

      assert_includes reason("grep User app", project:), "docs/agents/ruby-lsp.md"
    end
  end

  def test_setup_skill_is_named_while_the_notes_are_missing
    Dir.mktmpdir("lsp-project") do |project|
      assert_includes reason("grep User app", project:), "setup-ruby-lsp"
    end
  end

  private

  def denied?(command)
    deny?(hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: { command: })
  end

  def pattern_denied?(pattern)
    deny?(hook_event_name: "PreToolUse", tool_name: "Grep", tool_input: { pattern: })
  end

  def lsp_query(query)
    deny?(hook_event_name: "PostToolUse", tool_name: "LSP", tool_input: { query: })
  end

  def lsp_cursor(file, line:, character:)
    deny?(
      hook_event_name: "PostToolUse",
      tool_name: "LSP",
      tool_input: { filePath: file, line:, character: },
    )
  end

  def reason(command, project:)
    out = run_hook(
      { hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: { command: } },
      "CLAUDE_PROJECT_DIR" => project,
    )
    refute_empty out, "the hook let the search through, there is no deny text to read"
    JSON.parse(out).dig("hookSpecificOutput", "permissionDecisionReason")
  end

  # The hook has two decisions — deny or silence — and nothing else, so apart from the two cases
  # above there is nothing in the wording for a test to hold on to
  def deny?(payload)
    out = run_hook(payload)
    return false if out.empty?

    assert_equal "deny", JSON.parse(out).dig("hookSpecificOutput", "permissionDecision"),
                 "unclear decision: #{out}"
    true
  end

  def run_hook(payload, env = {})
    out, err, status = Open3.capture3(
      { "TMPDIR" => @marks }.merge(env),
      HOOK,
      stdin_data: JSON.dump(payload.merge(session_id: "test")),
    )
    assert status.success?, "the hook died with code #{status.exitstatus}: #{err}"
    out.strip
  end
end
