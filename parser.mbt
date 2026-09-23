///|
fn upper(text : String) -> String {
  text[:].to_upper().to_owned()
}

///|
fn lower(text : String) -> String {
  text[:].to_lower().to_owned()
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn ends_in_dot(text : String) -> Bool {
  let chars = text.to_array()
  chars.length() > 0 && chars[chars.length() - 1] == '.'
}

///|
/// Convert a master-file owner or domain-valued RDATA to an absolute DNS name.
pub fn absolute_name(name : String, origin : String) -> String {
  let canonical_origin = if ends_in_dot(origin) { lower(origin) } else { lower(origin) + "." }
  if name == "@" {
    canonical_origin
  } else if name == "." {
    "."
  } else if ends_in_dot(name) {
    lower(name)
  } else {
    lower(name) + "." + canonical_origin
  }
}

///|
fn ttl_factor(c : Char) -> Int? {
  match c {
    's' | 'S' => Some(1)
    'm' | 'M' => Some(60)
    'h' | 'H' => Some(3600)
    'd' | 'D' => Some(86400)
    'w' | 'W' => Some(604800)
    _ => None
  }
}

///|
/// Parse a TTL written as seconds or a sequence such as 1w2d3h.
pub fn parse_ttl(input : String) -> Int? {
  let chars = input.to_array()
  if chars.length() == 0 {
    return None
  }
  let mut total = 0
  let mut group = 0
  let mut digits = false
  for c in chars {
    if is_digit(c) {
      let digit = c.to_int() - '0'.to_int()
      if group > (2147483647 - digit) / 10 {
        return None
      }
      group = group * 10 + digit
      digits = true
    } else {
      if !digits {
        return None
      }
      let factor = match ttl_factor(c) {
        Some(value) => value
        None => return None
      }
      if group > (2147483647 - total) / factor {
        return None
      }
      total += group * factor
      group = 0
      digits = false
    }
  }
  if digits {
    if group > 2147483647 - total {
      return None
    }
    total += group
  }
  Some(total)
}

///|
fn is_class(input : String) -> Bool {
  upper(input) == "IN" || upper(input) == "CH" || upper(input) == "HS"
}

///|
fn is_record_type(input : String) -> Bool {
  match upper(input) {
    "A" | "AAAA" | "NS" | "SOA" | "CNAME" | "MX" | "TXT" | "PTR" |
    "SRV" | "CAA" | "DS" | "DNSKEY" | "RRSIG" | "NSEC" | "NSEC3" |
    "TLSA" | "SSHFP" | "NAPTR" | "SPF" | "LOC" => true
    _ => false
  }
}

///|
fn add_parse_error(
  diagnostics : Array[Diagnostic],
  code : String,
  message : String,
  stmt : Statement,
) -> Unit {
  let column = if stmt.tokens.length() > 0 { stmt.tokens[0].column } else { 1 }
  diagnostics.push(diagnostic(code, "error", message, stmt.line, column))
}

///|
fn parse_directive(
  stmt : Statement,
  current_origin : String,
  default_ttl : Int,
  diagnostics : Array[Diagnostic],
) -> (String, Int) {
  let head = upper(stmt.tokens[0].text)
  match head {
    "$ORIGIN" => {
      if stmt.tokens.length() != 2 {
        add_parse_error(diagnostics, "Z010", "$ORIGIN requires one name", stmt)
        (current_origin, default_ttl)
      } else {
        (absolute_name(stmt.tokens[1].text, current_origin), default_ttl)
      }
    }
    "$TTL" => {
      if stmt.tokens.length() != 2 {
        add_parse_error(diagnostics, "Z011", "$TTL requires one duration", stmt)
        (current_origin, default_ttl)
      } else {
        match parse_ttl(stmt.tokens[1].text) {
          Some(value) => (current_origin, value)
          None => {
            add_parse_error(diagnostics, "Z012", "invalid $TTL duration", stmt)
            (current_origin, default_ttl)
          }
        }
      }
    }
    "$INCLUDE" | "$GENERATE" => {
      add_parse_error(
        diagnostics,
        "Z013",
        "directive is outside the supported offline subset",
        stmt,
      )
      (current_origin, default_ttl)
    }
    _ => {
      add_parse_error(diagnostics, "Z014", "unknown master-file directive", stmt)
      (current_origin, default_ttl)
    }
  }
}

///|
fn parse_record(
  stmt : Statement,
  current_origin : String,
  previous_owner : String,
  default_ttl : Int,
  diagnostics : Array[Diagnostic],
) -> ResourceRecord? {
  let tokens = stmt.tokens
  let mut index = 0
  let owner = if stmt.indented {
    if previous_owner == "" {
      add_parse_error(diagnostics, "Z020", "inherited owner has no preceding record", stmt)
      return None
    }
    previous_owner
  } else {
    index = 1
    absolute_name(tokens[0].text, current_origin)
  }
  let mut ttl = default_ttl
  let mut class_name = "IN"
  let mut seen_ttl = false
  let mut seen_class = false
  while index < tokens.length() && !is_record_type(tokens[index].text) {
    let token = tokens[index]
    if is_class(token.text) {
      if seen_class {
        diagnostics.push(diagnostic("Z021", "error", "duplicate DNS class", token.line, token.column, owner=owner))
      }
      class_name = upper(token.text)
      seen_class = true
    } else {
      match parse_ttl(token.text) {
        Some(value) => {
          if seen_ttl {
            diagnostics.push(diagnostic("Z022", "error", "duplicate TTL", token.line, token.column, owner=owner))
          }
          ttl = value
          seen_ttl = true
        }
        None => {
          diagnostics.push(diagnostic("Z023", "error", "unsupported or missing record type", token.line, token.column, owner=owner))
          return None
        }
      }
    }
    index += 1
  }
  if index >= tokens.length() {
    add_parse_error(diagnostics, "Z024", "resource record has no type", stmt)
    return None
  }
  let record_type = upper(tokens[index].text)
  index += 1
  let rdata : Array[String] = []
  while index < tokens.length() {
    rdata.push(tokens[index].text)
    index += 1
  }
  if rdata.length() == 0 {
    add_parse_error(diagnostics, "Z025", "resource record has no data", stmt)
  }
  Some({
    owner,
    ttl,
    class_name,
    record_type,
    rdata,
    line: stmt.line,
    column: tokens[0].column,
  })
}

///|
/// Parse the supported RFC 1035 zone-file subset without filesystem or network access.
pub fn parse_zone(input : String, origin : String) -> Zone {
  let lexical = lex_zone(input)
  let diagnostics = lexical.diagnostics
  let records : Array[ResourceRecord] = []
  let initial_origin = absolute_name("@", origin)
  let mut current_origin = initial_origin
  let mut previous_owner = ""
  let mut default_ttl = 3600
  for stmt in lexical.statements {
    if stmt.tokens.length() == 0 {
      continue
    }
    if stmt.tokens[0].text.to_array()[0] == '$' {
      let (next_origin, next_ttl) = parse_directive(
        stmt,
        current_origin,
        default_ttl,
        diagnostics,
      )
      current_origin = next_origin
      default_ttl = next_ttl
    } else {
      match parse_record(stmt, current_origin, previous_owner, default_ttl, diagnostics) {
        Some(record) => {
          previous_owner = record.owner
          records.push(record)
        }
        None => ()
      }
    }
  }
  { origin: initial_origin, records, diagnostics }
}
