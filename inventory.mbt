///|
pub(all) struct TypeCount {
  record_type : String
  count : Int
} derive(Eq, Debug)

///|
pub(all) struct ZoneInventory {
  origin : String
  record_count : Int
  owner_count : Int
  address_count : Int
  alias_count : Int
  min_ttl : Int?
  max_ttl : Int?
  type_counts : Array[TypeCount]
} derive(Debug)

///|
fn count_type(type_counts : Array[TypeCount], kind : String) -> Unit {
  for index in 0..<type_counts.length() {
    if type_counts[index].record_type == kind {
      type_counts[index] = {
        record_type: kind,
        count: type_counts[index].count + 1,
      }
      return
    }
  }
  type_counts.push({ record_type: kind, count: 1, })
}

///|
/// Summarize a parsed zone without any network lookup.
pub fn inventory_zone(zone : Zone) -> ZoneInventory {
  let owners : Map[String, Bool] = Map([])
  let type_counts : Array[TypeCount] = []
  let mut address_count = 0
  let mut alias_count = 0
  let mut min_ttl : Int? = None
  let mut max_ttl : Int? = None
  for record in zone.records {
    owners.set(record.owner, true)
    count_type(type_counts, record.record_type)
    if record.record_type == "A" || record.record_type == "AAAA" {
      address_count += 1
    }
    if record.record_type == "CNAME" {
      alias_count += 1
    }
    match min_ttl {
      Some(previous) => if record.ttl < previous { min_ttl = Some(record.ttl) }
      None => min_ttl = Some(record.ttl)
    }
    match max_ttl {
      Some(previous) => if record.ttl > previous { max_ttl = Some(record.ttl) }
      None => max_ttl = Some(record.ttl)
    }
  }
  {
    origin: zone.origin,
    record_count: zone.records.length(),
    owner_count: owners.length(),
    address_count,
    alias_count,
    min_ttl,
    max_ttl,
    type_counts,
  }
}

///|
fn optional_int_text(value : Int?) -> String {
  match value {
    Some(number) => number.to_string()
    None => "none"
  }
}

///|
pub fn render_inventory_text(inventory : ZoneInventory) -> String {
  let out = StringBuilder()
  out.write_string("origin: \{inventory.origin}\n")
  out.write_string("records: \{inventory.record_count}\n")
  out.write_string("owners: \{inventory.owner_count}\n")
  out.write_string("addresses: \{inventory.address_count}\n")
  out.write_string("aliases: \{inventory.alias_count}\n")
  out.write_string(
    "ttl range: \{optional_int_text(inventory.min_ttl)}..\{optional_int_text(inventory.max_ttl)}\n",
  )
  out.write_string("types:\n")
  for item in inventory.type_counts {
    out.write_string("  \{item.record_type}: \{item.count}\n")
  }
  out.to_string()
}

///|
pub fn render_inventory_json(inventory : ZoneInventory) -> String {
  let out = StringBuilder()
  out.write_string("{\"origin\":")
  out.write_string(json_escaped(inventory.origin))
  out.write_string(",\"records\":\{inventory.record_count}")
  out.write_string(",\"owners\":\{inventory.owner_count}")
  out.write_string(",\"addresses\":\{inventory.address_count}")
  out.write_string(",\"aliases\":\{inventory.alias_count}")
  out.write_string(",\"min_ttl\":")
  match inventory.min_ttl {
    Some(n) => out.write_string(n.to_string())
    None => out.write_string("null")
  }
  out.write_string(",\"max_ttl\":")
  match inventory.max_ttl {
    Some(n) => out.write_string(n.to_string())
    None => out.write_string("null")
  }
  out.write_string(",\"types\":[")
  for i in 0..<inventory.type_counts.length() {
    if i > 0 {
      out.write_char(',')
    }
    let item = inventory.type_counts[i]
    out.write_string("{\"type\":")
    out.write_string(json_escaped(item.record_type))
    out.write_string(",\"count\":\{item.count}}")
  }
  out.write_string("]}")
  out.to_string()
}

///|
/// Get all exact owner/type matches in source order. `*` means every type.
pub fn find_records(
  zone : Zone,
  owner : String,
  record_type : String,
) -> Array[ResourceRecord] {
  let result : Array[ResourceRecord] = []
  let name = absolute_name(owner, zone.origin)
  let kind = upper(record_type)
  for record in zone.records {
    if record.owner == name && (kind == "*" || record.record_type == kind) {
      result.push(record)
    }
  }
  result
}

///|
pub(all) struct AliasTrace {
  path : Array[String]
  terminal : String
  cycle : Bool
} derive(Debug)

///|
/// Walk in-zone CNAME links. A repeated name ends the trace with `cycle=true`.
pub fn trace_alias(zone : Zone, owner : String) -> AliasTrace {
  let aliases = collect_aliases(zone)
  let visited : Map[String, Bool] = Map([])
  let path : Array[String] = []
  let mut current = absolute_name(owner, zone.origin)
  for _ in 0..<(zone.records.length() + 1) {
    if visited.get(current) is Some(_) {
      return { path, terminal: current, cycle: true, }
    }
    visited.set(current, true)
    path.push(current)
    match aliases.get(current) {
      Some(next) => current = next
      None => return { path, terminal: current, cycle: false, }
    }
  }
  { path, terminal: current, cycle: true, }
}
