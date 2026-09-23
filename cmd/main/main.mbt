///|
fn usage() -> Unit {
  println("MoonZoneGuard — offline DNS zone review")
  println("Usage:")
  println("  moonzoneguard check <zone-file> <origin> [text|json|markdown]")
  println(
    "  moonzoneguard diff <before-file> <after-file> <origin> [text|json]",
  )
  println("  moonzoneguard stats <zone-file> <origin>")
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
fn main {
  let args = @env.args()
  if args.length() < 3 {
    usage()
    @sys.exit(2)
    return
  }
  match args[2] {
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
    "diff" => {
      if args.length() < 6 {
        usage()
        @sys.exit(2)
        return
      }
      match (load(args[3]), load(args[4])) {
        (Some(before), Some(after)) => {
          let diff = @lib.compare_zones(
            @lib.parse_zone(before, args[5]),
            @lib.parse_zone(after, args[5]),
          )
          let format = if args.length() > 6 { args[6] } else { "text" }
          if format == "json" {
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
          println("origin: \{zone.origin}")
          println("records: \{zone.records.length()}")
          println("errors: \{@lib.error_count(findings)}")
          println("warnings: \{@lib.warning_count(findings)}")
          if @lib.error_count(findings) > 0 {
            @sys.exit(1)
          }
        }
      }
    }
    _ => {
      usage()
      @sys.exit(2)
    }
  }
}
