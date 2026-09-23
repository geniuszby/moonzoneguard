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

///|
fn contains_code(items : Array[Diagnostic], code : String) -> Bool {
  for item in items {
    if item.code == code {
      return true
    }
  }
  false
}

///|
fn base_zone(extra : String) -> String {
  "$ORIGIN example.org.\n$TTL 1h\n@ IN SOA ns.example.org. host.example.org. 2026092301 1h 15m 1w 1h\n@ IN NS ns.example.org.\nns IN A 192.0.2.53\n" + extra
}

///|
test "valid zone has no diagnostics" {
  let result = inspect_zone(base_zone("www IN A 192.0.2.1\n"), "example.org.")
  assert_eq(result.length(), 0)
}

///|
test "invalid IPv4 and IPv6 are diagnosed" {
  let result = inspect_zone(
    base_zone("www IN A 192.0.2.999\nwww IN AAAA 2001:::1\n"),
    "example.org.",
  )
  assert_true(contains_code(result, "Z102"))
}

///|
test "CNAME data conflict is diagnosed" {
  let result = inspect_zone(
    base_zone("alias IN CNAME www.example.org.\nalias IN A 192.0.2.3\n"),
    "example.org.",
  )
  assert_true(contains_code(result, "Z220"))
}

///|
test "CNAME cycle is diagnosed" {
  let result = inspect_zone(
    base_zone("a IN CNAME b.example.org.\nb IN CNAME a.example.org.\n"),
    "example.org.",
  )
  assert_true(contains_code(result, "Z223"))
}

///|
test "missing SOA and NS are diagnosed" {
  let result = inspect_zone("$TTL 1h\nwww IN A 192.0.2.1\n", "example.org.")
  assert_true(contains_code(result, "Z204"))
  assert_true(contains_code(result, "Z206"))
}

///|
test "mixed TTL in RRset is diagnosed" {
  let result = inspect_zone(
    base_zone("www 1h IN A 192.0.2.1\nwww 2h IN A 192.0.2.2\n"),
    "example.org.",
  )
  assert_true(contains_code(result, "Z211"))
}

///|
test "record data arity is checked" {
  let result = inspect_zone(base_zone("www IN MX 10\n"), "example.org.")
  assert_true(contains_code(result, "Z100"))
}

///|
test "address format helpers" {
  assert_true(valid_ipv4("192.0.2.1"))
  assert_true(!valid_ipv4("192.0.2.256"))
  assert_true(!valid_ipv4("192.0.2"))
  assert_true(valid_ipv6("2001:db8::1"))
  assert_true(valid_ipv6("::1"))
  assert_true(!valid_ipv6("2001:::1"))
}

///|
test "serial arithmetic handles wraparound and ambiguous half range" {
  assert_eq(parse_serial("4294967295"), Some(4294967295U))
  assert_eq(parse_serial("4294967296"), None)
  assert_eq(compare_serial(4294967295U, 0U), SerialOrder::Forward)
  assert_eq(compare_serial(10U, 9U), SerialOrder::Backward)
  assert_eq(compare_serial(0U, 2147483648U), SerialOrder::Undefined)
}

///|
test "zone diff distinguishes addition and TTL change" {
  let before = parse_zone(
    base_zone("www IN A 192.0.2.1\n"),
    "example.org.",
  )
  let after = parse_zone(
    "$ORIGIN example.org.\n$TTL 1h\n@ IN SOA ns.example.org. host.example.org. 2026092302 1h 15m 1w 1h\n@ IN NS ns.example.org.\nns IN A 192.0.2.53\nwww 2h IN A 192.0.2.1\nmail IN A 192.0.2.2\n",
    "example.org.",
  )
  let result = compare_zones(before, after)
  assert_eq(result.serial_order, Some(SerialOrder::Forward))
  assert_eq(result.changes.length(), 4)
  let mut ttl_change = false
  let mut addition = false
  for change in result.changes {
    if change.kind == "ttl-changed" && change.owner == "www.example.org." {
      ttl_change = true
    }
    if change.kind == "added" && change.owner == "mail.example.org." {
      addition = true
    }
  }
  assert_true(ttl_change && addition)
}

///|
test "unchanged SOA serial blocks modified zone" {
  let before = parse_zone(base_zone("www IN A 192.0.2.1\n"), "example.org.")
  let after = parse_zone(base_zone("www IN A 192.0.2.2\n"), "example.org.")
  let result = compare_zones(before, after)
  assert_true(contains_code(result.diagnostics, "D300"))
}
