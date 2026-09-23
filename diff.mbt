///|
pub(all) struct ZoneChange {
  kind : String
  owner : String
  record_type : String
  rdata : Array[String]
  before_ttl : Int?
  after_ttl : Int?
  line : Int
} derive(Eq, Debug)

///|
pub(all) struct ZoneDiff {
  changes : Array[ZoneChange]
  diagnostics : Array[Diagnostic]
  serial_order : SerialOrder?
} derive(Debug)

///|
fn record_index(zone : Zone) -> Map[String, Array[ResourceRecord]] {
  let result : Map[String, Array[ResourceRecord]] = Map([])
  for record in zone.records {
    let key = data_key(record)
    match result.get(key) {
      Some(records) => records.push(record)
      None => result.set(key, [record])
    }
  }
  result
}

///|
fn to_change(
  kind : String,
  record : ResourceRecord,
  before_ttl : Int?,
  after_ttl : Int?,
) -> ZoneChange {
  {
    kind,
    owner: record.owner,
    record_type: record.record_type,
    rdata: record.rdata,
    before_ttl,
    after_ttl,
    line: record.line,
  }
}

///|
fn collect_removed(
  before : Zone,
  after_index : Map[String, Array[ResourceRecord]],
  changes : Array[ZoneChange],
) -> Unit {
  let positions : Map[String, Int] = Map([])
  for record in before.records {
    let key = data_key(record)
    let position = match positions.get(key) {
      Some(value) => value
      None => 0
    }
    positions.set(key, position + 1)
    match after_index.get(key) {
      Some(matches) =>
        if position >= matches.length() {
          changes.push(to_change("removed", record, Some(record.ttl), None))
        } else if matches[position].ttl != record.ttl {
          changes.push(
            to_change(
              "ttl-changed",
              record,
              Some(record.ttl),
              Some(matches[position].ttl),
            ),
          )
        }
      None => changes.push(to_change("removed", record, Some(record.ttl), None))
    }
  }
}

///|
fn collect_added(
  after : Zone,
  before_index : Map[String, Array[ResourceRecord]],
  changes : Array[ZoneChange],
) -> Unit {
  let positions : Map[String, Int] = Map([])
  for record in after.records {
    let key = data_key(record)
    let position = match positions.get(key) {
      Some(value) => value
      None => 0
    }
    positions.set(key, position + 1)
    match before_index.get(key) {
      Some(matches) =>
        if position >= matches.length() {
          changes.push(to_change("added", record, None, Some(record.ttl)))
        }
      None => changes.push(to_change("added", record, None, Some(record.ttl)))
    }
  }
}

///|
fn serial_diagnostics(
  before : Zone,
  after : Zone,
  changed : Bool,
) -> (Array[Diagnostic], SerialOrder?) {
  let diagnostics : Array[Diagnostic] = []
  match (apex_serial(before), apex_serial(after)) {
    (Some(old_serial), Some(new_serial)) => {
      let order = compare_serial(old_serial, new_serial)
      match order {
        Same =>
          if changed {
            diagnostics.push(
              diagnostic(
                "D300",
                "error",
                "zone content changed without advancing the SOA serial",
                1,
                1,
                owner=after.origin,
              ),
            )
          }
        Forward => ()
        Backward =>
          diagnostics.push(
            diagnostic(
              "D301",
              "error",
              "SOA serial moves backward under RFC 1982 arithmetic",
              1,
              1,
              owner=after.origin,
            ),
          )
        Undefined =>
          diagnostics.push(
            diagnostic(
              "D302",
              "error",
              "SOA serial delta is undefined under RFC 1982 arithmetic",
              1,
              1,
              owner=after.origin,
            ),
          )
      }
      (diagnostics, Some(order))
    }
    _ => {
      diagnostics.push(
        diagnostic(
          "D303",
          "warning",
          "cannot compare SOA serials",
          1,
          1,
          owner=after.origin,
        ),
      )
      (diagnostics, None)
    }
  }
}

///|
/// Compare two versions of one zone as multisets of resource records.
pub fn compare_zones(before : Zone, after : Zone) -> ZoneDiff {
  let changes : Array[ZoneChange] = []
  let diagnostics : Array[Diagnostic] = []
  if before.origin != after.origin {
    diagnostics.push(diagnostic("D001", "error", "zone origins differ", 1, 1))
    return { changes, diagnostics, serial_order: None }
  }
  collect_removed(before, record_index(after), changes)
  collect_added(after, record_index(before), changes)
  let (serial_notes, serial_order) = serial_diagnostics(
    before,
    after,
    changes.length() > 0,
  )
  for item in serial_notes {
    diagnostics.push(item)
  }
  { changes, diagnostics, serial_order }
}
