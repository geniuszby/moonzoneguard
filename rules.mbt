///|
fn is_dnssec_companion(record_type : String) -> Bool {
  record_type == "RRSIG" || record_type == "NSEC" || record_type == "NSEC3"
}

///|
fn data_key(record : ResourceRecord) -> String {
  let builder = StringBuilder::new()
  builder.write_string(record.owner)
  builder.write_char('|')
  builder.write_string(record.class_name)
  builder.write_char('|')
  builder.write_string(record.record_type)
  for item in record.rdata {
    builder.write_char('|')
    builder.write_string(lower(item))
  }
  builder.to_string()
}

///|
fn rrset_key(record : ResourceRecord) -> String {
  record.owner + "|" + record.class_name + "|" + record.record_type
}

///|
fn add_record_note(
  diagnostics : Array[Diagnostic],
  code : String,
  severity : String,
  message : String,
  record : ResourceRecord,
) -> Unit {
  diagnostics.push(
    diagnostic(
      code,
      severity,
      message,
      record.line,
      record.column,
      owner=record.owner,
    ),
  )
}

///|
fn check_zone_structure(zone : Zone, diagnostics : Array[Diagnostic]) -> Unit {
  let mut soa_count = 0
  let mut ns_count = 0
  for record in zone.records {
    if !valid_domain_name(record.owner) {
      add_record_note(
        diagnostics, "Z200", "error", "invalid owner name", record,
      )
    }
    if !is_within_zone(record.owner, zone.origin) {
      add_record_note(
        diagnostics, "Z201", "error", "owner lies outside the declared zone", record,
      )
    }
    if record.class_name != "IN" {
      add_record_note(
        diagnostics, "Z202", "warning", "class is outside the Internet zone profile",
        record,
      )
    }
    if record.record_type == "SOA" {
      if record.owner != zone.origin {
        add_record_note(
          diagnostics, "Z203", "error", "SOA must be at the zone apex", record,
        )
      } else {
        soa_count += 1
      }
    }
    if record.record_type == "NS" && record.owner == zone.origin {
      ns_count += 1
    }
  }
  if soa_count == 0 {
    diagnostics.push(
      diagnostic(
        "Z204",
        "error",
        "zone apex has no SOA record",
        1,
        1,
        owner=zone.origin,
      ),
    )
  } else if soa_count > 1 {
    diagnostics.push(
      diagnostic(
        "Z205",
        "error",
        "zone apex has more than one SOA record",
        1,
        1,
        owner=zone.origin,
      ),
    )
  }
  if ns_count == 0 {
    diagnostics.push(
      diagnostic(
        "Z206",
        "error",
        "zone apex has no NS record",
        1,
        1,
        owner=zone.origin,
      ),
    )
  }
}

///|
fn check_duplicate_and_ttl(
  zone : Zone,
  diagnostics : Array[Diagnostic],
) -> Unit {
  let seen : Map[String, Bool] = Map([])
  let rrset_ttl : Map[String, Int] = Map([])
  for record in zone.records {
    let key = data_key(record)
    if seen.get(key) is Some(_) {
      add_record_note(
        diagnostics, "Z210", "warning", "duplicate resource record", record,
      )
    } else {
      seen.set(key, true)
    }
    let group_key = rrset_key(record)
    match rrset_ttl.get(group_key) {
      Some(previous) =>
        if previous != record.ttl {
          add_record_note(
            diagnostics, "Z211", "error", "records in one RRset have different TTL values",
            record,
          )
        }
      None => rrset_ttl.set(group_key, record.ttl)
    }
  }
}

///|
fn collect_aliases(zone : Zone) -> Map[String, String] {
  let aliases : Map[String, String] = Map([])
  for record in zone.records {
    if record.record_type == "CNAME" && record.rdata.length() == 1 {
      aliases.set(record.owner, absolute_rdata_name(record, 0, zone.origin))
    }
  }
  aliases
}

///|
fn check_alias_coexistence(
  zone : Zone,
  diagnostics : Array[Diagnostic],
) -> Unit {
  let aliases = collect_aliases(zone)
  for record in zone.records {
    if record.record_type != "CNAME" && !is_dnssec_companion(record.record_type) {
      if aliases.get(record.owner) is Some(_) {
        add_record_note(
          diagnostics, "Z220", "error", "CNAME owner also has other record data",
          record,
        )
      }
    }
    if record.record_type == "NS" && record.rdata.length() == 1 {
      let target = absolute_rdata_name(record, 0, zone.origin)
      if aliases.get(target) is Some(_) {
        add_record_note(
          diagnostics, "Z221", "warning", "NS target is a CNAME alias", record,
        )
      }
    }
    if record.record_type == "MX" && record.rdata.length() == 2 {
      let target = absolute_rdata_name(record, 1, zone.origin)
      if aliases.get(target) is Some(_) {
        add_record_note(
          diagnostics, "Z222", "warning", "MX target is a CNAME alias", record,
        )
      }
    }
  }
}

///|
fn check_alias_cycles(zone : Zone, diagnostics : Array[Diagnostic]) -> Unit {
  let aliases = collect_aliases(zone)
  let reported : Map[String, Bool] = Map([])
  for record in zone.records {
    if record.record_type != "CNAME" || record.rdata.length() != 1 {
      continue
    }
    let start = record.owner
    if reported.get(start) is Some(_) {
      continue
    }
    let mut current = start
    let visited : Map[String, Bool] = Map([])
    let mut steps = 0
    while steps <= zone.records.length() {
      if visited.get(current) is Some(_) {
        if current == start {
          add_record_note(
            diagnostics, "Z223", "error", "CNAME cycle returns to this owner", record,
          )
          reported.set(start, true)
        }
        break
      }
      visited.set(current, true)
      match aliases.get(current) {
        Some(next) => current = next
        None => break
      }
      steps += 1
    }
  }
}

///|
fn check_record_shapes(zone : Zone, diagnostics : Array[Diagnostic]) -> Unit {
  for record in zone.records {
    check_record_data(record, zone.origin, diagnostics)
  }
}

///|
/// Analyze syntax, record content, and cross-record DNS invariants.
pub fn validate_zone(zone : Zone) -> Array[Diagnostic] {
  let diagnostics : Array[Diagnostic] = []
  for item in zone.diagnostics {
    diagnostics.push(item)
  }
  check_zone_structure(zone, diagnostics)
  check_record_shapes(zone, diagnostics)
  check_duplicate_and_ttl(zone, diagnostics)
  check_alias_coexistence(zone, diagnostics)
  check_alias_cycles(zone, diagnostics)
  check_zone_integrity(zone, diagnostics)
  diagnostics
}

///|
/// Parse and validate a master file in one call.
pub fn inspect_zone(input : String, origin : String) -> Array[Diagnostic] {
  validate_zone(parse_zone(input, origin))
}
