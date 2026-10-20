# ARC 3.7 — First-time pairing candidate

Pairing is implemented in the persistent pyatv service and SwiftUI. Select Apple TV → Pair → enter PIN → Confirm PIN → Connect.

**Not tested with a real Apple TV or Xcode here.** The pairing flow may need adjustments after tomorrow’s device test. A paired device may require no PIN or an on-device PIN entry, depending on protocol and firmware. This implementation targets Companion, falling back to MRP.

Run `Build_Standalone_Helper.command` again before building Xcode, because the Python service changed. This requires a working Python/pyatv build environment. Keep ARC 3.6 as backup. Do not publish as stable until fresh pairing, clean-machine packaging, and signing are tested.
