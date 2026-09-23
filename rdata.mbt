///|
fn decimal_number(text : String) -> Int? {
  let chars = text.to_array()
  if chars.length() == 0 {
    return None
  }
  let mut result = 0
  for c in chars {
    if !is_digit(c) {
      return None
    }
    let digit = c.to_int() - '0'.to_int()
    if result > (2147483647 - digit) / 10 {
      return None
    }
    result = result * 10 + digit
  }
  Some(result)
}

///|
pub fn valid_ipv4(value : String) -> Bool {
  let parts = value.split(".").collect()
  if parts.length() != 4 {
    return false
  }
  for part in parts {
    let text = part.to_owned()
    if text.length() == 0 || text.length() > 3 {
      return false
    }
    match decimal_number(text) {
      Some(n) => if n > 255 { return false }
      None => return false
    }
  }
  true
}

///|
fn is_hex(c : Char) -> Bool {
  is_digit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

///|
/// Check the text form of an IPv6 address without accepting zone identifiers.
pub fn valid_ipv6(value : String) -> Bool {
  let chars = value.to_array()
  let mut dotted = false
  let mut last_colon = -1
  for index in 0..<chars.length() {
    if chars[index] == '.' {
      dotted = true
    }
    if chars[index] == ':' {
      last_colon = index
    }
  }
  if dotted {
    if last_colon < 0 || last_colon == chars.length() - 1 {
      return false
    }
    let suffix = value[last_colon + 1:].to_owned()
    if !valid_ipv4(suffix) {
      return false
    }
    let prefix = value[:last_colon].to_owned()
    return valid_ipv6(prefix + ":0:0")
  }
  if chars.length() < 2 || chars.length() > 39 {
    return false
  }
  let mut compressed = false
  let mut groups = 0
  let mut group_len = 0
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == ':' {
      if i + 1 < chars.length() && chars[i + 1] == ':' {
        if compressed {
          return false
        }
        compressed = true
        if group_len > 0 {
          groups += 1
          group_len = 0
        }
        i += 2
        continue
      }
      if group_len == 0 {
        return false
      }
      groups += 1
      group_len = 0
    } else if is_hex(c) {
      group_len += 1
      if group_len > 4 {
        return false
      }
    } else {
      return false
    }
    i += 1
  }
  if group_len > 0 {
    groups += 1
  } else if !compressed {
    return false
  }
  if compressed {
    groups < 8
  } else {
    groups == 8
  }
}

///|
fn number_in_range(text : String, low : Int, high : Int) -> Bool {
  match decimal_number(text) {
    Some(n) => n >= low && n <= high
    None => false
  }
}

///|
fn require_rdata_length(
  record : ResourceRecord,
  expected : Int,
  diagnostics : Array[Diagnostic],
) -> Bool {
  if record.rdata.length() == expected {
    true
  } else {
    diagnostics.push(
      diagnostic(
        "Z100",
        "error",
        "\{record.record_type} requires \{expected} RDATA fields; found \{record.rdata.length()}",
        record.line,
        record.column,
        owner=record.owner,
      ),
    )
    false
  }
}

///|
fn check_domain_field(
  record : ResourceRecord,
  index : Int,
  origin : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  let name = absolute_rdata_name(record, index, origin)
  if !valid_domain_name(name) {
    diagnostics.push(
      diagnostic(
        "Z101",
        "error",
        "invalid domain name in \{record.record_type} data: \{record.rdata[index]}",
        record.line,
        record.column,
        owner=record.owner,
      ),
    )
  }
}

///|
fn check_address_record(
  record : ResourceRecord,
  diagnostics : Array[Diagnostic],
) -> Unit {
  if !require_rdata_length(record, 1, diagnostics) {
    return
  }
  let valid = if record.record_type == "A" {
    valid_ipv4(record.rdata[0])
  } else {
    valid_ipv6(record.rdata[0])
  }
  if !valid {
    diagnostics.push(
      diagnostic(
        "Z102",
        "error",
        "invalid \{record.record_type} address: \{record.rdata[0]}",
        record.line,
        record.column,
        owner=record.owner,
      ),
    )
  }
}

///|
fn check_soa(
  record : ResourceRecord,
  origin : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  if !require_rdata_length(record, 7, diagnostics) {
    return
  }
  check_domain_field(record, 0, origin, diagnostics)
  check_domain_field(record, 1, origin, diagnostics)
  if parse_serial(record.rdata[2]) is None {
    diagnostics.push(
      diagnostic(
        "Z103",
        "error",
        "SOA serial must be a 32-bit unsigned decimal integer",
        record.line,
        record.column,
        owner=record.owner,
      ),
    )
  }
  for i in 3..<7 {
    if parse_ttl(record.rdata[i]) is None {
      diagnostics.push(
        diagnostic(
          "Z103",
          "error",
          "SOA numeric or duration field is invalid: \{record.rdata[i]}",
          record.line,
          record.column,
          owner=record.owner,
        ),
      )
    }
  }
}

///|
fn check_mx(
  record : ResourceRecord,
  origin : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  if !require_rdata_length(record, 2, diagnostics) {
    return
  }
  if !number_in_range(record.rdata[0], 0, 65535) {
    diagnostics.push(
      diagnostic(
        "Z104",
        "error",
        "MX preference must be 0..65535",
        record.line,
        record.column,
        owner=record.owner,
      ),
    )
  }
  check_domain_field(record, 1, origin, diagnostics)
}

///|
fn check_srv(
  record : ResourceRecord,
  origin : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  if !require_rdata_length(record, 4, diagnostics) {
    return
  }
  for i in 0..<3 {
    if !number_in_range(record.rdata[i], 0, 65535) {
      diagnostics.push(
        diagnostic(
          "Z105",
          "error",
          "SRV priority, weight, and port must be 0..65535",
          record.line,
          record.column,
          owner=record.owner,
        ),
      )
      break
    }
  }
  check_domain_field(record, 3, origin, diagnostics)
}

///|
fn check_caa(record : ResourceRecord, diagnostics : Array[Diagnostic]) -> Unit {
  if !require_rdata_length(record, 3, diagnostics) {
    return
  }
  if !number_in_range(record.rdata[0], 0, 255) {
    diagnostics.push(
      diagnostic(
        "Z106",
        "error",
        "CAA flags must be 0..255",
        record.line,
        record.column,
        owner=record.owner,
      ),
    )
  }
  if record.rdata[1].length() == 0 || record.rdata[1].length() > 15 {
    diagnostics.push(
      diagnostic(
        "Z107",
        "error",
        "CAA tag length must be 1..15",
        record.line,
        record.column,
        owner=record.owner,
      ),
    )
  }
}

///|
fn check_record_data(
  record : ResourceRecord,
  origin : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  match record.record_type {
    "A" | "AAAA" => check_address_record(record, diagnostics)
    "NS" | "CNAME" | "PTR" =>
      if require_rdata_length(record, 1, diagnostics) {
        check_domain_field(record, 0, origin, diagnostics)
      }
    "SOA" => check_soa(record, origin, diagnostics)
    "MX" => check_mx(record, origin, diagnostics)
    "SRV" => check_srv(record, origin, diagnostics)
    "CAA" => check_caa(record, diagnostics)
    "TXT" | "SPF" =>
      if record.rdata.length() == 0 {
        diagnostics.push(
          diagnostic(
            "Z108",
            "error",
            "text record requires at least one string",
            record.line,
            record.column,
            owner=record.owner,
          ),
        )
      }
    _ => ()
  }
}
