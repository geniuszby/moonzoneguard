///|
fn ascii_alpha(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
fn ascii_alnum(c : Char) -> Bool {
  ascii_alpha(c) || is_digit(c)
}

///|
fn valid_label(label : String) -> Bool {
  let chars = label.to_array()
  if chars.length() == 0 || chars.length() > 63 {
    return false
  }
  if !(ascii_alnum(chars[0]) || chars[0] == '_') {
    return false
  }
  if !(ascii_alnum(chars[chars.length() - 1]) ||
    chars[chars.length() - 1] == '_') {
    return false
  }
  for c in chars {
    if !(ascii_alnum(c) || c == '-' || c == '_') {
      return false
    }
  }
  true
}

///|
/// Conservative ASCII presentation-name validation. Escaped octets are outside v1 scope.
pub fn valid_domain_name(name : String) -> Bool {
  if name == "." {
    return true
  }
  if !ends_in_dot(name) || name.length() > 254 {
    return false
  }
  let labels = name.split(".").collect()
  if labels.length() < 2 {
    return false
  }
  for index in 0..<(labels.length() - 1) {
    if index == 0 && labels[index].to_owned() == "*" {
      continue
    }
    if !valid_label(labels[index].to_owned()) {
      return false
    }
  }
  true
}

///|
fn absolute_rdata_name(
  record : ResourceRecord,
  index : Int,
  _origin : String,
) -> String {
  absolute_name(record.rdata[index], record.origin)
}

///|
fn is_within_zone(name : String, origin : String) -> Bool {
  if name == origin {
    return true
  }
  let suffix = "." + origin
  let n = name.to_array()
  let s = suffix.to_array()
  if n.length() < s.length() {
    return false
  }
  let start = n.length() - s.length()
  for i in 0..<s.length() {
    if n[start + i] != s[i] {
      return false
    }
  }
  true
}
