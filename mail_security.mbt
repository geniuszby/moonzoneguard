///|
fn is_null_mx(record : ResourceRecord) -> Bool {
  record.record_type == "MX" &&
  record.rdata.length() == 2 &&
  record.rdata[1] == "."
}

///|
fn check_null_mx(zone : Zone, findings : Array[Diagnostic]) -> Unit {
  let mx_counts : Map[String, Int] = Map([])
  for record in zone.records {
    if record.record_type == "MX" {
      let previous = match mx_counts.get(record.owner) {
        Some(n) => n
        None => 0
      }
      mx_counts.set(record.owner, previous + 1)
    }
  }
  for record in zone.records {
    if !is_null_mx(record) {
      continue
    }
    if record.rdata[0] != "0" {
      add_record_note(
        findings, "Z240", "error", "null MX must have preference 0", record,
      )
    }
    match mx_counts.get(record.owner) {
      Some(count) =>
        if count > 1 {
          add_record_note(
            findings, "Z241", "error", "null MX must be the only MX record at its owner",
            record,
          )
        }
      None => ()
    }
  }
}

///|
fn known_caa_tag(tag : String) -> Bool {
  let canonical = lower(tag)
  canonical == "issue" || canonical == "issuewild" || canonical == "iodef"
}

///|
fn valid_caa_tag(tag : String) -> Bool {
  let chars = tag.to_array()
  if chars.length() == 0 || chars.length() > 15 {
    return false
  }
  for c in chars {
    if !ascii_alnum(c) {
      return false
    }
  }
  true
}

///|
fn check_caa_semantics(zone : Zone, findings : Array[Diagnostic]) -> Unit {
  for record in zone.records {
    if record.record_type != "CAA" || record.rdata.length() != 3 {
      continue
    }
    let flag = decimal_number(record.rdata[0])
    match flag {
      Some(value) => {
        if value != 0 && value != 128 {
          add_record_note(
            findings, "Z242", "warning", "CAA reserved flag bits are set; RFC 8659 defines 0 and 128",
            record,
          )
        }
        if value == 128 && !known_caa_tag(record.rdata[1]) {
          add_record_note(
            findings, "Z243", "warning", "unknown critical CAA property may prevent issuance",
            record,
          )
        }
      }
      None => ()
    }
    if !valid_caa_tag(record.rdata[1]) {
      add_record_note(
        findings, "Z244", "error", "CAA property tag must contain ASCII letters and digits",
        record,
      )
    }
    let value = record.rdata[2]
    if value.length() < 2 || !value.has_prefix("\"") || !value.has_suffix("\"") {
      add_record_note(
        findings, "Z245", "warning", "quote CAA property value for portable zone-file syntax",
        record,
      )
    }
  }
}

///|
fn starts_spf_text(record : ResourceRecord) -> Bool {
  if record.record_type != "TXT" || record.rdata.length() == 0 {
    return false
  }
  let first = lower(record.rdata[0])
  first.has_prefix("\"v=spf1") || first.has_prefix("v=spf1")
}

///|
fn check_spf_records(zone : Zone, findings : Array[Diagnostic]) -> Unit {
  let spf_counts : Map[String, Int] = Map([])
  for record in zone.records {
    if record.record_type == "SPF" {
      add_record_note(
        findings, "Z246", "warning", "SPF RR type is obsolete; publish SPF policy in TXT",
        record,
      )
    }
    if starts_spf_text(record) {
      let count = match spf_counts.get(record.owner) {
        Some(n) => n
        None => 0
      }
      if count > 0 {
        add_record_note(
          findings, "Z247", "error", "multiple SPF TXT policies at one owner", record,
        )
      }
      spf_counts.set(record.owner, count + 1)
    }
  }
}

///|
fn check_srv_aliases(zone : Zone, findings : Array[Diagnostic]) -> Unit {
  let aliases = collect_aliases(zone)
  for record in zone.records {
    if record.record_type != "SRV" || record.rdata.length() != 4 {
      continue
    }
    let exchange = absolute_rdata_name(record, 3, zone.origin)
    if aliases.get(exchange) is Some(_) {
      add_record_note(
        findings, "Z248", "warning", "SRV target is an alias; use its canonical host name",
        record,
      )
    }
  }
}

///|
fn check_mail_security(zone : Zone, findings : Array[Diagnostic]) -> Unit {
  check_null_mx(zone, findings)
  check_caa_semantics(zone, findings)
  check_spf_records(zone, findings)
  check_srv_aliases(zone, findings)
}
