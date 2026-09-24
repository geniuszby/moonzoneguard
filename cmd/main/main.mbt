///|
fn usage() -> Unit {
  println("MoonZoneGuard — offline DNS zone review")
  println("Usage:")
  println("  moonzoneguard check <zone-file> <origin> [text|json|markdown]")
  println(
    "  moonzoneguard rollout <parent-before> <parent-after> <child-before> <child-after> <parent-origin> <child-origin> [text|json]",
  )
  println("  moonzoneguard plan <manifest-file> [text|json]")
  println(
    "  moonzoneguard diff <before-file> <after-file> <origin> [text|json]",
  )
  println(
    "  moonzoneguard impact <before-file> <after-file> <origin> [text|json]",
  )
  println("  moonzoneguard stats <zone-file> <origin> [text|json]")
  println("  moonzoneguard trace <zone-file> <origin> <owner>")
  println("  moonzoneguard normalize <zone-file> <origin>")
  println(
    "  moonzoneguard lookup <zone-file> <origin> <name> <type> [text|json]",
  )
  println(
    "  moonzoneguard policy <zone-file> <origin> <policy-file> [text|json|markdown]",
  )
}

///|
fn load(path : String) -> String? {
  Some(@fs.read_file_to_string(path)) catch {
    _ => {
      println("Cannot read \{path}")
      @sys.exit(2)
      None
    }
  }
}

///|
/// Manifest rows contain: origin before-file after-file. Paths are relative
/// to the process working directory, as with the other CLI commands.
fn load_plan_manifest(input : String) -> Array[@lib.ZoneRevision]? {
  let revisions : Array[@lib.ZoneRevision] = []
  let lines = input.split("\n").collect()
  for index in 0..<lines.length() {
    let line = lines[index].to_owned().trim().to_owned()
    if line == "" || line.to_array()[0] == '#' {
      continue
    }
    let parts : Array[String] = []
    for item in line.split(" ") {
      let value = item.to_owned()
      if value != "" {
        parts.push(value)
      }
    }
    if parts.length() != 3 {
      println(
        "Manifest line \{index + 1}: expected origin before-file after-file",
      )
      return None
    }
    match (load(parts[1]), load(parts[2])) {
      (Some(before), Some(after)) => {
        let origin = @lib.absolute_name("@", parts[0])
        revisions.push({
          origin,
          before: @lib.parse_zone(before, origin),
          after: @lib.parse_zone(after, origin),
        })
      }
      _ => return None
    }
  }
  Some(revisions)
}

