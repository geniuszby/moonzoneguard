///|
pub(all) struct LookupResult {
  status : String
  queried_name : String
  queried_type : String
  canonical_name : String
  alias_path : Array[String]
  answers : Array[ResourceRecord]
} derive(Debug)

///|
fn lookup_result(
  status : String,
  name : String,
  kind : String,
  canonical : String,
  path : Array[String],
  answers : Array[ResourceRecord],
) -> LookupResult {
  {
    status,
    queried_name: name,
    queried_type: kind,
    canonical_name: canonical,
    alias_path: path,
    answers,
  }
}

///|
/// Simulate an exact, local lookup with CNAME following. This is not a DNS
/// resolver: it performs no wildcard synthesis, delegation, or network I/O.
pub fn lookup_zone(
  zone : Zone,
  name : String,
  record_type : String,
) -> LookupResult {
  let owner = absolute_name(name, zone.origin)
  let kind = upper(record_type)
  let empty : Array[ResourceRecord] = []
  let empty_path : Array[String] = []
  if !valid_domain_name(owner) {
    return lookup_result("invalid-name", owner, kind, owner, empty_path, empty)
  }
  if !is_within_zone(owner, zone.origin) {
    return lookup_result("outside-zone", owner, kind, owner, empty_path, empty)
  }
  let direct = find_records(zone, owner, kind)
  if direct.length() > 0 {
    return lookup_result("answer", owner, kind, owner, empty_path, direct)
  }
  let all = find_records(zone, owner, "*")
  if all.length() == 0 {
    return lookup_result(
      "name-not-found", owner, kind, owner, empty_path, empty,
    )
  }
  if kind == "CNAME" {
    return lookup_result("no-data", owner, kind, owner, empty_path, empty)
  }
  let trace = trace_alias(zone, owner)
  if trace.cycle {
    return lookup_result(
      "alias-cycle",
      owner,
      kind,
      trace.terminal,
      trace.path,
      empty,
    )
  }
  if trace.path.length() == 1 {
    return lookup_result("no-data", owner, kind, owner, trace.path, empty)
  }
  if !is_within_zone(trace.terminal, zone.origin) {
    return lookup_result(
      "external-target",
      owner,
      kind,
      trace.terminal,
      trace.path,
      empty,
    )
  }
  let answers = find_records(zone, trace.terminal, kind)
  if answers.length() > 0 {
    lookup_result("answer", owner, kind, trace.terminal, trace.path, answers)
  } else {
    lookup_result("no-data", owner, kind, trace.terminal, trace.path, empty)
  }
}

///|
pub fn render_lookup_text(result : LookupResult) -> String {
  let out = StringBuilder()
  out.write_string("status: \{result.status}\n")
  out.write_string("query: \{result.queried_name} \{result.queried_type}\n")
  out.write_string("canonical name: \{result.canonical_name}\n")
  for name in result.alias_path {
    out.write_string("alias path: \{name}\n")
  }
  for record in result.answers {
    out.write_string(canonical_record_line(record))
    out.write_char('\n')
  }
  out.to_string()
}

///|
pub fn render_lookup_json(result : LookupResult) -> String {
  let out = StringBuilder()
  out.write_char('{')
  write_json_field(out, "status", result.status, false)
  write_json_field(out, "name", result.queried_name, true)
  write_json_field(out, "type", result.queried_type, true)
  write_json_field(out, "canonical_name", result.canonical_name, true)
  out.write_string(",\"alias_path\":[")
  for i in 0..<result.alias_path.length() {
    if i > 0 {
      out.write_char(',')
    }
    out.write_string(json_escaped(result.alias_path[i]))
  }
  out.write_string("],\"answers\":[")
  for i in 0..<result.answers.length() {
    if i > 0 {
      out.write_char(',')
    }
    out.write_string(json_escaped(canonical_record_line(result.answers[i])))
  }
  out.write_string("]}")
  out.to_string()
}
