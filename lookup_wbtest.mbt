///|
fn lookup_fixture() -> Zone {
  parse_zone(
    "@ IN SOA ns.example.org. host.example.org. 1 1h 1h 1w 1h\n@ IN NS ns.example.org.\nns IN A 192.0.2.1\nwww IN A 192.0.2.2\nwww IN AAAA 2001:db8::2\napp IN CNAME www.example.org.\nportal IN CNAME app.example.org.\nexternal IN CNAME remote.other.example.\n",
    "example.org.",
  )
}

///|
test "lookup direct exact answer" {
  let result = lookup_zone(lookup_fixture(), "www", "a")
  assert_eq(result.status, "answer")
  assert_eq(result.answers.length(), 1)
  assert_eq(result.answers[0].rdata[0], "192.0.2.2")
  assert_eq(result.alias_path.length(), 0)
}

///|
test "lookup follows two aliases" {
  let result = lookup_zone(lookup_fixture(), "portal", "AAAA")
  assert_eq(result.status, "answer")
  assert_eq(result.canonical_name, "www.example.org.")
  assert_eq(result.alias_path.length(), 3)
  assert_eq(result.answers[0].record_type, "AAAA")
}

///|
test "lookup returns cname for a cname query" {
  let result = lookup_zone(lookup_fixture(), "app", "CNAME")
  assert_eq(result.status, "answer")
  assert_eq(result.answers.length(), 1)
  assert_eq(result.canonical_name, "app.example.org.")
}

///|
test "lookup sees existing name without requested type" {
  let result = lookup_zone(lookup_fixture(), "www", "MX")
  assert_eq(result.status, "no-data")
  assert_eq(result.answers.length(), 0)
}

///|
test "lookup sees nonexistent in-zone name" {
  let result = lookup_zone(lookup_fixture(), "missing", "A")
  assert_eq(result.status, "name-not-found")
}

///|
test "lookup does not query external names" {
  let result = lookup_zone(lookup_fixture(), "remote.other.example.", "A")
  assert_eq(result.status, "outside-zone")
}

///|
test "lookup returns external alias target without network" {
  let result = lookup_zone(lookup_fixture(), "external", "A")
  assert_eq(result.status, "external-target")
  assert_eq(result.canonical_name, "remote.other.example.")
}

///|
test "lookup detects alias cycle" {
  let zone = parse_zone(
    "a IN CNAME b.example.org.\nb IN CNAME a.example.org.\n", "example.org.",
  )
  let result = lookup_zone(zone, "a", "A")
  assert_eq(result.status, "alias-cycle")
  assert_eq(result.alias_path.length(), 2)
}

///|
test "lookup rejects malformed query name" {
  let result = lookup_zone(lookup_fixture(), "bad..example.org.", "A")
  assert_eq(result.status, "invalid-name")
}

///|
test "lookup text and json expose trace and answer" {
  let result = lookup_zone(lookup_fixture(), "app", "A")
  let text = render_lookup_text(result)
  let json = render_lookup_json(result)
  assert_eq(text.contains("status: answer"), true)
  assert_eq(text.contains("alias path: app.example.org."), true)
  assert_eq(json.contains("\"status\":\"answer\""), true)
  assert_eq(json.contains("www.example.org. 3600 IN A 192.0.2.2"), true)
}
