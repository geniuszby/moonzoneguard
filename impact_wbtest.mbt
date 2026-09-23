///|
fn impact_fixture(before_data : String, after_data : String) -> ChangeImpact {
  let header_before = "@ IN SOA ns.example.org. host.example.org. 1 1h 1h 1w 1h\n@ IN NS ns.example.org.\nns IN A 192.0.2.1\n"
  let header_after = "@ IN SOA ns.example.org. host.example.org. 2 1h 1h 1w 1h\n@ IN NS ns.example.org.\nns IN A 192.0.2.1\n"
  let before = parse_zone(header_before + before_data, "example.org.")
  let after = parse_zone(header_after + after_data, "example.org.")
  assess_impact(compare_zones(before, after), "example.org.")
}

///|
test "serial-only revision has low review priority" {
  let impact = impact_fixture("", "")
  assert_eq(impact.score, 0)
  assert_eq(impact.level, "low")
  assert_eq(impact.changed_owners, 0)
}

///|
test "address replacement counts one changed owner" {
  let impact = impact_fixture("www IN A 192.0.2.5\n", "www IN A 192.0.2.6\n")
  assert_eq(impact.changed_owners, 1)
  assert_eq(impact.added, 1)
  assert_eq(impact.removed, 1)
  assert_eq(impact.level, "medium")
}

///|
test "apex nameserver removal is high priority" {
  let before = parse_zone(
    "@ IN SOA ns.example.org. host.example.org. 1 1h 1h 1w 1h\n@ IN NS ns.example.org.\n@ IN NS ns2.example.org.\n",
    "example.org.",
  )
  let after = parse_zone(
    "@ IN SOA ns.example.org. host.example.org. 2 1h 1h 1w 1h\n@ IN NS ns.example.org.\n",
    "example.org.",
  )
  let impact = assess_impact(compare_zones(before, after), "example.org.")
  assert_eq(impact.level, "medium")
  assert_eq(impact.notes[0].category, "delegation")
  assert_eq(impact.notes[1].category, "removal")
}

///|
test "unchanged serial contributes an impact note" {
  let before = parse_zone(
    "@ IN SOA ns.example.org. host.example.org. 1 1h 1h 1w 1h\n@ IN NS ns.example.org.\n",
    "example.org.",
  )
  let after = parse_zone(
    "@ IN SOA ns.example.org. host.example.org. 1 1h 1h 1w 1h\n@ IN NS ns.example.org.\nwww IN A 192.0.2.1\n",
    "example.org.",
  )
  let impact = assess_impact(compare_zones(before, after), "example.org.")
  assert_eq(impact.level, "medium")
  assert_eq(impact.notes[impact.notes.length() - 1].category, "serial")
}

///|
test "impact renderers include score and category" {
  let impact = impact_fixture("", "@ IN CAA 0 issue \"ca.example\"\n")
  let text = render_impact_text(impact)
  let json = render_impact_json(impact)
  assert_eq(text.contains("certificate"), true)
  assert_eq(json.contains("\"category\":\"certificate\""), true)
  assert_eq(json.contains("\"score\":3"), true)
}
