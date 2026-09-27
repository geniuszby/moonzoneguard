# Third-party notices

The MoonBit standard library and `moonbitlang/x` are used through their package APIs. No third-party source files or media assets are copied into this repository. `moonbitlang/x` is distributed under Apache-2.0; see its [upstream repository](https://github.com/moonbitlang/x) for the current license text and notices.

RFC 1035, RFC 1982, and RFC 2181 are technical specifications consulted for behavior; their text is not incorporated into the source code.

`gmlewis/sha256@0.17.32` is used through its API for DS digest type 2. Its declared license is Apache-2.0; it is based on Go's SHA-256 implementation and retains Go Authors' BSD notices in its source. See [upstream](https://github.com/gmlewis/moonbit-sha256). Its transitive dependency `gmlewis/base64@0.16.11` is also Apache-2.0 ([upstream](https://github.com/gmlewis/moonbit-base64)). Dependency source and license notices remain in their distributed packages; they are not copied into this repository or counted as project code.

DNSSEC wire encoding and digest association follow RFC 4034 and RFC 4509. Test fixtures use published public key/DS vectors from RFC 4509 and public Ed25519 keys from RFC 8032; no private keys are included. They are identified as standards test vectors, not original project data.
