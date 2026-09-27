///|
/// A digest association, not evidence that the public key or RRSIG is valid.
pub(all) struct DnskeyFingerprint {
  owner : String
  flags : Int
  algorithm : Int
  key_tag : Int
  sha256_digest : String
} derive(Debug)

///|
fn dnssec_number(text : String, maximum : Int) -> Int? {
  if !number_in_range(text, 0, maximum) {
    return None
  }
  let mut value = 0
  for c in text {
    value = value * 10 + c.to_int() - '0'.to_int()
  }
  Some(value)
}

///|
fn dnssec_join_fields(fields : Array[String], start : Int) -> String {
  let out = StringBuilder()
  for i in start..<fields.length() {
    out.write_string(fields[i])
  }
  out.to_string()
}

///|
fn dnssec_hex(text : String) -> Bool {
  for c in text {
    if !(is_digit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
      return false
    }
  }
  text.length() > 0
}

///|
/// RFC 4034 canonical owner encoding (ASCII names without compression).
fn dnssec_owner_wire(owner : String) -> Array[Byte]? {
  if !valid_domain_name(owner) || owner.contains("*") {
    return None
  }
  let bytes : Array[Byte] = []
  for part in lower(owner).split(".") {
    let label = part.to_owned()
    if label == "" {
      continue
    }
    bytes.push(label.length().to_byte())
    for c in label {
      bytes.push(c.to_int().to_byte())
    }
  }
  bytes.push((0).to_byte())
  Some(bytes)
}

///|
/// Compute key tag and digest type 2 for a numeric DNSKEY presentation record.
/// RSA/MD5 algorithm 1 is deliberately unsupported because its key tag differs.
pub fn dnskey_ds_sha256(
  record : ResourceRecord,
) -> Result[DnskeyFingerprint, String] {
  if record.record_type != "DNSKEY" || record.rdata.length() < 4 {
    return Err("DNSKEY requires flags, protocol, algorithm and public key")
  }
  let flags = match dnssec_number(record.rdata[0], 65535) {
    Some(value) => value
    None => return Err("DNSKEY flags must be 0..65535")
  }
  if dnssec_number(record.rdata[1], 255) != Some(3) {
    return Err("DNSKEY protocol must be 3")
  }
  let algorithm = match dnssec_number(record.rdata[2], 255) {
    Some(value) if value > 1 && value < 255 => value
    _ =>
      return Err("DNSKEY algorithm must be 2..254; algorithm 1 is unsupported")
  }
  let text = dnssec_join_fields(record.rdata, 3)
  if text.length() > 87376 {
    return Err("DNSKEY public key exceeds DNS RDATA size bound")
  }
  let key = @base64.decode(text[:]) catch {
    _ => return Err("DNSKEY public key is not valid Base64")
  }
  if key.length() == 0 || key.length() > 65531 {
    return Err("DNSKEY public key must contain 1..65531 bytes")
  }
  let rdata : Array[Byte] = [
    (flags / 256).to_byte(),
    (flags % 256).to_byte(),
    (3).to_byte(),
    algorithm.to_byte(),
  ]
  for b in key {
    rdata.push(b)
  }
  let mut accumulator = 0U
  for i in 0..<rdata.length() {
    let value = rdata[i].to_int().to_uint()
    accumulator += if i % 2 == 0 { value << 8 } else { value }
  }
  let key_tag = ((accumulator + ((accumulator >> 16) & 65535U)) & 65535U).to_int()
  let owner_bytes = match dnssec_owner_wire(record.owner) {
    Some(value) => value
    None =>
      return Err("DNSKEY owner must be a canonical ASCII non-wildcard name")
  }
  let digest = @sha256.Digest::new()
  for b in owner_bytes {
    @sha256.HashFunc::write(digest, b)
  }
  for b in rdata {
    @sha256.HashFunc::write(digest, b)
  }
  Ok({
    owner: lower(record.owner),
    flags,
    algorithm,
    key_tag,
    sha256_digest: lower(@sha256.HashFunc::check_sum(digest)),
  })
}

