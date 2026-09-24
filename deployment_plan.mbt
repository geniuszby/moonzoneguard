///|
/// One zone's proposed atomic transition. The origin must match both parsed
/// zone documents. At most six revisions can be checked in one plan.
pub(all) struct ZoneRevision {
  origin : String
  before : Zone
  after : Zone
} derive(Debug)

///|
pub(all) struct DeploymentSnapshot {
  mask : Int
  blocked : Bool
  findings : Array[DelegationFinding]
} derive(Debug)

///|
/// One attempted publication step from a reachable state into a blocked
/// state. `from_mask = -1` means the baseline itself is blocked.
pub(all) struct DeploymentCounterexample {
  from_mask : Int
  to_mask : Int
  changed_zone : String
  safe_prefix : Array[String]
  findings : Array[DelegationFinding]
} derive(Debug)

///|
/// A relation shared by every safe complete publication sequence.
pub(all) struct DeploymentPrecedence {
  before_origin : String
  after_origin : String
} derive(Debug)

///|
/// A safe order is a path through the Boolean state lattice where each
/// step updates exactly one zone and every visited snapshot passes.
pub(all) struct DeploymentPlan {
  status : String
  order : Array[String]
  snapshots : Array[DeploymentSnapshot]
  preflight : Array[DelegationFinding]
  counterexample : DeploymentCounterexample?
  safe_order_count : Int
  required_precedence : Array[DeploymentPrecedence]
  first_steps : Array[String]
  blocked_state_count : Int
} derive(Debug)

///|
fn deployment_preflight(
  revisions : Array[ZoneRevision],
) -> Array[DelegationFinding] {
  let findings : Array[DelegationFinding] = []
  if revisions.length() < 2 || revisions.length() > 6 {
    delegation_finding(
      findings, "M001", "error", "manifest", "", 0, "deployment plan requires 2 to 6 zones",
    )
    return findings
  }
  let seen : Map[String, Bool] = Map([])
  for revision in revisions {
    if seen.get(revision.origin) is Some(_) {
      delegation_finding(
        findings,
        "M002",
        "error",
        revision.origin,
        revision.origin,
        0,
        "zone origin occurs more than once in deployment plan",
      )
    }
    seen.set(revision.origin, true)
    if revision.before.origin != revision.origin ||
      revision.after.origin != revision.origin {
      delegation_finding(
        findings,
        "M003",
        "error",
        revision.origin,
        revision.origin,
        0,
        "declared origin differs from one of its parsed zone snapshots",
      )
    }
    let diff = compare_zones(revision.before, revision.after)
    for item in diff.diagnostics {
      delegation_finding(
        findings,
        item.code,
        item.severity,
        revision.origin + "-after",
        item.owner,
        item.line,
        item.message,
      )
    }
  }
  findings
}

///|
/// For each zone, choose the closest supplied ancestor. An ancestor can
/// serve several children; a child has at most one parent in this model.
fn nearest_supplied_parents(revisions : Array[ZoneRevision]) -> Array[Int] {
  let parents : Array[Int] = []
  for child_index in 0..<revisions.length() {
    let mut parent_index = -1
    let mut parent_length = -1
    for candidate in 0..<revisions.length() {
      if candidate != child_index &&
        revisions[child_index].origin != revisions[candidate].origin &&
        is_within_zone(
          revisions[child_index].origin,
          revisions[candidate].origin,
        ) &&
        revisions[candidate].origin.length() > parent_length {
        parent_index = candidate
        parent_length = revisions[candidate].origin.length()
      }
    }
    parents.push(parent_index)
  }
  parents
}

///|
fn deployment_weights(count : Int) -> Array[Int] {
  let weights : Array[Int] = []
  let mut weight = 1
  for _ in 0..<count {
    weights.push(weight)
    weight *= 2
  }
  weights
}

///|
fn deployment_updated(mask : Int, weight : Int) -> Bool {
  mask / weight % 2 == 1
}

