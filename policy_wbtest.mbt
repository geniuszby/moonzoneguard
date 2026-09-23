///|
fn policy_fixture() -> Zone {
  parse_zone(
    "$ORIGIN example.org.\n$TTL 1h\n@ IN SOA ns.example.org. host.example.org. 1 1h 1h 1w 1h\n@ IN NS ns.example.org.\nns IN A 192.0.2.1\nmail IN A 192.0.2.2\n@ IN MX 10 mail.example.org.\nlegacy IN SPF \"v=spf1 -all\"\n",
    "example.org.",
  )
}

///|
test "empty policy has permissive defaults" {
  let result = parse_policy("")
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.policy.min_ttl, None)
  assert_eq(result.policy.max_ttl, None)
  assert_eq(result.policy.min_apex_ns, 1)
  assert_eq(result.policy.require_ipv6_for_mail, false)
  assert_eq(result.policy.forbid_types.length(), 0)
}

///|
test "policy parser reads keys and comments" {
  let result = parse_policy(
    "# Review profile\nmin-ttl 300\nmax-ttl 86400\nmin-apex-ns 2\nrequire-ipv6-for-mail yes\nforbid-type spf\n",
  )
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.policy.min_ttl, Some(300))
  assert_eq(result.policy.max_ttl, Some(86400))
  assert_eq(result.policy.min_apex_ns, 2)
  assert_eq(result.policy.require_ipv6_for_mail, true)
  assert_eq(result.policy.forbid_types[0], "SPF")
}

///|
test "policy parser rejects malformed values" {
  let result = parse_policy(
    "min-ttl nope\nrequire-ipv6-for-mail maybe\nunknown 2\nmax-ttl 100 extra\n",
  )
  assert_eq(result.diagnostics.length(), 4)
  assert_eq(result.diagnostics[0].code, "P001")
  assert_eq(result.diagnostics[1].code, "P002")
  assert_eq(result.diagnostics[2].code, "P004")
  assert_eq(result.diagnostics[3].code, "P003")
}

///|
test "policy parser detects contradictory ttl limits" {
  let result = parse_policy("min-ttl 200\nmax-ttl 100\n")
  assert_eq(result.diagnostics.length(), 1)
  assert_eq(result.diagnostics[0].code, "P005")
}

///|
test "policy checks apex nameservers and ipv6 mail" {
  let config = parse_policy("min-apex-ns 2\nrequire-ipv6-for-mail true\n")
  let findings = validate_with_policy(policy_fixture(), config.policy)
  assert_eq(contains_code(findings, "P102"), true)
  assert_eq(contains_code(findings, "P103"), true)
}

///|
test "policy checks forbidden record type" {
  let config = parse_policy("forbid-type SPF\n")
  let findings = validate_with_policy(policy_fixture(), config.policy)
  assert_eq(contains_code(findings, "P104"), true)
  assert_eq(error_count(findings), 1)
}

///|
test "policy ttl bounds are applied to each record" {
  let config = parse_policy("min-ttl 4000\nmax-ttl 5000\n")
  let findings = validate_with_policy(policy_fixture(), config.policy)
  assert_eq(contains_code(findings, "P100"), true)
  assert_eq(contains_code(findings, "P101"), false)
}
