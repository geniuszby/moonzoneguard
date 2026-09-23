///|
fn is_domain_rdata_field(record_type : String, index : Int) -> Bool {
  match record_type {
    "NS" | "CNAME" | "PTR" => index == 0
    "MX" => index == 1
    "SOA" => index == 0 || index == 1
    "SRV" => index == 3
    _ => false
  }
}

///|
fn canonical_rdata_field(record : ResourceRecord, index : Int) -> String {
  if is_domain_rdata_field(record.record_type, index) {
    absolute_name(record.rdata[index], record.origin)
  } else if record.record_type == "AAAA" {
    lower(record.rdata[index])
  } else {
    record.rdata[index]
  }
}

///|
fn write_canonical_rdata(out : StringBuilder, record : ResourceRecord) -> Unit {
  for index in 0..<record.rdata.length() {
    if index > 0 {
      out.write_char(' ')
    }
    out.write_string(canonical_rdata_field(record, index))
  }
}

///|
/// Render one record with explicit owner, TTL, class, and type.
/// RDATA names are expanded against the `$ORIGIN` active at that record.
pub fn canonical_record_line(record : ResourceRecord) -> String {
  let out = StringBuilder()
  out.write_string(record.owner)
  out.write_char(' ')
  out.write_string(record.ttl.to_string())
  out.write_char(' ')
  out.write_string(record.class_name)
  out.write_char(' ')
  out.write_string(record.record_type)
  out.write_char(' ')
  write_canonical_rdata(out, record)
  out.to_string()
}

///|
/// Produce stable, explicit master-file text in source record order.
pub fn render_canonical_zone(zone : Zone) -> String {
  let out = StringBuilder()
  out.write_string("$ORIGIN \{zone.origin}\n")
  for record in zone.records {
    out.write_string(canonical_record_line(record))
    out.write_char('\n')
  }
  out.to_string()
}
