# Changelog

## Unreleased

## 0.3.0 - 2026-09-28

- Check SHA-256 DS/DNSKEY associations in every parent-child deployment state.
- Compute RFC 4034 key tags and RFC 4509 digests with a licensed SHA-256 package.
- Block unsupported/unmatched digest paths and conservative DS-removal downgrades.
- Add standards vectors, key rollover fixtures, and successful/failing CI examples.
- Include input zone order and updated zone names in deployment JSON snapshots,
  so CI consumers can interpret state masks without retaining the manifest.

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
