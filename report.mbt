///|
fn json_hex_digit(n : Int) -> Char {
  let digits = "0123456789abcdef".to_array()
  digits[n]
}

///|
fn json_escaped(value : String) -> String {
  let out = StringBuilder::new()
  out.write_char('"')
  for c in value {
    match c {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      _ => {
        let n = c.to_int()
        if n < 32 {
          out.write_string("\\u00")
          out.write_char(json_hex_digit(n / 16))
          out.write_char(json_hex_digit(n % 16))
        } else {
          out.write_char(c)
        }
      }
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
fn write_json_field(out : StringBuilder, name : String, value : String, comma : Bool) -> Unit {
  if comma {
    out.write_char(',')
  }
  out.write_string(json_escaped(name))
  out.write_char(':')
  out.write_string(json_escaped(value))
}

///|
fn write_json_number(out : StringBuilder, name : String, value : Int, comma : Bool) -> Unit {
  if comma {
    out.write_char(',')
  }
  out.write_string(json_escaped(name))
  out.write_char(':')
  out.write_string(value.to_string())
}

///|
fn write_diagnostic_json(out : StringBuilder, item : Diagnostic) -> Unit {
  out.write_char('{')
  write_json_field(out, "code", item.code, false)
  write_json_field(out, "severity", item.severity, true)
  write_json_field(out, "message", item.message, true)
  write_json_number(out, "line", item.line, true)
  write_json_number(out, "column", item.column, true)
  write_json_field(out, "owner", item.owner, true)
  out.write_char('}')
}

///|
/// Render a deterministic, parseable JSON diagnostics object.
pub fn render_diagnostics_json(items : Array[Diagnostic]) -> String {
  let out = StringBuilder::new()
  out.write_string("{\"errors\":")
  out.write_string(error_count(items).to_string())
  out.write_string(",\"warnings\":")
  out.write_string(warning_count(items).to_string())
  out.write_string(",\"diagnostics\":[")
  for i in 0..<items.length() {
    if i > 0 {
      out.write_char(',')
    }
    write_diagnostic_json(out, items[i])
  }
  out.write_string("]}")
  out.to_string()
}

///|
fn diagnostic_line(item : Diagnostic) -> String {
  "\{item.line}:\{item.column}: \{item.severity} \{item.code}: \{item.message}"
}

///|
/// Render diagnostics for terminal display.
pub fn render_diagnostics_text(items : Array[Diagnostic]) -> String {
  let out = StringBuilder::new()
  for item in items {
    out.write_string(diagnostic_line(item))
    if item.owner != "" {
      out.write_string(" [")
      out.write_string(item.owner)
      out.write_char(']')
    }
    out.write_char('\n')
  }
  out.write_string("\{error_count(items)} error(s), \{warning_count(items)} warning(s)\n")
  out.to_string()
}

///|
fn markdown_escape(text : String) -> String {
  let out = StringBuilder::new()
  for c in text {
    if c == '|' {
      out.write_string("\\|")
    } else if c == '\n' {
      out.write_string("<br>")
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
/// Render a compact review report suitable for a pull request description.
pub fn render_diagnostics_markdown(items : Array[Diagnostic]) -> String {
  let out = StringBuilder::new()
  out.write_string("# MoonZoneGuard report\n\n")
  out.write_string("Errors: \{error_count(items)} · Warnings: \{warning_count(items)}\n\n")
  out.write_string("| Location | Severity | Rule | Finding |\n| --- | --- | --- | --- |\n")
  for item in items {
    out.write_string("| \{item.line}:\{item.column} | \{item.severity} | \{item.code} | \{markdown_escape(item.message)} |\n")
  }
  if items.length() == 0 {
    out.write_string("| — | — | — | No findings |\n")
  }
  out.to_string()
}

///|
fn write_rdata_text(out : StringBuilder, rdata : Array[String]) -> Unit {
  for i in 0..<rdata.length() {
    if i > 0 {
      out.write_char(' ')
    }
    out.write_string(rdata[i])
  }
}

///|
fn write_change_json(out : StringBuilder, change : ZoneChange) -> Unit {
  out.write_char('{')
  write_json_field(out, "kind", change.kind, false)
  write_json_field(out, "owner", change.owner, true)
  write_json_field(out, "type", change.record_type, true)
  out.write_string(",\"rdata\":[")
  for i in 0..<change.rdata.length() {
    if i > 0 {
      out.write_char(',')
    }
    out.write_string(json_escaped(change.rdata[i]))
  }
  out.write_char(']')
  out.write_string(",\"before_ttl\":")
  match change.before_ttl {
    Some(n) => out.write_string(n.to_string())
    None => out.write_string("null")
  }
  out.write_string(",\"after_ttl\":")
  match change.after_ttl {
    Some(n) => out.write_string(n.to_string())
    None => out.write_string("null")
  }
  out.write_char('}')
}

///|
pub fn render_diff_json(diff : ZoneDiff) -> String {
  let out = StringBuilder::new()
  out.write_string("{\"changes\":[")
  for i in 0..<diff.changes.length() {
    if i > 0 {
      out.write_char(',')
    }
    write_change_json(out, diff.changes[i])
  }
  out.write_string("],\"diagnostics\":[")
  for i in 0..<diff.diagnostics.length() {
    if i > 0 {
      out.write_char(',')
    }
    write_diagnostic_json(out, diff.diagnostics[i])
  }
  out.write_string("]}")
  out.to_string()
}

///|
pub fn render_diff_text(diff : ZoneDiff) -> String {
  let out = StringBuilder::new()
  for change in diff.changes {
    out.write_string(change.kind)
    out.write_char(' ')
    out.write_string(change.owner)
    out.write_char(' ')
    out.write_string(change.record_type)
    out.write_char(' ')
    write_rdata_text(out, change.rdata)
    if change.kind == "ttl-changed" {
      out.write_string(" ttl ")
      match change.before_ttl {
        Some(n) => out.write_string(n.to_string())
        None => out.write_string("?")
      }
      out.write_string(" -> ")
      match change.after_ttl {
        Some(n) => out.write_string(n.to_string())
        None => out.write_string("?")
      }
    }
    out.write_char('\n')
  }
  for item in diff.diagnostics {
    out.write_string(diagnostic_line(item))
    out.write_char('\n')
  }
  out.write_string("\{diff.changes.length()} change(s), \{error_count(diff.diagnostics)} error(s)\n")
  out.to_string()
}
