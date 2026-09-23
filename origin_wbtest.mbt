///|
test "invalid initial zone origin is reported" {
  let zone = parse_zone("www IN A 192.0.2.1\n", "bad..example.org.")
  assert_eq(contains_code(zone.diagnostics, "Z030"), true)
}

///|
test "valid initial origin remains accepted" {
  let zone = parse_zone("www IN A 192.0.2.1\n", "example.org.")
  assert_eq(contains_code(zone.diagnostics, "Z030"), false)
  assert_eq(zone.records[0].owner, "www.example.org.")
}

///|
test "invalid origin directive does not corrupt following names" {
  let zone = parse_zone(
    "$ORIGIN bad..example.org.\nwww IN A 192.0.2.1\n", "example.org.",
  )
  assert_eq(contains_code(zone.diagnostics, "Z031"), true)
  assert_eq(zone.records[0].owner, "www.example.org.")
}

///|
test "valid relative origin directive expands against current origin" {
  let zone = parse_zone("$ORIGIN sub\nwww IN A 192.0.2.1\n", "example.org.")
  assert_eq(zone.diagnostics.length(), 0)
  assert_eq(zone.records[0].owner, "www.sub.example.org.")
}
