///|
/// A finding in one parent/child deployment snapshot. `source` identifies
/// the input file, and `line` is the original zone-file line.
pub(all) struct DelegationFinding {
  code : String
  severity : String
  source : String
  owner : String
  line : Int
  message : String
} derive(Debug)

///|
pub(all) struct DelegationState {
  name : String
  parent_version : String
  child_version : String
  blocked : Bool
  findings : Array[DelegationFinding]
} derive(Debug)

///|
/// The four snapshots assume that each zone file is published atomically.
/// A safe order means no local error was found in its three snapshots.
pub(all) struct DelegationRollout {
  states : Array[DelegationState]
  preflight : Array[DelegationFinding]
  parent_first : Bool
  child_first : Bool
  recommendation : String
} derive(Debug)

///|
fn delegation_finding(
  findings : Array[DelegationFinding],
  code : String,
  severity : String,
  source : String,
  owner : String,
  line : Int,
  message : String,
) -> Unit {
  findings.push({ code, severity, source, owner, line, message, })
}

///|
fn append_zone_findings(
  findings : Array[DelegationFinding],
  zone : Zone,
  source : String,
) -> Unit {
  for item in validate_zone(zone) {
    delegation_finding(
      findings,
      item.code,
      item.severity,
      source,
      item.owner,
      item.line,
      item.message,
    )
  }
}

///|
fn records_at(
  zone : Zone,
  owner : String,
  record_type : String,
) -> Array[ResourceRecord] {
  let result : Array[ResourceRecord] = []
  for record in zone.records {
    if record.owner == owner && record.record_type == record_type {
      result.push(record)
    }
  }
  result
}

///|
fn ns_targets(records : Array[ResourceRecord]) -> Map[String, Bool] {
  let result : Map[String, Bool] = Map([])
  for record in records {
    if record.rdata.length() > 0 {
      result.set(absolute_rdata_name(record, 0, record.origin), true)
    }
  }
  result
}

///|
fn same_ns_targets(
  parent_records : Array[ResourceRecord],
  child_records : Array[ResourceRecord],
) -> Bool {
  let parent_targets = ns_targets(parent_records)
  let child_targets = ns_targets(child_records)
  if parent_targets.length() != child_targets.length() {
    return false
  }
  for target in parent_targets.keys() {
    if child_targets.get(target) is None {
      return false
    }
  }
  true
}

///|
fn address_values(zone : Zone, owner : String) -> Map[String, Bool] {
  let values : Map[String, Bool] = Map([])
  for record in zone.records {
    if record.owner == owner &&
      (record.record_type == "A" || record.record_type == "AAAA") &&
      record.rdata.length() > 0 {
      values.set(record.record_type + ":" + lower(record.rdata[0]), true)
    }
  }
  values
}

///|
fn addresses_overlap(
  parent : Map[String, Bool],
  child : Map[String, Bool],
) -> Bool {
  for address in parent.keys() {
    if child.get(address) is Some(_) {
      return true
    }
  }
  false
}

///|
fn audit_delegation_pair(
  parent : Zone,
  child : Zone,
  parent_source : String,
  child_source : String,
  include_validation : Bool,
) -> Array[DelegationFinding] {
  let findings : Array[DelegationFinding] = []
  if include_validation {
    append_zone_findings(findings, parent, parent_source)
    append_zone_findings(findings, child, child_source)
  }
  if parent.origin == child.origin ||
    !is_within_zone(child.origin, parent.origin) {
    delegation_finding(
      findings,
      "G001",
      "error",
      child_source,
      child.origin,
      0,
      "child origin must be strictly below parent origin",
    )
    return findings
  }
  let parent_ns = records_at(parent, child.origin, "NS")
  let child_ns = records_at(child, child.origin, "NS")
  if parent_ns.length() == 0 {
    delegation_finding(
      findings,
      "G002",
      "error",
      parent_source,
      child.origin,
      0,
      "parent zone has no NS delegation for child origin",
    )
  }
  if child_ns.length() == 0 {
    delegation_finding(
      findings,
      "G003",
      "error",
      child_source,
      child.origin,
      0,
      "child zone has no apex NS record",
    )
  }
  if parent_ns.length() > 0 &&
    child_ns.length() > 0 &&
    !same_ns_targets(parent_ns, child_ns) {
    delegation_finding(
      findings,
      "G004",
      "warning",
      child_source,
      child.origin,
      child_ns[0].line,
      "parent delegation and child apex NS sets differ during this snapshot",
    )
  }
  let seen : Map[String, Bool] = Map([])
  for record in parent_ns {
    if record.rdata.length() == 0 {
      continue
    }
    let target = absolute_rdata_name(record, 0, record.origin)
    if !is_within_zone(target, child.origin) || seen.get(target) is Some(_) {
      continue
    }
    seen.set(target, true)
    let glue = address_values(parent, target)
    let authoritative = address_values(child, target)
    if glue.length() == 0 {
      delegation_finding(
        findings,
        "G005",
        "error",
        parent_source,
        target,
        record.line,
        "in-domain nameserver has no A/AAAA glue in parent zone",
      )
    }
    if authoritative.length() == 0 {
      delegation_finding(
        findings, "G006", "error", child_source, target, 0, "in-domain nameserver has no A/AAAA address in child snapshot",
      )
    } else if glue.length() > 0 && !addresses_overlap(glue, authoritative) {
      delegation_finding(
        findings,
        "G007",
        "error",
        parent_source,
        target,
        record.line,
        "parent glue and child authoritative addresses have no common value under conservative rollout policy",
      )
    }
  }
  findings
}

