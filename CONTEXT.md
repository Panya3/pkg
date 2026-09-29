# pkg

The library hub: the one repository that pins every third-party library this project uses and builds
them into artifacts other projects can pick up, so nobody has to track those libraries down twice.

## Language

**hub**:
This repository in its role as the single place that stores and builds the third-party libraries.
_Avoid_: package manager, SDK, distribution

**vendor/**:
The directory holding third-party sources as submodules, where the superproject decides which commit each one sits at.
_Avoid_: third_party, deps/, external/, subprojects/

**dependency group**:
How libraries are sorted by how well they fit the hub's build — group A arrives through upstream's own CMake, group B only in part, group C has no CMake to use at all.
_Avoid_: tier, layer, level, priority

**member**:
One third-party library admitted into the hub's build, whether it produces files or is header-only.
_Avoid_: package, module, component, dependency

**staged artifact**:
A member's output placed under `bin/` under that member's name instead of being left in the build tree.
_Avoid_: output, dist, install tree

**include root**:
The directory that must be on the include path for a member's headers to be usable — under this hub, `bin/include/<member>/`.
_Avoid_: include dir, header path, public headers

**overlay**:
A header the hub owns, placed ahead of the vendor's header on the include path to extend a member without editing anything in `vendor/`.
_Avoid_: patch, patchset, workaround, shim

**patch set**:
A diff the hub keeps and applies to vendor sources at configure time, for changes an overlay cannot express.
_Avoid_: diff, mod, override, fork

**build environment**:
The machine that actually configures and builds the hub — CI holds that role here, not a developer's machine.
_Avoid_: local machine, devbox, workstation
