///|
test "ttl accepts seconds and compact units" {
  assert_eq(parse_ttl("0"), Some(0))
  assert_eq(parse_ttl("1s"), Some(1))
  assert_eq(parse_ttl("1m"), Some(60))
  assert_eq(parse_ttl("1h"), Some(3600))
  assert_eq(parse_ttl("1d"), Some(86400))
  assert_eq(parse_ttl("1w"), Some(604800))
}

///|
test "ttl accepts mixed units and case variants" {
  assert_eq(parse_ttl("1w2d3h4m5s"), Some(788645))
  assert_eq(parse_ttl("1W2D3H4M5S"), Some(788645))
  assert_eq(parse_ttl("2h30m"), Some(9000))
}

///|
test "ttl rejects missing amount or unknown unit" {
  assert_eq(parse_ttl(""), None)
  assert_eq(parse_ttl("h"), None)
  assert_eq(parse_ttl("1q"), None)
  assert_eq(parse_ttl("1hms"), None)
}

///|
test "ttl rejects negative and fractional values" {
  assert_eq(parse_ttl("-1"), None)
  assert_eq(parse_ttl("1.5h"), None)
  assert_eq(parse_ttl("+1"), None)
}

///|
test "ttl enforces signed-int overflow boundary" {
  assert_eq(parse_ttl("2147483647"), Some(2147483647))
  assert_eq(parse_ttl("2147483648"), None)
  assert_eq(parse_ttl("999999999999999"), None)
}

///|
test "ttl rejects overflow caused by unit multiplication" {
  assert_eq(parse_ttl("3550w"), Some(2147040000))
  assert_eq(parse_ttl("3551w"), None)
}

///|
test "ttl rejects overflow across compact terms" {
  assert_eq(parse_ttl("3550w7d"), None)
  assert_eq(parse_ttl("2147483640s8s"), None)
  assert_eq(parse_ttl("2147483640s7s"), Some(2147483647))
}

///|
test "ttl directive reports invalid input and preserves default" {
  let zone = parse_zone(
    "$TTL 1h\na IN A 192.0.2.1\n$TTL 5000000000\nb IN A 192.0.2.2\n", "example.org.",
  )
  assert_eq(contains_code(zone.diagnostics, "Z012"), true)
  assert_eq(zone.records[0].ttl, 3600)
  assert_eq(zone.records[1].ttl, 3600)
}
