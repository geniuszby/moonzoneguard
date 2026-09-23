///|
fn mail_fixture(extra : String) -> Array[Diagnostic] {
  inspect_zone(
    "@ IN SOA ns.example.org. host.example.org. 1 1h 1h 1w 1h\n@ IN NS ns.example.org.\nns IN A 192.0.2.1\n" +
    extra,
    "example.org.",
  )
}

///|
test "valid null mx marks a no-mail domain" {
  let findings = mail_fixture("@ IN MX 0 .\n")
  assert_eq(contains_code(findings, "Z240"), false)
  assert_eq(contains_code(findings, "Z241"), false)
  assert_eq(contains_code(findings, "Z231"), false)
}

///|
test "null mx requires zero preference" {
  let findings = mail_fixture("@ IN MX 10 .\n")
  assert_eq(contains_code(findings, "Z240"), true)
}

///|
test "null mx cannot coexist with a normal exchanger" {
  let findings = mail_fixture(
    "@ IN MX 0 .\n@ IN MX 10 mail.example.org.\nmail IN A 192.0.2.2\n",
  )
  assert_eq(contains_code(findings, "Z241"), true)
}

///|
test "caa reserved flag bits produce a warning" {
  let findings = mail_fixture("@ IN CAA 1 issue \"ca.example\"\n")
  assert_eq(contains_code(findings, "Z242"), true)
}

///|
test "unknown critical caa property is highlighted" {
  let findings = mail_fixture("@ IN CAA 128 experimental \"value\"\n")
  assert_eq(contains_code(findings, "Z243"), true)
  assert_eq(contains_code(findings, "Z242"), false)
}

///|
test "caa property tags reject punctuation" {
  let findings = mail_fixture("@ IN CAA 0 issue! \"ca.example\"\n")
  assert_eq(contains_code(findings, "Z244"), true)
}

///|
test "unquoted caa values get portability warning" {
  let findings = mail_fixture("@ IN CAA 0 issue ca.example\n")
  assert_eq(contains_code(findings, "Z245"), true)
}

///|
test "spf rr type is deprecated" {
  let findings = mail_fixture("@ IN SPF \"v=spf1 -all\"\n")
  assert_eq(contains_code(findings, "Z246"), true)
}

///|
test "multiple spf txt policies conflict" {
  let findings = mail_fixture(
    "@ IN TXT \"v=spf1 a -all\"\n@ IN TXT \"v=spf1 mx -all\"\n",
  )
  assert_eq(contains_code(findings, "Z247"), true)
}

///|
test "unrelated txt strings do not count as spf" {
  let findings = mail_fixture("@ IN TXT \"hello\"\n@ IN TXT \"v=spf1 -all\"\n")
  assert_eq(contains_code(findings, "Z247"), false)
}

///|
test "srv target alias is a warning" {
  let findings = mail_fixture(
    "service IN CNAME endpoint.example.org.\nendpoint IN A 192.0.2.2\n_sip._tcp IN SRV 0 0 5060 service.example.org.\n",
  )
  assert_eq(contains_code(findings, "Z248"), true)
}
