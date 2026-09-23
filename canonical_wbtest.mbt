///|
test "canonical output expands names and explicit ttl" {
  let zone = parse_zone(
    "$ORIGIN example.org.\n$TTL 1h\n@ IN SOA ns host 1 1h 1h 1w 1h\n@ IN NS ns\nns IN A 192.0.2.1\n",
    "example.org.",
  )
  let text = render_canonical_zone(zone)
  assert_eq(
    text.contains("example.org. 3600 IN SOA ns.example.org. host.example.org."),
    true,
  )
  assert_eq(text.contains("example.org. 3600 IN NS ns.example.org."), true)
}

///|
test "canonical output uses origin active at each record" {
  let zone = parse_zone(
    "$ORIGIN example.org.\na IN CNAME b\n$ORIGIN sub.example.org.\nc IN CNAME d\n",
    "example.org.",
  )
  let text = render_canonical_zone(zone)
  assert_eq(text.contains("a.example.org. 3600 IN CNAME b.example.org."), true)
  assert_eq(
    text.contains("c.sub.example.org. 3600 IN CNAME d.sub.example.org."),
    true,
  )
}

///|
test "canonical output round-trips common records" {
  let original = parse_zone(
    "$ORIGIN example.org.\n@ IN SOA ns host 1 1h 1h 1w 1h\n@ IN NS ns\nns IN A 192.0.2.1\nwww IN TXT \"Hello World\"\n",
    "example.org.",
  )
  let reparsed = parse_zone(render_canonical_zone(original), "example.org.")
  assert_eq(reparsed.diagnostics.length(), 0)
  assert_eq(reparsed.records.length(), original.records.length())
  assert_eq(render_canonical_zone(reparsed), render_canonical_zone(original))
}

///|
test "text case change appears in zone diff" {
  let before = parse_zone("www IN TXT \"Hello\"\n", "example.org.")
  let after = parse_zone("www IN TXT \"hello\"\n", "example.org.")
  let diff = compare_zones(before, after)
  assert_eq(diff.changes.length(), 2)
}

///|
test "relative and absolute domain-valued rdata compare equally" {
  let before = parse_zone("www IN CNAME host\n", "example.org.")
  let after = parse_zone("www IN CNAME host.example.org.\n", "example.org.")
  let diff = compare_zones(before, after)
  assert_eq(diff.changes.length(), 0)
}
