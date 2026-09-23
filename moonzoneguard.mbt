///|
/// One parsed DNS resource record. Names are canonical absolute names.
pub(all) struct ResourceRecord {
  owner : String
  origin : String
  ttl : Int
  class_name : String
  record_type : String
  rdata : Array[String]
  line : Int
  column : Int
} derive(Eq, Debug)

///|
/// A source-linked finding. `severity` is error, warning, or note.
pub(all) struct Diagnostic {
  code : String
  severity : String
  message : String
  line : Int
  column : Int
  owner : String
} derive(Eq, Debug)

///|
/// A parsed zone and its syntax diagnostics.
pub(all) struct Zone {
  origin : String
  records : Array[ResourceRecord]
  diagnostics : Array[Diagnostic]
} derive(Debug)

///|
fn diagnostic(
  code : String,
  severity : String,
  message : String,
  line : Int,
  column : Int,
  owner? : String = "",
) -> Diagnostic {
  { code, severity, message, line, column, owner }
}

///|
pub fn error_count(diagnostics : Array[Diagnostic]) -> Int {
  let mut result = 0
  for item in diagnostics {
    if item.severity == "error" {
      result += 1
    }
  }
  result
}

///|
pub fn warning_count(diagnostics : Array[Diagnostic]) -> Int {
  let mut result = 0
  for item in diagnostics {
    if item.severity == "warning" {
      result += 1
    }
  }
  result
}
