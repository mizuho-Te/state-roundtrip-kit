# State Roundtrip Kit

[日本語](README.ja.md)

A small Swift package for the unglamorous question: **did the values we saved survive reopening?**

It provides strict, order-independent snapshot comparison, redacted diagnostics, explicit stage results, and test-owned temporary directories. It does not automate an arbitrary app or replace XCTest, SwiftData/Core Data, migration tests, or backup verification.

## Verification status

2026-10-21: validated independently on macOS 27.0.1 (Apple Silicon), Xcode 27.0 and Swift 6.4. The core builds and all 14 XCTest methods pass. The iOS UI sample and synthetic host compile for the simulator, and all 5 UI tests pass on an existing iPhone 18 Pro / iOS 27.0 simulator. See `VALIDATION.txt` for the separate UI execution result, evidence, fixes and limitations. On 2026-10-21, [GitHub Actions](https://github.com/mizuho-Te/state-roundtrip-kit/actions/runs/39574967581) passed all 14 core XCTest methods on each of Linux / Swift 5.9.2 and macOS / Apple Swift 6.3.3. CI does not execute the five iOS UI tests; those results come from the separate synthetic-host simulator run above. Older OS runtimes and physical devices remain untested. A JSON write/read test alone is not evidence of app-restart persistence.

## Setup

Swift 5.9+; Foundation core intended for Linux/macOS and iOS 15+. These are declared targets, not a verified compatibility matrix.

From this directory:

```sh
swift test
```

For an existing Xcode project, add this directory as a local Swift package, then link `StateRoundtripKit` to the test target. No third-party package dependencies, network access, credentials or telemetry.

```swift
import StateRoundtripKit
let expected = try Snapshot(records: [
    Record(id: "synthetic-card-1", fields: ["question": "2 + 2?", "answer": "4"])
])
let actual = try Snapshot(records: [
    Record(id: "synthetic-card-1", fields: ["question": "2 + 2?", "answer": "5"])
])
let result = SnapshotComparator.compare(expected: expected, actual: actual)
assert(!result.matches)
print(result.summary) // Counts only; no IDs, field names or values.
```

Comparison checks record count, ID sets, field sets and exact string values. Record order does not matter. Duplicate and empty IDs are rejected. Missing and empty fields differ. Do not normalize away meaningful differences; choose explicit canonical date, integer minor-unit and Boolean representations in your adapter. Include ordering as an explicit field if it matters. Snapshots represent exactly what callers supply: omitted records/fields cannot be checked.

`Difference` includes a category and sorted-union ordinals. It intentionally stores no original names or values. There is no unsafe “show all values” switch. Keep your own synthetic fixture mapping locally if deeper diagnosis is needed. `Record` / `Snapshot` themselves do contain input data and are not safe to log. Stage diagnostic codes are caller-controlled; use fixed codes, never raw error text or personal data.

## The eight stages

Prepare → launch → input → save → terminate → relaunch → readBack → compare.

`ScenarioReport.passed` requires every stage exactly once, in order, with `passed` status. It is a reporting model, not an orchestrator: it cannot prove that a caller actually performed a marked stage. Capture failures at the operation where they occur and mark downstream stages skipped; never infer success from missing results.

## Integrating the UI sample

`Examples/RoundtripUITests.swift` is a manually integrated sample, excluded from package tests. Copy it to an existing iOS UI-test target; link the package. Choose a simulator and run that target from Xcode. Change accessibility IDs and field types to match your synthetic test screen. Never point it at a production account.

For a standalone synthetic host, open `ValidationHost/RoundtripValidation.xcodeproj`; see [its instructions](ValidationHost/README.md). It has a dedicated bundle identifier and no normal app store.

Your DEBUG-only app adapter must:

1. Parse `--roundtrip-fixture <unique ID>` before opening storage. Reject malformed IDs. Select a dedicated app-sandbox test store; disable sync/network. Never use the live store as a fallback.
2. Preserve that store across subsequent launches with the same ID. Do NOT reset at every launch, which would invalidate the test.
3. Show `roundtrip.isolated-ready` only after isolation and loading are complete. Add stable accessibility identifiers to input, save, and restored fields.
4. Clear `card.saved` when input changes, and show a new acknowledgment only when the persistence operation succeeds. The sample asserts that no old acknowledgment is present before Save. The synthetic host also changes its save generation value after each successful write. A stale or merely tapped Save button is not proof of commit.
5. Supply a full fixture-store export adapter if asserting all records. The sample only checks one selected field, not database identity or count.
6. Explicitly remove only that test-owned store after review. No general app reset, account deletion, or destructive uninstall is provided.

App and UI-test processes have separate sandboxes. `FixtureDirectory.url` is for files in the current process, NOT a shared app-container path. Pass a fixture ID, not the runner's temp path, into the app. `terminate()` is ordinary termination, not a simulated crash, OS kill, disk-full condition or migration.

The sample waits until the input value matches the synthetic text before recording input as passed. Use a placeholder different from the expected text because an empty text field can expose its placeholder as its accessibility value.

Wait on semantic completion and predicate expectations instead of fixed sleeps. On failure, inspect whether the input control, keyboard, save operation or read-back phase failed before blaming storage. Do not attach real screenshots/databases to public CI.

## Synthetic scenarios

- Ledger: create a fake entry with `amountMinorUnits=1234`, edit to `5678`, save, reopen, compare all fixture records and fields.
- Cards: edit a synthetic question, assert `approved=false`, save, explicitly approve, reopen, verify the approval and review position. Each transition needs its own expected snapshot.
- Negative control: deliberately alter one expected value and confirm the test fails before trusting the harness.

The package's JSON fixture test exercises serialization only. Neither scenario above is claimed as an executed application test.

## Cleanup safety

`FixtureDirectory()` creates a fresh UUID directory under the process temporary directory and a random ownership marker. `cleanup()` is explicit and rejects a replaced root symlink, missing/changed marker, or path outside its original direct parent. It never accepts an arbitrary directory. Prevent concurrent filesystem mutation during use/cleanup: path checks are not a security boundary against a malicious process racing filesystem operations. A failed cleanup leaves evidence rather than deleting an unknown directory.

## References

- [Xcode testing](https://developer.apple.com/documentation/xcode/testing)
- [XCUIApplication](https://developer.apple.com/documentation/xcuiautomation/xcuiapplication)
- [Asynchronous XCTest expectations](https://developer.apple.com/documentation/xctest/asynchronous-tests-and-expectations)

## License / release

MIT License. Copyright (c) 2026 mizuho-Te. See [LICENSE](LICENSE).
