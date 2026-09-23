///|
pub(all) struct ImpactNote {
  severity : String
  category : String
  message : String
  owner : String
  line : Int
} derive(Eq, Debug)

///|
pub(all) struct ChangeImpact {
  score : Int
  level : String
  changed_owners : Int
  added : Int
  removed : Int
  ttl_changed : Int
  notes : Array[ImpactNote]
} derive(Debug)

///|
fn impact_note(
  notes : Array[ImpactNote],
  severity : String,
  category : String,
  message : String,
  change : ZoneChange,
) -> Unit {
  notes.push({
    severity,
    category,
    message,
    owner: change.owner,
    line: change.line,
  })
}

///|
fn change_type_weight(change : ZoneChange, origin : String) -> Int {
  if change.record_type == "SOA" {
    return 0
  }
  if change.record_type == "NS" && change.owner == origin {
    return 4
  }
  if change.record_type == "MX" && change.owner == origin {
    return 3
  }
  if change.record_type == "CAA" {
    return 3
  }
  if change.record_type == "CNAME" {
    return 2
  }
  if change.record_type == "A" || change.record_type == "AAAA" {
    return 2
  }
  1
}

///|
fn inspect_one_change(
  change : ZoneChange,
  origin : String,
  notes : Array[ImpactNote],
) -> Int {
  if change.kind == "ttl-changed" {
    match (change.before_ttl, change.after_ttl) {
      (Some(before), Some(after)) =>
        if after < before {
          impact_note(
            notes,
            "note",
            "ttl",
            "TTL decreased from \{before} to \{after}; caches may refresh sooner",
            change,
          )
        } else {
          impact_note(
            notes,
            "note",
            "ttl",
            "TTL increased from \{before} to \{after}; rollback may take longer",
            change,
          )
        }
      _ => ()
    }
    return 1
  }
  let weight = change_type_weight(change, origin)
  if change.record_type == "NS" && change.owner == origin {
    impact_note(
      notes, "high", "delegation", "apex nameserver changed; review authoritative service and glue",
      change,
    )
  } else if change.record_type == "MX" {
    impact_note(
      notes, "high", "mail", "mail routing changed; review target and priority",
      change,
    )
  } else if change.record_type == "CAA" {
    impact_note(
      notes, "high", "certificate", "CAA changed; review certificate issuance policy",
      change,
    )
  } else if change.record_type == "CNAME" {
    impact_note(
      notes, "medium", "alias", "alias destination changed; review dependent names",
      change,
    )
  } else if change.record_type == "A" || change.record_type == "AAAA" {
    impact_note(
      notes, "medium", "address", "address record changed; review service endpoint",
      change,
    )
  }
  if change.kind == "removed" {
    impact_note(
      notes, "medium", "removal", "record removed; check consumers and cache lifetime",
      change,
    )
    return weight + 1
  }
  weight
}

///|
/// A transparent review priority score, not a prediction of DNS availability.
/// SOA serial changes alone are ignored in this score.
pub fn assess_impact(diff : ZoneDiff, origin : String) -> ChangeImpact {
  let notes : Array[ImpactNote] = []
  let owners : Map[String, Bool] = Map([])
  let mut score = 0
  let mut added = 0
  let mut removed = 0
  let mut ttl_changed = 0
  for change in diff.changes {
    if change.record_type == "SOA" {
      continue
    }
    owners.set(change.owner, true)
    match change.kind {
      "added" => added += 1
      "removed" => removed += 1
      "ttl-changed" => ttl_changed += 1
      _ => ()
    }
    score += inspect_one_change(change, origin, notes)
  }
  for item in diff.diagnostics {
    if item.severity == "error" {
      score += 4
      notes.push({
        severity: "high",
        category: "serial",
        message: item.message,
        owner: item.owner,
        line: item.line,
      })
    }
  }
  let level = if score >= 8 {
    "high"
  } else if score >= 3 {
    "medium"
  } else {
    "low"
  }
  {
    score,
    level,
    changed_owners: owners.length(),
    added,
    removed,
    ttl_changed,
    notes,
  }
}

///|
pub fn render_impact_text(impact : ChangeImpact) -> String {
  let out = StringBuilder()
  out.write_string("Review priority: \{impact.level} (score \{impact.score})\n")
  out.write_string(
    "Owners: \{impact.changed_owners}, added: \{impact.added}, removed: \{impact.removed}, TTL changed: \{impact.ttl_changed}\n",
  )
  for note in impact.notes {
    out.write_string(
      "[\{note.severity}] \{note.category}: \{note.message} (\{note.owner})\n",
    )
  }
  out.to_string()
}

///|
pub fn render_impact_json(impact : ChangeImpact) -> String {
  let out = StringBuilder()
  out.write_string("{\"level\":")
  out.write_string(json_escaped(impact.level))
  out.write_string(",\"score\":\{impact.score}")
  out.write_string(",\"changed_owners\":\{impact.changed_owners}")
  out.write_string(",\"added\":\{impact.added}")
  out.write_string(",\"removed\":\{impact.removed}")
  out.write_string(",\"ttl_changed\":\{impact.ttl_changed}")
  out.write_string(",\"notes\":[")
  for index in 0..<impact.notes.length() {
    if index > 0 {
      out.write_char(',')
    }
    let note = impact.notes[index]
    out.write_char('{')
    write_json_field(out, "severity", note.severity, false)
    write_json_field(out, "category", note.category, true)
    write_json_field(out, "message", note.message, true)
    write_json_field(out, "owner", note.owner, true)
    write_json_number(out, "line", note.line, true)
    out.write_char('}')
  }
  out.write_string("]}")
  out.to_string()
}
