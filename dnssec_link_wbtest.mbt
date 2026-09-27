///|
fn rfc4509_key() -> ResourceRecord {
  parse_zone(
    "dskey.example.com. DNSKEY 256 3 5 ( AQOeiiR0GOMYkDshWoSKz9Xz fwJr1AYtsmx3TGkJaNXVbfi/ 2pHm822aJ5iI9BMzNXxeYCmZ DRD99WYwYqUSdjMmmAphXdvx egXd/M5+X7OrzKBaMbCVdFLU Uh6DhweJBjEVv5f2wwjM9Xzc nOf+EPbtG9DMBmADjFDc2w/r ljwvFw== )",
    "example.com.",
  ).records[0]
}

///|
test "RFC 4509 DNSKEY key tag and SHA256 DS conformance vector" {
  let result = dnskey_ds_sha256(rfc4509_key()).unwrap()
  assert_eq(result.key_tag, 60485)
  assert_eq(
    result.sha256_digest,
    "d4b7d520e7bb5f0f67674a0cceb1e3e0614b93c4f9e99b8383f6a1e4469da50a",
  )
}

///|
let rollover_old_key = "257 3 15 11qYAYKxCrfVS/7TyWQHOg7hcvPapiMlrwIaaPcHURo="

///|
let rollover_new_key = "257 3 15 PUAXw+hDiVqStwqnTRt+vJyYLM8uxJaMwM1V8Sr0Zgw="

///|
let rollover_old_ds = "14017 15 2 5322afb01115be1b5812b75130f3054ba57dee7e88f5f6e825fe81d11728df6a"

///|
let rollover_new_ds = "27232 15 2 e14f13f02452a2b340ce80c59f065a3dbd10de6dfef7e8bc93bea0ff02638d81"

///|
fn dnssec_parent(serial : String, ds : String) -> Zone {
  parse_zone(
    "$ORIGIN example.org.\n@ SOA ns host \{serial} 1h 1h 1w 1h\n@ NS ns\nns A 192.0.2.1\napp NS ns.app.example.org.\nns.app A 192.0.2.53\napp DS \{ds}\n",
    "example.org.",
  )
}

///|
fn dnssec_child(serial : String, keys : String) -> Zone {
  parse_zone(
    "$ORIGIN app.example.org.\n@ SOA ns host \{serial} 1h 1h 1w 1h\n@ NS ns\nns A 192.0.2.53\n" +
    keys,
    "app.example.org.",
  )
}

///|
test "DNSKEY Ed25519 vector matches independently computed dotnet digest" {
  let key = dnssec_child("1", "@ DNSKEY " + rollover_old_key).records[3]
  let fingerprint = dnskey_ds_sha256(key).unwrap()
  assert_eq(fingerprint.key_tag, 14017)
  assert_eq(
    fingerprint.sha256_digest,
    "5322afb01115be1b5812b75130f3054ba57dee7e88f5f6e825fe81d11728df6a",
  )
}

///|
test "DS rollover requires child key prepublication before parent DS switch" {
  let parent_before = dnssec_parent("1", rollover_old_ds)
  let parent_after = dnssec_parent("2", rollover_new_ds)
  let child_before = dnssec_child("1", "@ DNSKEY " + rollover_old_key)
  let child_after = dnssec_child(
    "2",
    "@ DNSKEY " + rollover_old_key + "\n@ DNSKEY " + rollover_new_key,
  )
  let result = analyze_delegation_rollout(
    parent_before, parent_after, child_before, child_after,
  )
  assert_eq(result.recommendation, "child-first")
  assert_true(rollout_has_code(result.states[1], "S105"))
  assert_true(rollout_has_code(result.states[2], "S100"))
  let plan = plan_delegation_rollout([
    {
      origin: parent_before.origin,
      before: parent_before,
      after: parent_after,
    },
    { origin: child_before.origin, before: child_before, after: child_after, },
  ])
  assert_eq(plan.safe_order_count, 1)
  assert_eq(plan.order[0], child_before.origin)
}