///|
fn delegation_state(
  name : String,
  parent_version : String,
  child_version : String,
  parent : Zone,
  child : Zone,
) -> DelegationState {
  let findings = audit_delegation_pair(
    parent,
    child,
    "parent-" + parent_version,
    "child-" + child_version,
    true,
  )
  let mut blocked = false
  for item in findings {
    if item.severity == "error" {
      blocked = true
    }
  }
  { name, parent_version, child_version, blocked, findings, }
}

///|
/// Check both publication orders of one parent and one child zone.
/// This is a bounded offline model: it does not simulate DNS caches,
/// live servers, DNSSEC validation, or non-atomic publication.
pub fn analyze_delegation_rollout(
  parent_before : Zone,
  parent_after : Zone,
  child_before : Zone,
  child_after : Zone,
) -> DelegationRollout {
  let preflight : Array[DelegationFinding] = []
  let parent_diff = compare_zones(parent_before, parent_after)
  let child_diff = compare_zones(child_before, child_after)
  for item in parent_diff.diagnostics {
    delegation_finding(
      preflight,
      item.code,
      item.severity,
      "parent-after",
      item.owner,
      item.line,
      item.message,
    )
  }
  for item in child_diff.diagnostics {
    delegation_finding(
      preflight,
      item.code,
      item.severity,
      "child-after",
      item.owner,
      item.line,
      item.message,
    )
  }
  let states = [
    delegation_state(
      "baseline", "before", "before", parent_before, child_before,
    ),
    delegation_state(
      "parent-updated", "after", "before", parent_after, child_before,
    ),
    delegation_state(
      "child-updated", "before", "after", parent_before, child_after,
    ),
    delegation_state("final", "after", "after", parent_after, child_after),
  ]
  let mut preflight_ok = true
  for item in preflight {
    if item.severity == "error" {
      preflight_ok = false
    }
  }
  let endpoints_ok = preflight_ok && !states[0].blocked && !states[3].blocked
  let parent_first = endpoints_ok && !states[1].blocked
  let child_first = endpoints_ok && !states[2].blocked
  let recommendation = if parent_first && child_first {
    "either-order"
  } else if parent_first {
    "parent-first"
  } else if child_first {
    "child-first"
  } else {
    "no-safe-order"
  }
  { states, preflight, parent_first, child_first, recommendation, }
}

///|
pub fn render_delegation_rollout_text(result : DelegationRollout) -> String {
  let out = StringBuilder()
  out.write_string("recommendation: ")
  out.write_string(result.recommendation)
  out.write_char('\n')
  for item in result.preflight {
    out.write_string("preflight: ")
    out.write_string(item.severity)
    out.write_char(' ')
    out.write_string(item.code)
    out.write_string(" [")
    out.write_string(item.source)
    out.write_string("] ")
    out.write_string(item.message)
    out.write_char('\n')
  }
  for state in result.states {
    out.write_string(state.name)
    out.write_string(" (parent=")
    out.write_string(state.parent_version)
    out.write_string(", child=")
    out.write_string(state.child_version)
    out.write_string("): ")
    out.write_string(if state.blocked { "blocked" } else { "pass" })
    out.write_char('\n')
    for item in state.findings {
      out.write_string("  ")
      out.write_string(item.severity)
      out.write_char(' ')
      out.write_string(item.code)
      out.write_string(" [")
      out.write_string(item.source)
      out.write_char(':')
      out.write_string(item.line.to_string())
      out.write_string("] ")
      out.write_string(item.owner)
      out.write_string(": ")
      out.write_string(item.message)
      out.write_char('\n')
    }
  }
  out.to_string()
}

///|
pub fn render_delegation_rollout_json(result : DelegationRollout) -> String {
  let out = StringBuilder()
  out.write_char('{')
  write_json_field(out, "recommendation", result.recommendation, false)
  out.write_string(",\"parent_first\":")
  out.write_string(if result.parent_first { "true" } else { "false" })
  out.write_string(",\"child_first\":")
  out.write_string(if result.child_first { "true" } else { "false" })
  out.write_string(",\"preflight\":[")
  for i in 0..<result.preflight.length() {
    if i > 0 {
      out.write_char(',')
    }
    let item = result.preflight[i]
    out.write_char('{')
    write_json_field(out, "code", item.code, false)
    write_json_field(out, "severity", item.severity, true)
    write_json_field(out, "source", item.source, true)
    write_json_field(out, "owner", item.owner, true)
    write_json_number(out, "line", item.line, true)
    write_json_field(out, "message", item.message, true)
    out.write_char('}')
  }
  out.write_char(']')
  out.write_string(",\"states\":[")
  for i in 0..<result.states.length() {
    if i > 0 {
      out.write_char(',')
    }
    let state = result.states[i]
    out.write_char('{')
    write_json_field(out, "name", state.name, false)
    write_json_field(out, "parent_version", state.parent_version, true)
    write_json_field(out, "child_version", state.child_version, true)
    out.write_string(",\"blocked\":")
    out.write_string(if state.blocked { "true" } else { "false" })
    out.write_string(",\"findings\":[")
    for j in 0..<state.findings.length() {
      if j > 0 {
        out.write_char(',')
      }
      let item = state.findings[j]
      out.write_char('{')
      write_json_field(out, "code", item.code, false)
      write_json_field(out, "severity", item.severity, true)
      write_json_field(out, "source", item.source, true)
      write_json_field(out, "owner", item.owner, true)
      write_json_number(out, "line", item.line, true)
      write_json_field(out, "message", item.message, true)
      out.write_char('}')
    }
    out.write_string("]}")
  }
  out.write_string("]}")
  out.to_string()
}
