///|
fn rollout_parent(ns : String, glue : String) -> Zone {
  parse_zone(
    "$ORIGIN example.org.\n$TTL 1h\n@ SOA ns.example.org. host.example.org. \{if ns == "ns1" { "1" } else { "2" }} 1h 1h 1w 1h\n@ NS ns.example.org.\nns A 192.0.2.1\napp NS \{ns}.app.example.org.\n" +
    glue,
    "example.org.",
  )
}

///|
fn rollout_child(ns : String, addresses : String) -> Zone {
  parse_zone(
    "$ORIGIN app.example.org.\n$TTL 1h\n@ SOA \{ns}.app.example.org. host.app.example.org. \{if ns == "ns1" { "1" } else { "2" }} 1h 1h 1w 1h\n@ NS \{ns}.app.example.org.\n" +
    addresses,
    "app.example.org.",
  )
}

///|
fn rollout_has_code(state : DelegationState, code : String) -> Bool {
  for item in state.findings {
    if item.code == code {
      return true
    }
  }
  false
}

///|
test "rollout recommends child-first when new NS needs child address" {
  let parent_before = rollout_parent("ns1", "ns1.app A 192.0.2.11\n")
  let parent_after = rollout_parent("ns2", "ns2.app A 192.0.2.12\n")
  let child_before = rollout_child("ns1", "ns1 A 192.0.2.11\n")
  let child_after = rollout_child("ns2", "ns1 A 192.0.2.11\nns2 A 192.0.2.12\n")
  let result = analyze_delegation_rollout(
    parent_before, parent_after, child_before, child_after,
  )
  assert_eq(result.recommendation, "child-first")
  assert_eq(result.states.length(), 4)
  assert_eq(result.states[0].blocked, false)
  assert_eq(result.states[1].blocked, true)
  assert_true(rollout_has_code(result.states[1], "G006"))
  assert_eq(result.states[2].blocked, false)
  assert_eq(result.states[3].blocked, false)
  assert_true(render_delegation_rollout_text(result).contains("child-first"))
  assert_true(
    render_delegation_rollout_json(result).contains(
      "\"name\":\"parent-updated\"",
    ),
  )
}

///|
test "rollout blocks missing in-domain glue in final snapshot" {
  let parent_before = rollout_parent("ns1", "ns1.app A 192.0.2.11\n")
  let parent_after = rollout_parent("ns2", "")
  let child_before = rollout_child("ns1", "ns1 A 192.0.2.11\n")
  let child_after = rollout_child("ns2", "ns1 A 192.0.2.11\nns2 A 192.0.2.12\n")
  let result = analyze_delegation_rollout(
    parent_before, parent_after, child_before, child_after,
  )
  assert_eq(result.recommendation, "no-safe-order")
  assert_true(rollout_has_code(result.states[3], "G005"))
}

///|
test "rollout blocks disjoint glue and child addresses" {
  let parent = rollout_parent("ns1", "ns1.app A 192.0.2.99\n")
  let child = rollout_child("ns2", "ns1 A 192.0.2.11\nns2 A 192.0.2.12\n")
  let result = analyze_delegation_rollout(parent, parent, child, child)
  assert_eq(result.recommendation, "no-safe-order")
  assert_true(rollout_has_code(result.states[0], "G004"))
  assert_true(rollout_has_code(result.states[0], "G007"))
}

///|
test "rollout rejects unrelated parent and child origins" {
  let parent = rollout_parent("ns1", "ns1.app A 192.0.2.11\n")
  let child = parse_zone(
    "$ORIGIN unrelated.test.\n@ NS ns.unrelated.test.\n", "unrelated.test.",
  )
  let result = analyze_delegation_rollout(parent, parent, child, child)
  assert_eq(result.recommendation, "no-safe-order")
  assert_true(rollout_has_code(result.states[0], "G001"))
}

///|
test "rollout can recommend parent-first" {
  let parent_before = rollout_parent("ns1", "ns1.app A 192.0.2.11\n")
  let parent_after = rollout_parent("ns2", "ns2.app A 192.0.2.12\n")
  let child_before = rollout_child(
    "ns1", "ns1 A 192.0.2.11\nns2 A 192.0.2.12\n",
  )
  let child_after = rollout_child("ns2", "ns2 A 192.0.2.12\n")
  let result = analyze_delegation_rollout(
    parent_before, parent_after, child_before, child_after,
  )
  assert_eq(result.recommendation, "parent-first")
  assert_eq(result.states[1].blocked, false)
  assert_true(rollout_has_code(result.states[2], "G006"))
}

///|
test "rollout preflight rejects a zone change without advancing serial" {
  let before = rollout_parent("ns1", "ns1.app A 192.0.2.11\n")
  let after = rollout_parent("ns1", "ns1.app A 192.0.2.99\n")
  let child = rollout_child("ns1", "ns1 A 192.0.2.11\n")
  let result = analyze_delegation_rollout(before, after, child, child)
  assert_eq(result.recommendation, "no-safe-order")
  assert_true(result.preflight.length() > 0)
  assert_eq(result.preflight[0].code, "D300")
}

///|
test "rollout detects a missing parent delegation" {
  let parent = parse_zone(
    "$ORIGIN example.org.\n@ SOA ns.example.org. host.example.org. 1 1h 1h 1w 1h\n@ NS ns.example.org.\n",
    "example.org.",
  )
  let child = rollout_child("ns1", "ns1 A 192.0.2.11\n")
  let result = analyze_delegation_rollout(parent, parent, child, child)
  assert_eq(result.recommendation, "no-safe-order")
  assert_true(rollout_has_code(result.states[0], "G002"))
}
