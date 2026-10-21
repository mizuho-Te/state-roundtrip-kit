# Synthetic iOS validation host

This standalone UIKit app exercises the supplied UI sample without using another app or its data.
It has its own bundle identifier: `local.state-roundtrip.validation.host.20261021`.

Open `RoundtripValidation.xcodeproj`, select the `RoundtripValidation` scheme and an already installed iOS simulator, and run the tests. The generated project is included, so XcodeGen is not required to use it. `project.yml` is its reproducible source (generated with existing XcodeGen 2.44.1).

The test target includes the package's `../Examples/RoundtripUITests.swift` directly. Four extra controls reject malformed fixture IDs, reject incomplete input, invalidate stale save acknowledgments and verify a new save generation, and confirm an unsaved edit does not survive relaunch.

All storage and fixture argument handling are inside `#if DEBUG`. The host validates `state-roundtrip-<lowercase UUID>` before choosing:

`Application Support/StateRoundtripValidation/<fixture ID>/card.json`

It loads existing data for that ID, writes atomically on Save, and shows a save acknowledgment only after successful write. Editing clears the acknowledgment. There is no normal store, account, network, or synchronization implementation. Release builds display a disabled screen.

The test app is intentionally not uninstalled or reset; synthetic stores remain available for review. Only the new app and test runner are installed during testing. No other bundle is launched or modified.

From the package root, these commands build and run on an explicit existing device:

```sh
# Replace DEVICE_UDID with the chosen existing simulator's identifier.
xcodebuild -project ValidationHost/RoundtripValidation.xcodeproj \
  -scheme RoundtripValidation -configuration Debug \
  -destination 'platform=iOS Simulator,id=DEVICE_UDID' \
  -derivedDataPath /tmp/state-roundtrip-build \
  -disableAutomaticPackageResolution -skipPackageUpdates \
  build-for-testing CODE_SIGNING_ALLOWED=NO
xcodebuild -project ValidationHost/RoundtripValidation.xcodeproj \
  -scheme RoundtripValidation -configuration Debug \
  -destination 'platform=iOS Simulator,id=DEVICE_UDID' \
  -derivedDataPath /tmp/state-roundtrip-build \
  -resultBundlePath /tmp/state-roundtrip-ui.xcresult \
  -parallel-testing-enabled NO \
  -disableAutomaticPackageResolution -skipPackageUpdates \
  test-without-building CODE_SIGNING_ALLOWED=NO
```

Use fresh result-bundle paths on repeat runs. The validation UI-test target uses iOS 17 as its minimum to match the test frameworks supplied with Xcode 27; the library and host retain iOS 15. Running on an installed iOS 27 simulator does not validate iOS 15 or 17 runtime compatibility. See the validation report for actual execution results and limitations.