///|
fn deployment_zone(revision : ZoneRevision, updated : Bool) -> Zone {
  if updated {
    revision.after
  } else {
    revision.before
  }
}

///|
fn deployment_source(origin : String, updated : Bool) -> String {
  origin + (if updated { "-after" } else { "-before" })
}

///|
fn inspect_deployment_snapshot(
  mask : Int,
  revisions : Array[ZoneRevision],
  parents : Array[Int],
  weights : Array[Int],
) -> DeploymentSnapshot {
  let findings : Array[DelegationFinding] = []
  for i in 0..<revisions.length() {
    let updated = deployment_updated(mask, weights[i])
    append_zone_findings(
      findings,
      deployment_zone(revisions[i], updated),
      deployment_source(revisions[i].origin, updated),
    )
  }
  for child_index in 0..<revisions.length() {
    let parent_index = parents[child_index]
    if parent_index < 0 {
      continue
    }
    let parent_updated = deployment_updated(mask, weights[parent_index])
    let child_updated = deployment_updated(mask, weights[child_index])
    let cross = audit_delegation_pair(
      deployment_zone(revisions[parent_index], parent_updated),
      deployment_zone(revisions[child_index], child_updated),
      deployment_source(revisions[parent_index].origin, parent_updated),
      deployment_source(revisions[child_index].origin, child_updated),
      false,
    )
    for item in cross {
      findings.push(item)
    }
  }
  let mut blocked = false
  for item in findings {
    if item.severity == "error" {
      blocked = true
    }
  }
  { mask, blocked, findings, }
}

///|
fn deployment_has_error(findings : Array[DelegationFinding]) -> Bool {
  for item in findings {
    if item.severity == "error" {
      return true
    }
  }
  false
}

///|
fn deployment_blocked_count(snapshots : Array[DeploymentSnapshot]) -> Int {
  let mut count = 0
  for snapshot in snapshots {
    if snapshot.blocked {
      count += 1
    }
  }
  count
}

///|
fn deployment_reconstruct_order(
  last_mask : Int,
  predecessors : Array[Int],
  weights : Array[Int],
  revisions : Array[ZoneRevision],
) -> Array[String] {
  let reversed : Array[String] = []
  let mut cursor = last_mask
  while cursor > 0 {
    let previous = predecessors[cursor]
    let changed_bit = cursor - previous
    for i in 0..<weights.length() {
      if weights[i] == changed_bit {
        reversed.push(revisions[i].origin)
      }
    }
    cursor = previous
  }
  let order : Array[String] = []
  for i in 0..<reversed.length() {
    order.push(reversed[reversed.length() - 1 - i])
  }
  order
}

///|
fn deployment_bit_count(mask : Int, weights : Array[Int]) -> Int {
  let mut count = 0
  for weight in weights {
    if deployment_updated(mask, weight) {
      count += 1
    }
  }
  count
}

///|
fn deployment_counterexample(
  revisions : Array[ZoneRevision],
  weights : Array[Int],
  snapshots : Array[DeploymentSnapshot],
  predecessors : Array[Int],
) -> DeploymentCounterexample? {
  if snapshots[0].blocked {
    return Some({
      from_mask: -1,
      to_mask: 0,
      changed_zone: "",
      safe_prefix: [],
      findings: snapshots[0].findings,
    })
  }
  let mut best_depth = -1
  let mut best_from = -1
  let mut best_to = -1
  let mut best_zone = ""
  for mask in 0..<snapshots.length() {
    if predecessors[mask] < 0 || snapshots[mask].blocked {
      continue
    }
    let depth = deployment_bit_count(mask, weights)
    for i in 0..<weights.length() {
      if deployment_updated(mask, weights[i]) {
        continue
      }
      let next = mask + weights[i]
      if snapshots[next].blocked && depth > best_depth {
        best_depth = depth
        best_from = mask
        best_to = next
        best_zone = revisions[i].origin
      }
    }
  }
  if best_to < 0 {
    None
  } else {
    Some({
      from_mask: best_from,
      to_mask: best_to,
      changed_zone: best_zone,
      safe_prefix: deployment_reconstruct_order(
        best_from, predecessors, weights, revisions,
      ),
      findings: snapshots[best_to].findings,
    })
  }
}

