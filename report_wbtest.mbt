///|
test "empty diagnostic report is valid json" {
  let items : Array[Diagnostic] = []
  assert_eq(
    render_diagnostics_json(items),
    "{\"errors\":0,\"warnings\":0,\"diagnostics\":[]}",
  )
}

///|
test "diagnostic json escapes control characters" {
  let items = [
    diagnostic(
      "T001",
      "error",
      "quote \" slash \\ newline\n tab\t",
      2,
      3,
      owner="a.example.org.",
    ),
  ]
  let rendered = render_diagnostics_json(items)
  assert_eq(rendered.contains("\\\""), true)
  assert_eq(rendered.contains("\\\\"), true)
  assert_eq(rendered.contains("\\n"), true)
  assert_eq(rendered.contains("\\t"), true)
  assert_eq(rendered.contains("\"line\":2"), true)
  assert_eq(rendered.contains("\"column\":3"), true)
}

///|
test "diagnostic counters distinguish errors and warnings" {
  let items = [
    diagnostic("T001", "error", "error", 1, 1),
    diagnostic("T002", "warning", "warning", 2, 1),
    diagnostic("T003", "note", "note", 3, 1),
  ]
  assert_eq(error_count(items), 1)
  assert_eq(warning_count(items), 1)
  let rendered = render_diagnostics_json(items)
  assert_eq(rendered.contains("\"errors\":1"), true)
  assert_eq(rendered.contains("\"warnings\":1"), true)
}

///|
test "text report includes location and owner" {
  let items = [
    diagnostic(
      "T004",
      "warning",
      "check target",
      10,
      7,
      owner="www.example.org.",
    ),
  ]
  let rendered = render_diagnostics_text(items)
  assert_eq(rendered.contains("10:7: warning T004"), true)
  assert_eq(rendered.contains("[www.example.org.]"), true)
  assert_eq(rendered.contains("0 error(s), 1 warning(s)"), true)
}

///|
test "markdown report escapes table separators" {
  let items = [diagnostic("T005", "error", "left|right", 1, 1)]
  let rendered = render_diagnostics_markdown(items)
  assert_eq(rendered.contains("left\\|right"), true)
  assert_eq(rendered.contains("| Location | Severity | Rule | Finding |"), true)
}

///|
test "markdown report has an explicit empty row" {
  let items : Array[Diagnostic] = []
  let rendered = render_diagnostics_markdown(items)
  assert_eq(rendered.contains("No findings"), true)
  assert_eq(rendered.contains("Errors: 0"), true)
}

///|
test "diff report describes added and removed addresses" {
  let before = parse_zone("www IN A 192.0.2.1\n", "example.org.")
  let after = parse_zone("www IN A 192.0.2.2\n", "example.org.")
  let diff = compare_zones(before, after)
  let text = render_diff_text(diff)
  let json = render_diff_json(diff)
  assert_eq(text.contains("removed www.example.org. A 192.0.2.1"), true)
  assert_eq(text.contains("added www.example.org. A 192.0.2.2"), true)
  assert_eq(json.contains("\"kind\":\"removed\""), true)
  assert_eq(json.contains("\"kind\":\"added\""), true)
}

///|
test "diff report describes ttl change without removal" {
  let before = parse_zone("www 1h IN A 192.0.2.1\n", "example.org.")
  let after = parse_zone("www 2h IN A 192.0.2.1\n", "example.org.")
  let diff = compare_zones(before, after)
  assert_eq(diff.changes.length(), 1)
  assert_eq(diff.changes[0].kind, "ttl-changed")
  let text = render_diff_text(diff)
  let json = render_diff_json(diff)
  assert_eq(text.contains("ttl 3600 -> 7200"), true)
  assert_eq(json.contains("\"before_ttl\":3600"), true)
  assert_eq(json.contains("\"after_ttl\":7200"), true)
}
