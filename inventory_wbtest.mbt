///|
fn inventory_fixture() -> Zone {
  parse_zone(
    "$TTL 1h\n@ IN SOA ns.example.org. host.example.org. 1 1h 1h 1w 1h\n@ IN NS ns.example.org.\nns IN A 192.0.2.1\na IN CNAME b.example.org.\nb IN CNAME c.example.org.\nc 2h IN A 192.0.2.2\n",
    "example.org.",
  )
}

///|
test "inventory groups records and owners" {
  let summary = inventory_zone(inventory_fixture())
  assert_eq(summary.origin, "example.org.")
  assert_eq(summary.record_count, 6)
  assert_eq(summary.owner_count, 5)
  assert_eq(summary.address_count, 2)
  assert_eq(summary.alias_count, 2)
  assert_eq(summary.min_ttl, Some(3600))
  assert_eq(summary.max_ttl, Some(7200))
  assert_eq(summary.type_counts.length(), 4)
  assert_eq(summary.type_counts[1].record_type, "NS")
}

///|
test "inventory handles an empty zone" {
  let summary = inventory_zone(parse_zone("", "example.org."))
  assert_eq(summary.record_count, 0)
  assert_eq(summary.owner_count, 0)
  assert_eq(summary.min_ttl, None)
  assert_eq(summary.max_ttl, None)
  assert_eq(summary.type_counts.length(), 0)
}

///|
test "inventory text names all types" {
  let rendered = render_inventory_text(inventory_zone(inventory_fixture()))
  assert_eq(rendered.contains("records: 6"), true)
  assert_eq(rendered.contains("CNAME: 2"), true)
  assert_eq(rendered.contains("ttl range: 3600..7200"), true)
}

///|
test "inventory json is shaped for dashboards" {
  let rendered = render_inventory_json(inventory_zone(inventory_fixture()))
  assert_eq(rendered.contains("\"origin\":\"example.org.\""), true)
  assert_eq(rendered.contains("\"owners\":5"), true)
  assert_eq(rendered.contains("\"type\":\"CNAME\",\"count\":2"), true)
}

///|
test "find exact owner records" {
  let zone = inventory_fixture()
  let records = find_records(zone, "@", "ns")
  assert_eq(records.length(), 1)
  assert_eq(records[0].record_type, "NS")
  assert_eq(find_records(zone, "ns", "*").length(), 1)
  assert_eq(find_records(zone, "missing", "*").length(), 0)
}

///|
test "alias trace reaches address owner" {
  let trace = trace_alias(inventory_fixture(), "a")
  assert_eq(trace.cycle, false)
  assert_eq(trace.path.length(), 3)
  assert_eq(trace.path[0], "a.example.org.")
  assert_eq(trace.terminal, "c.example.org.")
}

///|
test "alias trace reports cycle" {
  let zone = parse_zone(
    "a IN CNAME b.example.org.\nb IN CNAME a.example.org.\n", "example.org.",
  )
  let trace = trace_alias(zone, "a")
  assert_eq(trace.cycle, true)
  assert_eq(trace.path.length(), 2)
  assert_eq(trace.terminal, "a.example.org.")
}