///|
/// First publications that still permit at least one complete safe path.
fn deployment_first_steps(
  revisions : Array[ZoneRevision],
  weights : Array[Int],
  completions : Array[Int],
) -> Array[String] {
  let first : Array[String] = []
  if completions[0] == 0 {
    return first
  }
  for i in 0..<revisions.length() {
    if completions[weights[i]] > 0 {
      first.push(revisions[i].origin)
    }
  }
  first
}

///|
/// Dynamic programming over the state lattice counts complete safe orders.
/// With six zones the maximum is 6! = 720, within Int range.
fn deployment_completion_counts(
  snapshots : Array[DeploymentSnapshot],
  weights : Array[Int],
) -> Array[Int] {
  let total = snapshots.length()
  let counts : Array[Int] = []
  for _ in 0..<total {
    counts.push(0)
  }
  if snapshots[total - 1].blocked {
    return counts
  }
  counts[total - 1] = 1
  for offset in 1..<total {
    let mask = total - 1 - offset
    if snapshots[mask].blocked {
      continue
    }
    for weight in weights {
      if !deployment_updated(mask, weight) {
        counts[mask] += counts[mask + weight]
      }
    }
  }
  counts
}

///|
/// An A-before-B relation is required when no complete safe path contains
/// a reachable snapshot with B published while A remains unpublished.
fn deployment_required_precedence(
  revisions : Array[ZoneRevision],
  weights : Array[Int],
  predecessors : Array[Int],
  completions : Array[Int],
) -> Array[DeploymentPrecedence] {
  let constraints : Array[DeploymentPrecedence] = []
  if completions[0] == 0 {
    return constraints
  }
  for a in 0..<revisions.length() {
    for b in 0..<revisions.length() {
      if a == b {
        continue
      }
      let mut b_can_precede_a = false
      for mask in 0..<completions.length() {
        if predecessors[mask] >= 0 &&
          completions[mask] > 0 &&
          deployment_updated(mask, weights[b]) &&
          !deployment_updated(mask, weights[a]) {
          b_can_precede_a = true
          break
        }
      }
      if !b_can_precede_a {
        constraints.push({
          before_origin: revisions[a].origin,
          after_origin: revisions[b].origin,
        })
      }
    }
  }
  constraints
}

///|
/// Enumerate at most 64 before/after combinations, then search for a path
/// from all-before to all-after where one zone changes at each step.
pub fn plan_delegation_rollout(
  revisions : Array[ZoneRevision],
) -> DeploymentPlan {
  let preflight = deployment_preflight(revisions)
  if revisions.length() < 2 || revisions.length() > 6 {
    return {
      status: "invalid-input",
      order: [],
      snapshots: [],
      preflight,
      counterexample: None,
      safe_order_count: 0,
      required_precedence: [],
      first_steps: [],
      blocked_state_count: 0,
    }
  }
  let parents = nearest_supplied_parents(revisions)
  let mut edges = 0
  for parent in parents {
    if parent >= 0 {
      edges += 1
    }
  }
  if edges == 0 {
    delegation_finding(
      preflight, "M004", "error", "manifest", "", 0, "no parent-child relationship among supplied zone origins",
    )
  }
  let weights = deployment_weights(revisions.length())
  let total = weights[weights.length() - 1] * 2
  let snapshots : Array[DeploymentSnapshot] = []
  for mask in 0..<total {
    snapshots.push(
      inspect_deployment_snapshot(mask, revisions, parents, weights),
    )
  }
  if deployment_has_error(preflight) {
    return {
      status: "invalid-input",
      order: [],
      snapshots,
      preflight,
      counterexample: None,
      safe_order_count: 0,
      required_precedence: [],
      first_steps: [],
      blocked_state_count: deployment_blocked_count(snapshots),
    }
  }
  let predecessors : Array[Int] = []
  for _ in 0..<total {
    predecessors.push(-1)
  }
  if !snapshots[0].blocked {
    predecessors[0] = 0
  }
  for mask in 0..<total {
    if predecessors[mask] < 0 || snapshots[mask].blocked {
      continue
    }
    for i in 0..<revisions.length() {
      if deployment_updated(mask, weights[i]) {
        continue
      }
      let next = mask + weights[i]
      if !snapshots[next].blocked && predecessors[next] < 0 {
        predecessors[next] = mask
      }
    }
  }
  let final_mask = total - 1
  let completions = deployment_completion_counts(snapshots, weights)
  if predecessors[final_mask] < 0 {
    {
      status: "no-safe-order",
      order: [],
      snapshots,
      preflight,
      counterexample: deployment_counterexample(
        revisions, weights, snapshots, predecessors,
      ),
      safe_order_count: 0,
      required_precedence: [],
      first_steps: [],
      blocked_state_count: deployment_blocked_count(snapshots),
    }
  } else {
    {
      status: "safe-order",
      order: deployment_reconstruct_order(
        final_mask, predecessors, weights, revisions,
      ),
      snapshots,
      preflight,
      counterexample: None,
      safe_order_count: completions[0],
      required_precedence: deployment_required_precedence(
        revisions, weights, predecessors, completions,
      ),
      first_steps: deployment_first_steps(revisions, weights, completions),
      blocked_state_count: deployment_blocked_count(snapshots),
    }
  }
}

