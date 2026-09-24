///|
fn three_zone_revisions(retain_old_grandchild : Bool) -> Array[ZoneRevision] {
  let parent_before = parse_zone(
    "$ORIGIN example.org.\n$TTL 1h\n@ SOA ns.example.org. host.example.org. 1 1h 1h 1w 1h\n@ NS ns.example.org.\nns A 192.0.2.1\napp NS ns1.app.example.org.\nns1.app A 192.0.2.11\n",
    "example.org.",
  )
  let parent_after = parse_zone(
    "$ORIGIN example.org.\n$TTL 1h\n@ SOA ns.example.org. host.example.org. 2 1h 1h 1w 1h\n@ NS ns.example.org.\nns A 192.0.2.1\napp NS ns2.app.example.org.\nns2.app A 192.0.2.12\n",
    "example.org.",
  )
  let child_before = parse_zone(
    "$ORIGIN app.example.org.\n$TTL 1h\n@ SOA ns1.app.example.org. host.app.example.org. 1 1h 1h 1w 1h\n@ NS ns1.app.example.org.\nns1 A 192.0.2.11\ndev NS ns1.dev.app.example.org.\nns1.dev A 192.0.2.21\n",
    "app.example.org.",
  )
  let child_after = parse_zone(
    "$ORIGIN app.example.org.\n$TTL 1h\n@ SOA ns2.app.example.org. host.app.example.org. 2 1h 1h 1w 1h\n@ NS ns2.app.example.org.\nns1 A 192.0.2.11\nns2 A 192.0.2.12\ndev NS ns2.dev.app.example.org.\nns2.dev A 192.0.2.22\n",
    "app.example.org.",
  )
  let grandchild_before = parse_zone(
    "$ORIGIN dev.app.example.org.\n$TTL 1h\n@ SOA ns1.dev.app.example.org. host.dev.app.example.org. 1 1h 1h 1w 1h\n@ NS ns1.dev.app.example.org.\nns1 A 192.0.2.21\n",
    "dev.app.example.org.",
  )
  let retained = if retain_old_grandchild { "ns1 A 192.0.2.21\n" } else { "" }
  let grandchild_after = parse_zone(
    "$ORIGIN dev.app.example.org.\n$TTL 1h\n@ SOA ns2.dev.app.example.org. host.dev.app.example.org. 2 1h 1h 1w 1h\n@ NS ns2.dev.app.example.org.\n" +
    retained +
    "ns2 A 192.0.2.22\n",
    "dev.app.example.org.",
  )
  [
    { origin: "example.org.", before: parent_before, after: parent_after, },
    { origin: "app.example.org.", before: child_before, after: child_after, },
    {
      origin: "dev.app.example.org.",
      before: grandchild_before,
      after: grandchild_after,
    },
  ]
}

///|
test "planner finds only safe three-zone publication order" {
  let plan = plan_delegation_rollout(three_zone_revisions(true))
  assert_eq(plan.status, "safe-order")
  assert_eq(plan.snapshots.length(), 8)
  assert_eq(plan.order.length(), 3)
  assert_eq(plan.order[0], "dev.app.example.org.")
  assert_eq(plan.order[1], "app.example.org.")
  assert_eq(plan.order[2], "example.org.")
  assert_eq(plan.safe_order_count, 1)
  assert_eq(plan.required_precedence.length(), 3)
  assert_true(
    render_deployment_plan_json(plan).contains("\"status\":\"safe-order\""),
  )
}

///|
test "planner finds no safe order when intermediate child address is removed" {
  let plan = plan_delegation_rollout(three_zone_revisions(false))
  assert_eq(plan.status, "no-safe-order")
  assert_eq(plan.order.length(), 0)
  assert_eq(plan.safe_order_count, 0)
  assert_true(plan.snapshots[4].blocked)
  assert_true(render_deployment_plan_text(plan).contains("G006"))
  assert_true(plan.counterexample is Some(_))
  assert_true(
    render_deployment_plan_json(plan).contains("\"counterexample\":{"),
  )
}

///|
test "planner rejects unrelated or duplicate zones" {
  let revisions = three_zone_revisions(true)
  let duplicate = [revisions[0], revisions[0]]
  let result = plan_delegation_rollout(duplicate)
  assert_eq(result.status, "invalid-input")
  assert_eq(result.preflight[0].code, "M002")
  assert_eq(plan_delegation_rollout([]).status, "invalid-input")
}

///|
test "planner counts two equivalent safe orders" {
  let parent = rollout_parent("ns1", "ns1.app A 192.0.2.11\n")
  let child = rollout_child("ns1", "ns1 A 192.0.2.11\n")
  let revisions = [
    { origin: "example.org.", before: parent, after: parent, },
    { origin: "app.example.org.", before: child, after: child, },
  ]
  let plan = plan_delegation_rollout(revisions)
  assert_eq(plan.status, "safe-order")
  assert_eq(plan.safe_order_count, 2)
  assert_eq(plan.required_precedence.length(), 0)
}
