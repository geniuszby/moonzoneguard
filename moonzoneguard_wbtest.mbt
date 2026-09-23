///|
test "lexer keeps quoted semicolon and multiline SOA together" {
  let result = lex_zone(
    "$TTL 1h\n@ IN SOA ns.example. host.example. (\n  2026092301 1h 15m 1w 1h\n)\n@ IN TXT \"a;b\" ; ignored\n",
  )
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.statements.length(), 3)
  assert_eq(result.statements[1].tokens.length(), 10)
  assert_eq(result.statements[2].tokens[3].text, "\"a;b\"")
}

///|
test "ttl combinations and overflow" {
  assert_eq(parse_ttl("1w2d3h4m5s"), Some(788645))
  assert_eq(parse_ttl("60"), Some(60))
  assert_eq(parse_ttl("2h30m"), Some(9000))
  assert_eq(parse_ttl(""), None)
  assert_eq(parse_ttl("3q"), None)
  assert_eq(parse_ttl("999999999999"), None)
}

///|
test "parse relative names and inherited owner" {
  let zone = parse_zone(
    "$ORIGIN example.org.\n$TTL 15m\n@ IN SOA ns.example.org. host.example.org. 1 1h 1h 1w 1h\nwww IN A 192.0.2.1\n  IN AAAA 2001:db8::1\n",
    "example.org.",
  )
  assert_eq(zone.diagnostics.length(), 0)
  assert_eq(zone.records.length(), 3)
  assert_eq(zone.records[1].owner, "www.example.org.")
  assert_eq(zone.records[2].owner, "www.example.org.")
  assert_eq(zone.records[2].ttl, 900)
}