///|
fn write_deployment_finding_json(
  out : StringBuilder,
  item : DelegationFinding,
) -> Unit {
  out.write_char('{')
  write_json_field(out, "code", item.code, false)
  write_json_field(out, "severity", item.severity, true)
  write_json_field(out, "source", item.source, true)
  write_json_field(out, "owner", item.owner, true)
  write_json_number(out, "line", item.line, true)
  write_json_field(out, "message", item.message, true)
  out.write_char('}')
}

///|
pub fn render_deployment_plan_json(plan : DeploymentPlan) -> String {
  let out = StringBuilder()
  out.write_char('{')
  write_json_field(out, "status", plan.status, false)
  write_json_number(out, "safe_order_count", plan.safe_order_count, true)
  write_json_number(out, "blocked_state_count", plan.blocked_state_count, true)
  write_json_number(out, "examined_state_count", plan.snapshots.length(), true)
  write_json_number(
    out,
    "passing_state_count",
    plan.snapshots.length() - plan.blocked_state_count,
    true,
  )
  out.write_string(",\"first_steps\":[")
  for i in 0..<plan.first_steps.length() {
    if i > 0 {
      out.write_char(',')
    }
    out.write_string(json_escaped(plan.first_steps[i]))
  }
  out.write_char(']')
  out.write_string(",\"order\":[")
  for i in 0..<plan.order.length() {
    if i > 0 {
      out.write_char(',')
    }
    out.write_string(json_escaped(plan.order[i]))
  }
  out.write_string("],\"required_precedence\":[")
  for i in 0..<plan.required_precedence.length() {
    if i > 0 {
      out.write_char(',')
    }
    let constraint = plan.required_precedence[i]
    out.write_char('{')
    write_json_field(out, "before", constraint.before_origin, false)
    write_json_field(out, "after", constraint.after_origin, true)
    out.write_char('}')
  }
  out.write_string("],\"preflight\":[")
  for i in 0..<plan.preflight.length() {
    if i > 0 {
      out.write_char(',')
    }
    write_deployment_finding_json(out, plan.preflight[i])
  }
  out.write_string("],\"snapshots\":[")
  for i in 0..<plan.snapshots.length() {
    if i > 0 {
      out.write_char(',')
    }
    let snapshot = plan.snapshots[i]
    out.write_string("{\"mask\":")
    out.write_string(snapshot.mask.to_string())
    out.write_string(",\"blocked\":")
    out.write_string(if snapshot.blocked { "true" } else { "false" })
    out.write_string(",\"findings\":[")
    for j in 0..<snapshot.findings.length() {
      if j > 0 {
        out.write_char(',')
      }
      write_deployment_finding_json(out, snapshot.findings[j])
    }
    out.write_string("]}")
  }
  out.write_string("],\"counterexample\":")
  match plan.counterexample {
    None => out.write_string("null")
    Some(witness) => {
      out.write_string("{\"from_mask\":")
      out.write_string(witness.from_mask.to_string())
      out.write_string(",\"to_mask\":")
      out.write_string(witness.to_mask.to_string())
      write_json_field(out, "changed_zone", witness.changed_zone, true)
      out.write_string(",\"safe_prefix\":[")
      for i in 0..<witness.safe_prefix.length() {
        if i > 0 {
          out.write_char(',')
        }
        out.write_string(json_escaped(witness.safe_prefix[i]))
      }
      out.write_char(']')
      out.write_string(",\"findings\":[")
      for i in 0..<witness.findings.length() {
        if i > 0 {
          out.write_char(',')
        }
        write_deployment_finding_json(out, witness.findings[i])
      }
      out.write_string("]}")
    }
  }
  out.write_char('}')
  out.to_string()
}

