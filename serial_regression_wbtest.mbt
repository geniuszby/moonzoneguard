///|
fn serial_zone(serial : String, extra : String) -> Zone {
  parse_zone(
    "@ IN SOA ns.example.org. host.example.org. " +
    serial +
    " 1h 1h 1w 1h\n@ IN NS ns.example.org.\nns IN A 192.0.2.1\n" +
    extra,
    "example.org.",
  )
}

///|
test "serial parser accepts zero and uint32 maximum" {
  assert_eq(parse_serial("0"), Some(0U))
  assert_eq(parse_serial("1"), Some(1U))
  assert_eq(parse_serial("4294967295"), Some(4294967295U))
}

///|
test "serial parser rejects empty and nondecimal input" {
  assert_eq(parse_serial(""), None)
  assert_eq(parse_serial("+1"), None)
  assert_eq(parse_serial("-1"), None)
  assert_eq(parse_serial("1.0"), None)
  assert_eq(parse_serial("one"), None)
}

///|
test "serial parser rejects overflow" {
  assert_eq(parse_serial("4294967296"), None)
  assert_eq(parse_serial("999999999999999"), None)
}

///|
test "serial parser accepts leading zeros as decimal" {
  assert_eq(parse_serial("0001"), Some(1U))
  assert_eq(parse_serial("0000000000"), Some(0U))
}

///|
test "serial equality is symmetric" {
  assert_eq(compare_serial(0U, 0U), SerialOrder::Same)
  assert_eq(compare_serial(123U, 123U), SerialOrder::Same)
  assert_eq(compare_serial(4294967295U, 4294967295U), SerialOrder::Same)
}

///|
test "serial forward and backward ordering" {
  assert_eq(compare_serial(1U, 2U), SerialOrder::Forward)
  assert_eq(compare_serial(2U, 1U), SerialOrder::Backward)
  assert_eq(compare_serial(1000U, 1001U), SerialOrder::Forward)
}

///|
test "serial wraps from uint32 maximum to zero" {
  assert_eq(compare_serial(4294967295U, 0U), SerialOrder::Forward)
  assert_eq(compare_serial(0U, 4294967295U), SerialOrder::Backward)
}

///|
test "serial half-space is undefined both directions" {
  assert_eq(compare_serial(0U, 2147483648U), SerialOrder::Undefined)
  assert_eq(compare_serial(2147483648U, 0U), SerialOrder::Undefined)
  assert_eq(compare_serial(5U, 2147483653U), SerialOrder::Undefined)
}

///|
test "serial boundary immediately before half-space is forward" {
  assert_eq(compare_serial(0U, 2147483647U), SerialOrder::Forward)
  assert_eq(compare_serial(2147483647U, 0U), SerialOrder::Backward)
}

///|
test "serial boundary immediately after half-space is backward" {
  assert_eq(compare_serial(0U, 2147483649U), SerialOrder::Backward)
  assert_eq(compare_serial(2147483649U, 0U), SerialOrder::Forward)
}

///|
test "changed content with same serial is an error" {
  let before = serial_zone("1", "www IN A 192.0.2.1\n")
  let after = serial_zone("1", "www IN A 192.0.2.2\n")
  let result = compare_zones(before, after)
  assert_eq(result.serial_order, Some(SerialOrder::Same))
  assert_eq(contains_code(result.diagnostics, "D300"), true)
}

///|
test "unchanged content with same serial is allowed" {
  let before = serial_zone("1", "www IN A 192.0.2.1\n")
  let after = serial_zone("1", "www IN A 192.0.2.1\n")
  let result = compare_zones(before, after)
  assert_eq(result.changes.length(), 0)
  assert_eq(contains_code(result.diagnostics, "D300"), false)
}

///|
test "backward serial is an error" {
  let before = serial_zone("2", "")
  let after = serial_zone("1", "")
  let result = compare_zones(before, after)
  assert_eq(result.serial_order, Some(SerialOrder::Backward))
  assert_eq(contains_code(result.diagnostics, "D301"), true)
}

///|
test "half-space serial difference is an error" {
  let before = serial_zone("0", "")
  let after = serial_zone("2147483648", "")
  let result = compare_zones(before, after)
  assert_eq(result.serial_order, Some(SerialOrder::Undefined))
  assert_eq(contains_code(result.diagnostics, "D302"), true)
}

///|
test "missing soa serial cannot be compared" {
  let before = parse_zone("@ IN NS ns.example.org.\n", "example.org.")
  let after = serial_zone("1", "")
  let result = compare_zones(before, after)
  assert_eq(result.serial_order, None)
  assert_eq(contains_code(result.diagnostics, "D303"), true)
}