///|
fn audit_dnssec_link(
  parent : Zone,
  child : Zone,
  parent_source : String,
  child_source : String,
  findings : Array[DelegationFinding],
) -> Unit {
  let ds_records = records_at(parent, child.origin, "DS")
  let key_records = records_at(child, child.origin, "DNSKEY")
  if ds_records.length() == 0 {
    if key_records.length() > 0 {
      delegation_finding(
        findings,
        "S106",
        "warning",
        parent_source,
        child.origin,
        0,
        "child publishes DNSKEY but parent has no DS; no digest trust link is checked",
      )
    }
    return
  }
  let fingerprints : Array[DnskeyFingerprint] = []
  let key_lines : Array[Int] = []
  for record in key_records {
    match dnskey_ds_sha256(record) {
      Err(message) =>
        delegation_finding(
          findings,
          "S102",
          "error",
          child_source,
          record.owner,
          record.line,
          message,
        )
      Ok(key) =>
        // Zone Key must be set; revoked keys do not establish this association.
        if key.flags / 256 % 2 == 1 && key.flags / 128 % 2 == 0 {
          fingerprints.push(key)
          key_lines.push(record.line)
        }
    }
  }
  let mut matches = 0
  for record in ds_records {
    if record.rdata.length() < 4 {
      delegation_finding(
        findings,
        "S101",
        "error",
        parent_source,
        record.owner,
        record.line,
        "DS requires key tag, algorithm, digest type and digest",
      )
      continue
    }
    let tag = dnssec_number(record.rdata[0], 65535)
    let algorithm = dnssec_number(record.rdata[1], 255)
    let digest_type = dnssec_number(record.rdata[2], 255)
    let hex = dnssec_join_fields(record.rdata, 3)
    if tag is None ||
      algorithm is None ||
      digest_type is None ||
      !dnssec_hex(hex) {
      delegation_finding(
        findings,
        "S101",
        "error",
        parent_source,
        record.owner,
        record.line,
        "DS has invalid numeric fields or hexadecimal digest",
      )
      continue
    }
    if digest_type != Some(2) {
      delegation_finding(
        findings,
        "S103",
        "warning",
        parent_source,
        record.owner,
        record.line,
        "unsupported DS digest type; only SHA-256 type 2 is checked",
      )
      continue
    }
    if hex.length() != 64 {
      delegation_finding(
        findings,
        "S101",
        "error",
        parent_source,
        record.owner,
        record.line,
        "SHA-256 DS digest must contain 64 hexadecimal characters",
      )
      continue
    }
    let mut matched = false
    for i in 0..<fingerprints.length() {
      let key = fingerprints[i]
      if tag == Some(key.key_tag) &&
        algorithm == Some(key.algorithm) &&
        lower(hex) == key.sha256_digest {
        matched = true
        delegation_finding(
          findings,
          "S100",
          "note",
          parent_source,
          record.owner,
          record.line,
          "SHA-256 DS matches DNSKEY tag \{key.key_tag} at \{child_source}:\{key_lines[i]}; signatures remain unchecked",
        )
        break
      }
    }
    if matched {
      matches += 1
    } else {
      delegation_finding(
        findings,
        "S104",
        "warning",
        parent_source,
        record.owner,
        record.line,
        "SHA-256 DS has no matching eligible child DNSKEY",
      )
    }
  }
  if matches == 0 {
    delegation_finding(
      findings,
      "S105",
      "error",
      parent_source,
      child.origin,
      ds_records[0].line,
      "no supported SHA-256 DS/DNSKEY association in this deployment snapshot",
    )
  }
}

///|
/// Intentional DNSSEC de-signing needs a separate operator-reviewed workflow.
fn audit_dnssec_transition(
  before : Zone,
  after : Zone,
  child_origin : String,
  source : String,
  findings : Array[DelegationFinding],
) -> Unit {
  let old_ds = records_at(before, child_origin, "DS")
  if old_ds.length() > 0 && records_at(after, child_origin, "DS").length() == 0 {
    delegation_finding(
      findings, "S107", "error", source, child_origin, 0, "parent removes all child DS records; trust downgrade is blocked by conservative rollout policy",
    )
  }
}