///|
pub fn render_deployment_plan_text(plan : DeploymentPlan) -> String {
  let out = StringBuilder()
  out.write_string("status: ")
  out.write_string(plan.status)
  out.write_char('\n')
  out.write_string("safe orders: ")
  out.write_string(plan.safe_order_count.to_string())
  out.write_char('\n')
  out.write_string("blocked states: ")
  out.write_string(plan.blocked_state_count.to_string())
  out.write_char('\n')
  out.write_string("examined states: ")
  out.write_string(plan.snapshots.length().to_string())
  out.write_char('\n')
  if plan.first_steps.length() > 0 {
    out.write_string("viable first updates:")
    for origin in plan.first_steps {
      out.write_char(' ')
      out.write_string(origin)
    }
    out.write_char('\n')
  }
  if plan.order.length() > 0 {
    out.write_string("order:")
    for origin in plan.order {
      out.write_char(' ')
      out.write_string(origin)
    }
    out.write_char('\n')
  }
  for constraint in plan.required_precedence {
    out.write_string("must precede: ")
    out.write_string(constraint.before_origin)
    out.write_string(" -> ")
    out.write_string(constraint.after_origin)
    out.write_char('\n')
  }
  match plan.counterexample {
    Some(witness) => {
      if witness.safe_prefix.length() > 0 {
        out.write_string("counterexample safe prefix:")
        for origin in witness.safe_prefix {
          out.write_char(' ')
          out.write_string(origin)
        }
        out.write_char('\n')
      }
      out.write_string("counterexample: state ")
      out.write_string(witness.from_mask.to_string())
      out.write_string(" -> state ")
      out.write_string(witness.to_mask.to_string())
      if witness.changed_zone != "" {
        out.write_string(" after publishing ")
        out.write_string(witness.changed_zone)
      }
      out.write_char('\n')
    }
    None => ()
  }
  for item in plan.preflight {
    out.write_string("preflight ")
    out.write_string(item.severity)
    out.write_char(' ')
    out.write_string(item.code)
    out.write_string(" [")
    out.write_string(item.source)
    out.write_string("] ")
    out.write_string(item.message)
    out.write_char('\n')
  }
  for snapshot in plan.snapshots {
    out.write_string("state ")
    out.write_string(snapshot.mask.to_string())
    out.write_string(if snapshot.blocked { ": blocked\n" } else { ": pass\n" })
    if snapshot.blocked {
      for item in snapshot.findings {
        if item.severity == "error" {
          out.write_string("  ")
          out.write_string(item.code)
          out.write_string(" [")
          out.write_string(item.source)
          out.write_char(':')
          out.write_string(item.line.to_string())
          out.write_string("] ")
          out.write_string(item.owner)
          out.write_string(": ")
          out.write_string(item.message)
          out.write_char('\n')
        }
      }
    }
  }
  out.to_string()
}
