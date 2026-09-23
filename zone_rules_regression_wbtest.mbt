///|
fn rule_fixture(extra : String) -> Array[Diagnostic] {
  inspect_zone(
    "@ IN SOA ns.example.org. host.example.org. 1 1h 1h 1w 1h\n@ IN NS ns.example.org.\nns IN A 192.0.2.1\n" +
    extra,
    "example.org.",
  )
}

///|
test "baseline zone has no findings" {
  let findings = rule_fixture("")
  assert_eq(error_count(findings), 0)
  assert_eq(warning_count(findings), 0)
}

///|
test "soa outside apex is rejected" {
  let findings = rule_fixture(
    "sub IN SOA ns.example.org. host.example.org. 2 1h 1h 1w 1h\n",
  )
  assert_eq(contains_code(findings, "Z203"), true)
}

///|
test "second apex soa is rejected" {
  let findings = rule_fixture(
    "@ IN SOA ns.example.org. host.example.org. 2 1h 1h 1w 1h\n",
  )
  assert_eq(contains_code(findings, "Z205"), true)
}

///|
test "out-of-zone owner is rejected" {
  let findings = rule_fixture("www.other.example. IN A 192.0.2.2\n")
  assert_eq(contains_code(findings, "Z201"), true)
}

///|
test "unsupported class is a warning" {
  let findings = rule_fixture("www CH A 192.0.2.2\n")
  assert_eq(contains_code(findings, "Z202"), true)
}

///|
test "duplicate address record is a warning" {
  let findings = rule_fixture("www IN A 192.0.2.2\nwww IN A 192.0.2.2\n")
  assert_eq(contains_code(findings, "Z210"), true)
}

///|
test "different addresses are not duplicates" {
  let findings = rule_fixture("www IN A 192.0.2.2\nwww IN A 192.0.2.3\n")
  assert_eq(contains_code(findings, "Z210"), false)
}

///|
test "cname cannot coexist with address" {
  let findings = rule_fixture(
    "www IN A 192.0.2.2\nwww IN CNAME ns.example.org.\n",
  )
  assert_eq(contains_code(findings, "Z220"), true)
}

///|
test "apex cname is rejected" {
  let findings = rule_fixture("@ IN CNAME www.example.org.\n")
  assert_eq(contains_code(findings, "Z233"), true)
}

///|
test "multiple cnames at one owner are rejected" {
  let findings = rule_fixture(
    "www IN CNAME a.example.org.\nwww IN CNAME b.example.org.\n",
  )
  assert_eq(contains_code(findings, "Z234"), true)
}
