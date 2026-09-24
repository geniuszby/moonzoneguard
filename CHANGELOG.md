# Changelog

## Unreleased

## 0.2.0 - 2026-09-24

- Add bounded parent/child delegation rollout analysis with four snapshots,
  glue and authoritative address checks, counterexample evidence, and CLI output.
- Gate rollout recommendations on both zones' SOA serial preflight checks.
- Add bounded multi-zone planning with safe-order counts, required precedence,
  viable first steps, and counterexample paths.
- Validate the initial zone origin and `$ORIGIN` directives.
- Reject revision analysis when either zone fails validation.
- Document three reproducible review scenarios and run them in CI.
- Include RFC 1982 serial order explicitly in JSON diff reports.

## 0.1.0 - 2026-09-23

- Initial MoonBit zone-file lexer and parser.
- Record shape and cross-record validation with source locations.
- RFC 1982 SOA serial comparison and zone revision diff.
- CLI, machine-readable and review-friendly reports, examples, and CI.
- Team review policy, inventory, alias tracing, local lookup, canonical output,
  change impact summary, and mail/security checks.
