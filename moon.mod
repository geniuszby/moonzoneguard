// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "geniuszby/moonzoneguard"

version = "0.3.0"

readme = "README.md"

repository = "https://github.com/geniuszby/moonzoneguard"

license = "Apache-2.0"

keywords = [ "dns", "zone", "delegation", "rollout" ]

preferred_target = "js"

description = "Bounded DNS delegation and DS/DNSKEY digest rollout analysis"

import {
  "moonbitlang/x@0.4.49",
  "gmlewis/sha256@0.17.32",
}