///|
fn main {
  let args = @env.args()
  if args.length() < 3 {
    usage()
    @sys.exit(2)
    return
  }
  match args[2] {
    "plan" => {
      if args.length() < 4 {
        usage()
        @sys.exit(2)
        return
      }
      let format = if args.length() > 4 { args[4] } else { "text" }
      if format != "text" && format != "json" {
        usage()
        @sys.exit(2)
        return
      }
      match load(args[3]) {
        Some(input) =>
          match load_plan_manifest(input) {
            Some(revisions) => {
              let plan = @lib.plan_delegation_rollout(revisions)
              if format == "json" {
                println(@lib.render_deployment_plan_json(plan))
              } else {
                println(@lib.render_deployment_plan_text(plan))
              }
              if plan.status != "safe-order" {
                @sys.exit(1)
              }
            }
            None => @sys.exit(2)
          }
        None => ()
      }
    }
    "rollout" => {
      if args.length() < 9 {
        usage()
        @sys.exit(2)
        return
      }
      let format = if args.length() > 9 { args[9] } else { "text" }
      if format != "text" && format != "json" {
        usage()
        @sys.exit(2)
        return
      }
      match (load(args[3]), load(args[4]), load(args[5]), load(args[6])) {
        (
          Some(parent_before),
          Some(parent_after),
          Some(child_before),
          Some(child_after),
        ) => {
          let result = @lib.analyze_delegation_rollout(
            @lib.parse_zone(parent_before, args[7]),
            @lib.parse_zone(parent_after, args[7]),
            @lib.parse_zone(child_before, args[8]),
            @lib.parse_zone(child_after, args[8]),
          )
          if format == "json" {
            println(@lib.render_delegation_rollout_json(result))
          } else {
            println(@lib.render_delegation_rollout_text(result))
          }
          if result.recommendation == "no-safe-order" {
            @sys.exit(1)
          }
        }
        _ => ()
      }
    }
    "check" => {
      if args.length() < 5 {
        usage()
        @sys.exit(2)
        return
      }
      match load(args[3]) {
        None => return
        Some(source) => {
          let findings = @lib.inspect_zone(source, args[4])
          let format = if args.length() > 5 { args[5] } else { "text" }
          match format {
            "json" => println(@lib.render_diagnostics_json(findings))
            "markdown" => println(@lib.render_diagnostics_markdown(findings))
            "text" => println(@lib.render_diagnostics_text(findings))
            _ => {
              usage()
              @sys.exit(2)
            }
          }
          if @lib.error_count(findings) > 0 {
            @sys.exit(1)
          }
        }
      }
    }
    "diff" | "impact" => {
      if args.length() < 6 {
        usage()
        @sys.exit(2)
        return
      }
      match (load(args[3]), load(args[4])) {
        (Some(before), Some(after)) => {
          let format = if args.length() > 6 { args[6] } else { "text" }
          if format != "text" && format != "json" {
            usage()
            @sys.exit(2)
            return
          }
          let before_zone = @lib.parse_zone(before, args[5])
          let after_zone = @lib.parse_zone(after, args[5])
          let before_findings = @lib.validate_zone(before_zone)
          let after_findings = @lib.validate_zone(after_zone)
          if @lib.error_count(before_findings) > 0 ||
            @lib.error_count(after_findings) > 0 {
            if format == "json" {
              println(
                "{\"before\":\{@lib.render_diagnostics_json(before_findings)},\"after\":\{@lib.render_diagnostics_json(after_findings)}}",
              )
            } else {
              println(
                "Before zone:\n\{@lib.render_diagnostics_text(before_findings)}",
              )
              println(
                "After zone:\n\{@lib.render_diagnostics_text(after_findings)}",
              )
            }
            @sys.exit(1)
            return
          }
          let diff = @lib.compare_zones(before_zone, after_zone)
          if args[2] == "impact" {
            let impact = @lib.assess_impact(diff, args[5])
            if format == "json" {
              println(@lib.render_impact_json(impact))
            } else if format == "text" {
              println(@lib.render_impact_text(impact))
            } else {
              usage()
              @sys.exit(2)
            }
          } else if format == "json" {
            println(@lib.render_diff_json(diff))
          } else if format == "text" {
            println(@lib.render_diff_text(diff))
          } else {
            usage()
            @sys.exit(2)
          }
          if @lib.error_count(diff.diagnostics) > 0 {
            @sys.exit(1)
          }
        }
        _ => ()
      }
    }
    "stats" => {
      if args.length() < 5 {
        usage()
        @sys.exit(2)
        return
      }
      match load(args[3]) {
        None => return
        Some(source) => {
          let zone = @lib.parse_zone(source, args[4])
          let findings = @lib.validate_zone(zone)
          let inventory = @lib.inventory_zone(zone)
          let format = if args.length() > 5 { args[5] } else { "text" }
          if format == "json" {
            println(@lib.render_inventory_json(inventory))
          } else if format == "text" {
            println(@lib.render_inventory_text(inventory))
            println("errors: \{@lib.error_count(findings)}")
            println("warnings: \{@lib.warning_count(findings)}")
          } else {
            usage()
            @sys.exit(2)
          }
          if @lib.error_count(findings) > 0 {
            @sys.exit(1)
          }
        }
      }
    }
    "trace" => {
      if args.length() < 6 {
        usage()
        @sys.exit(2)
        return
      }
      match load(args[3]) {
        Some(source) => {
          let trace = @lib.trace_alias(
            @lib.parse_zone(source, args[4]),
            args[5],
          )
          for name in trace.path {
            println(name)
          }
          if trace.cycle {
            println("cycle returns to \{trace.terminal}")
            @sys.exit(1)
          }
        }
        None => ()
      }
    }
    "normalize" => {
      if args.length() < 5 {
        usage()
        @sys.exit(2)
        return
      }
      match load(args[3]) {
        Some(source) => {
          let zone = @lib.parse_zone(source, args[4])
          if @lib.error_count(zone.diagnostics) > 0 {
            println(@lib.render_diagnostics_text(zone.diagnostics))
            @sys.exit(1)
          }
          println(@lib.render_canonical_zone(zone))
        }
        None => ()
      }
    }
    "lookup" => {
      if args.length() < 7 {
        usage()
        @sys.exit(2)
        return
      }
      match load(args[3]) {
        Some(source) => {
          let result = @lib.lookup_zone(
            @lib.parse_zone(source, args[4]),
            args[5],
            args[6],
          )
          let format = if args.length() > 7 { args[7] } else { "text" }
          if format == "json" {
            println(@lib.render_lookup_json(result))
          } else if format == "text" {
            println(@lib.render_lookup_text(result))
          } else {
            usage()
            @sys.exit(2)
          }
          if result.status == "alias-cycle" || result.status == "invalid-name" {
            @sys.exit(1)
          }
        }
        None => ()
      }
    }
    "policy" => {
      if args.length() < 6 {
        usage()
        @sys.exit(2)
        return
      }
      match (load(args[3]), load(args[5])) {
        (Some(source), Some(config)) => {
          let parsed = @lib.parse_policy(config)
          let findings = @lib.validate_with_policy(
            @lib.parse_zone(source, args[4]),
            parsed.policy,
          )
          for item in parsed.diagnostics {
            findings.push(item)
          }
          let format = if args.length() > 6 { args[6] } else { "text" }
          match format {
            "json" => println(@lib.render_diagnostics_json(findings))
            "markdown" => println(@lib.render_diagnostics_markdown(findings))
            "text" => println(@lib.render_diagnostics_text(findings))
            _ => {
              usage()
              @sys.exit(2)
            }
          }
          if @lib.error_count(findings) > 0 {
            @sys.exit(1)
          }
        }
        _ => ()
      }
    }
    _ => {
      usage()
      @sys.exit(2)
    }
  }
}
