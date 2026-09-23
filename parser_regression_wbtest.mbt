///|
test "origin starts as the supplied zone name" {
  let zone = parse_zone("@ IN NS ns\n", "Example.Org")
  assert_eq(zone.origin, "example.org.")
  assert_eq(zone.records[0].owner, "example.org.")
  assert_eq(zone.records[0].origin, "example.org.")
}

///|
test "origin directive changes following relative names" {
  let zone = parse_zone(
    "$ORIGIN example.org.\na IN CNAME b\n$ORIGIN sub.example.org.\nc IN CNAME d\n",
    "example.org.",
  )
  assert_eq(zone.records[0].owner, "a.example.org.")
  assert_eq(zone.records[1].owner, "c.sub.example.org.")
  assert_eq(zone.records[1].origin, "sub.example.org.")
}

///|
test "ttl directive sets default for subsequent records" {
  let zone = parse_zone(
    "$TTL 30m\na IN A 192.0.2.1\n$TTL 2h\nb IN A 192.0.2.2\n", "example.org.",
  )
  assert_eq(zone.records[0].ttl, 1800)
  assert_eq(zone.records[1].ttl, 7200)
}

///|
test "record ttl overrides default only for that record" {
  let zone = parse_zone(
    "$TTL 1h\na 30m IN A 192.0.2.1\nb IN A 192.0.2.2\n", "example.org.",
  )
  assert_eq(zone.records[0].ttl, 1800)
  assert_eq(zone.records[1].ttl, 3600)
}

///|
test "class and ttl may occur in either order" {
  let zone = parse_zone(
    "a IN 2h A 192.0.2.1\nb 2h IN A 192.0.2.2\n", "example.org.",
  )
  assert_eq(zone.diagnostics.length(), 0)
  assert_eq(zone.records[0].ttl, 7200)
  assert_eq(zone.records[1].ttl, 7200)
}

///|
test "indented line inherits preceding owner" {
  let zone = parse_zone(
    "www IN A 192.0.2.1\n  IN AAAA 2001:db8::1\n", "example.org.",
  )
  assert_eq(zone.records[0].owner, zone.records[1].owner)
}

///|
test "indented first record cannot inherit an owner" {
  let zone = parse_zone("  IN A 192.0.2.1\n", "example.org.")
  assert_eq(contains_code(zone.diagnostics, "Z020"), true)
  assert_eq(zone.records.length(), 0)
}

///|
test "missing rdata is reported" {
  let zone = parse_zone("www IN A\n", "example.org.")
  assert_eq(contains_code(zone.diagnostics, "Z025"), true)
}

///|
test "unsupported directives are explicit errors" {
  let zone = parse_zone(
    "$INCLUDE other.zone\n$GENERATE 1-3 host$ A 192.0.2.$\n", "example.org.",
  )
  assert_eq(zone.diagnostics.length(), 2)
  assert_eq(zone.diagnostics[0].code, "Z013")
  assert_eq(zone.diagnostics[1].code, "Z013")
}

///|
test "unmatched parentheses are reported" {
  let left = parse_zone("@ IN TXT ( \"hello\"\n", "example.org.")
  let right = parse_zone("@ IN TXT \"hello\" )\n", "example.org.")
  assert_eq(contains_code(left.diagnostics, "Z004"), true)
  assert_eq(contains_code(right.diagnostics, "Z002"), true)
}

///|
test "quoted semicolon is not a comment" {
  let zone = parse_zone(
    "@ IN TXT \"hello;world\" ; this is a comment\n", "example.org.",
  )
  assert_eq(zone.diagnostics.length(), 0)
  assert_eq(zone.records[0].rdata[0], "\"hello;world\"")
}

///|
test "diff refuses a malformed before zone" {
  let before = parse_zone("$INCLUDE other.zone\n", "example.org.")
  let after = parse_zone("www IN A 192.0.2.1\n", "example.org.")
  let result = compare_zones(before, after)
  assert_eq(result.changes.length(), 0)
  assert_eq(contains_code(result.diagnostics, "D010"), true)
}

///|
test "diff refuses a malformed after zone" {
  let before = parse_zone("www IN A 192.0.2.1\n", "example.org.")
  let after = parse_zone("$INCLUDE other.zone\n", "example.org.")
  let result = compare_zones(before, after)
  assert_eq(result.changes.length(), 0)
  assert_eq(contains_code(result.diagnostics, "D011"), true)
}
