///|
fn address_owners(zone : Zone) -> Map[String, Bool] {
  let owners : Map[String, Bool] = Map([])
  for record in zone.records {
    if record.record_type == "A" || record.record_type == "AAAA" {
      owners.set(record.owner, true)
    }
  }
  owners
}

///|
fn check_in_zone_targets(zone : Zone, diagnostics : Array[Diagnostic]) -> Unit {
  let addresses = address_owners(zone)
  for record in zone.records {
    let target_index = match record.record_type {
      "NS" => 0
      "MX" => 1
      "SRV" => 3
      _ => -1
    }
    if target_index < 0 || record.rdata.length() <= target_index {
      continue
    }
    let target = absolute_rdata_name(record, target_index, zone.origin)
    if target == "." {
      continue
    }
    if is_within_zone(target, zone.origin) && addresses.get(target) is None {
      let code = match record.record_type {
        "NS" => "Z230"
        "MX" => "Z231"
        _ => "Z232"
      }
      add_record_note(
        diagnostics,
        code,
        "warning",
        "in-zone \{record.record_type} target has no A or AAAA record: \{target}",
        record,
      )
    }
  }
}

///|
fn check_apex_alias(zone : Zone, diagnostics : Array[Diagnostic]) -> Unit {
  for record in zone.records {
    if record.owner == zone.origin && record.record_type == "CNAME" {
      add_record_note(
        diagnostics, "Z233", "error", "zone apex cannot be a CNAME", record,
      )
    }
  }
}

///|
fn check_singleton_records(
  zone : Zone,
  diagnostics : Array[Diagnostic],
) -> Unit {
  let owners : Map[String, Int] = Map([])
  for record in zone.records {
    if record.record_type != "CNAME" {
      continue
    }
    let count = match owners.get(record.owner) {
      Some(value) => value
      None => 0
    }
    if count > 0 {
      add_record_note(
        diagnostics, "Z234", "error", "owner has multiple CNAME records", record,
      )
    }
    owners.set(record.owner, count + 1)
  }
}

///|
fn check_zone_integrity(zone : Zone, diagnostics : Array[Diagnostic]) -> Unit {
  check_in_zone_targets(zone, diagnostics)
  check_apex_alias(zone, diagnostics)
  check_singleton_records(zone, diagnostics)
}
