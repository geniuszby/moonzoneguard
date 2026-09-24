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

version = "0.2.0"

readme = "README.md"

repository = "https://github.com/geniuszby/moonzoneguard"

license = "Apache-2.0"

keywords = [ "dns", "zone", "delegation", "rollout" ]

preferred_target = "js"

description = "Offline DNS delegation rollout analysis across parent and child zones"

import {
  "moonbitlang/x@0.4.49",
}
