///|
/// Optional local review policy. Defaults are deliberately permissive.
pub(all) struct AuditPolicy {
  mut min_ttl : Int?
  mut max_ttl : Int?
  mut min_apex_ns : Int
  mut require_ipv6_for_mail : Bool
  forbid_types : Array[String]
} derive(Debug)

///|
pub(all) struct PolicyParse {
  policy : AuditPolicy
  diagnostics : Array[Diagnostic]
} derive(Debug)

///|
pub fn default_policy() -> AuditPolicy {
  {
    min_ttl: None,
    max_ttl: None,
    min_apex_ns: 1,
    require_ipv6_for_mail: false,
    forbid_types: [],
  }
}

///|
fn policy_error(
  findings : Array[Diagnostic],
  code : String,
  message : String,
  line : Int,
) -> Unit {
  findings.push(diagnostic(code, "error", message, line, 1))
}

///|
fn parse_policy_integer(
  text : String,
  line : Int,
  diagnostics : Array[Diagnostic],
) -> Int? {
  match decimal_number(text) {
    Some(value) => Some(value)
    None => {
      policy_error(diagnostics, "P001", "expected a nonnegative integer", line)
      None
    }
  }
}

///|
fn parse_policy_boolean(
  text : String,
  line : Int,
  diagnostics : Array[Diagnostic],
) -> Bool? {
  match lower(text) {
    "true" | "yes" => Some(true)
    "false" | "no" => Some(false)
    _ => {
      policy_error(diagnostics, "P002", "expected true/false or yes/no", line)
      None
    }
  }
}

///|
/// Parse a small, reviewable policy format: one `key value` pair per line.
/// Blank lines and lines beginning with `#` are ignored.
pub fn parse_policy(source : String) -> PolicyParse {
  let policy = default_policy()
  let diagnostics : Array[Diagnostic] = []
  let lines = source.split("\n").collect()
  for index in 0..<lines.length() {
    let line = lines[index].to_owned().trim().to_owned()
    if line == "" || line.has_prefix("#") {
      continue
    }
    let parts = line.split(" ").collect()
    let words : Array[String] = []
    for item in parts {
      let word = item.to_owned()
      if word != "" {
        words.push(word)
      }
    }
    if words.length() != 2 {
      policy_error(
        diagnostics,
        "P003",
        "expected exactly one key and one value",
        index + 1,
      )
      continue
    }
    match words[0] {
      "min-ttl" =>
        policy.min_ttl = parse_policy_integer(words[1], index + 1, diagnostics)
      "max-ttl" =>
        policy.max_ttl = parse_policy_integer(words[1], index + 1, diagnostics)
      "min-apex-ns" =>
        match parse_policy_integer(words[1], index + 1, diagnostics) {
          Some(value) => policy.min_apex_ns = value
          None => ()
        }
      "require-ipv6-for-mail" =>
        match parse_policy_boolean(words[1], index + 1, diagnostics) {
          Some(value) => policy.require_ipv6_for_mail = value
          None => ()
        }
      "forbid-type" => policy.forbid_types.push(upper(words[1]))
      _ =>
        policy_error(
          diagnostics,
          "P004",
          "unknown policy key: \{words[0]}",
          index + 1,
        )
    }
  }
  match (policy.min_ttl, policy.max_ttl) {
    (Some(minimum), Some(maximum)) =>
      if minimum > maximum {
        policy_error(diagnostics, "P005", "min-ttl exceeds max-ttl", 1)
      }
    _ => ()
  }
  { policy, diagnostics, }
}

///|
fn policy_ttl_checks(
  zone : Zone,
  policy : AuditPolicy,
  findings : Array[Diagnostic],
) -> Unit {
  for record in zone.records {
    match policy.min_ttl {
      Some(minimum) =>
        if record.ttl < minimum {
          add_record_note(
            findings,
            "P100",
            "warning",
            "TTL \{record.ttl} is below policy minimum \{minimum}",
            record,
          )
        }
      None => ()
    }
    match policy.max_ttl {
      Some(maximum) =>
        if record.ttl > maximum {
          add_record_note(
            findings,
            "P101",
            "warning",
            "TTL \{record.ttl} exceeds policy maximum \{maximum}",
            record,
          )
        }
      None => ()
    }
  }
}

///|
fn policy_ns_checks(
  zone : Zone,
  policy : AuditPolicy,
  findings : Array[Diagnostic],
) -> Unit {
  let mut count = 0
  for record in zone.records {
    if record.owner == zone.origin && record.record_type == "NS" {
      count += 1
    }
  }
  if count < policy.min_apex_ns {
    findings.push(
      diagnostic(
        "P102",
        "warning",
        "apex has \{count} NS records; policy requires \{policy.min_apex_ns}",
        1,
        1,
        owner=zone.origin,
      ),
    )
  }
}

///|
fn policy_mail_checks(zone : Zone, findings : Array[Diagnostic]) -> Unit {
  let ipv6_owners : Map[String, Bool] = Map([])
  for record in zone.records {
    if record.record_type == "AAAA" {
      ipv6_owners.set(record.owner, true)
    }
  }
  for record in zone.records {
    if record.record_type != "MX" || record.rdata.length() != 2 {
      continue
    }
    let target = absolute_rdata_name(record, 1, zone.origin)
    if is_within_zone(target, zone.origin) && ipv6_owners.get(target) is None {
      add_record_note(
        findings,
        "P103",
        "warning",
        "in-zone mail exchanger has no AAAA record: \{target}",
        record,
      )
    }
  }
}

///|
fn policy_type_checks(
  zone : Zone,
  policy : AuditPolicy,
  findings : Array[Diagnostic],
) -> Unit {
  for record in zone.records {
    for forbidden in policy.forbid_types {
      if record.record_type == forbidden {
        add_record_note(
          findings,
          "P104",
          "error",
          "record type \{forbidden} is forbidden by policy",
          record,
        )
      }
    }
  }
}

///|
/// Apply optional team policy after the standard DNS validation.
pub fn validate_with_policy(
  zone : Zone,
  policy : AuditPolicy,
) -> Array[Diagnostic] {
  let findings = validate_zone(zone)
  policy_ttl_checks(zone, policy, findings)
  policy_ns_checks(zone, policy, findings)
  if policy.require_ipv6_for_mail {
    policy_mail_checks(zone, findings)
  }
  policy_type_checks(zone, policy, findings)
  findings
}