///|
test "removing old key while switching DS has no safe atomic order" {
  let result = analyze_delegation_rollout(
    dnssec_parent("1", rollover_old_ds),
    dnssec_parent("2", rollover_new_ds),
    dnssec_child("1", "@ DNSKEY " + rollover_old_key),
    dnssec_child("2", "@ DNSKEY " + rollover_new_key),
  )
  assert_eq(result.recommendation, "no-safe-order")
  assert_true(rollout_has_code(result.states[1], "S105"))
  assert_true(rollout_has_code(result.states[2], "S105"))
  assert_eq(result.states[3].blocked, false)
}

///|
test "same key tag cannot mask tampered DS digest" {
  let parent = dnssec_parent("1", "14017 15 2 " + "0".repeat(64))
  let child = dnssec_child("1", "@ DNSKEY " + rollover_old_key)
  let result = analyze_delegation_rollout(parent, parent, child, child)
  assert_true(rollout_has_code(result.states[0], "S105"))
}

///|
test "unsupported DS digest blocks unverified association" {
  let parent = dnssec_parent("1", "14017 15 4 deadbeef")
  let child = dnssec_child("1", "@ DNSKEY " + rollover_old_key)
  let result = analyze_delegation_rollout(parent, parent, child, child)
  assert_true(rollout_has_code(result.states[0], "S103"))
  assert_true(rollout_has_code(result.states[0], "S105"))
}

///|
test "DNSKEY rejects malformed base64 and invalid protocol" {
  let bad = parse_zone("@ DNSKEY 257 3 15 %%%%", "app.example.org.").records[0]
  assert_true(dnskey_ds_sha256(bad) is Err(_))
  let protocol = parse_zone("@ DNSKEY 257 2 15 AQID", "app.example.org.").records[0]
  assert_true(dnskey_ds_sha256(protocol) is Err(_))
}

///|
test "DNSKEY without zone flag cannot satisfy parent DS" {
  let child = dnssec_child(
    "1", "@ DNSKEY 1 3 15 11qYAYKxCrfVS/7TyWQHOg7hcvPapiMlrwIaaPcHURo=",
  )
  let key = dnskey_ds_sha256(child.records[3]).unwrap()
  let parent = dnssec_parent("1", "\{key.key_tag} 15 2 \{key.sha256_digest}")
  let result = analyze_delegation_rollout(parent, parent, child, child)
  assert_true(rollout_has_code(result.states[0], "S105"))
}

///|
test "one matching DS is sufficient despite a stale additional DS" {
  let parent = dnssec_parent(
    "1",
    rollover_old_ds + "\napp DS " + rollover_new_ds,
  )
  let child = dnssec_child("1", "@ DNSKEY " + rollover_old_key)
  let result = analyze_delegation_rollout(parent, parent, child, child)
  assert_eq(result.recommendation, "either-order")
  assert_true(rollout_has_code(result.states[0], "S104"))
}

///|
test "DS removal is a conservative trust downgrade preflight error" {
  let before = dnssec_parent("1", rollover_old_ds)
  let after = parse_zone(
    "$ORIGIN example.org.\n@ SOA ns host 2 1h 1h 1w 1h\n@ NS ns\nns A 192.0.2.1\napp NS ns.app.example.org.\nns.app A 192.0.2.53\n",
    "example.org.",
  )
  let child = dnssec_child("1", "@ DNSKEY " + rollover_old_key)
  let result = analyze_delegation_rollout(before, after, child, child)
  assert_eq(result.recommendation, "no-safe-order")
  assert_true(result.preflight[0].code == "S107")
  let plan = plan_delegation_rollout([
    { origin: before.origin, before, after, },
    { origin: child.origin, before: child, after: child, },
  ])
  assert_eq(plan.status, "invalid-input")
}
