#!/bin/sh
# Xcode Cloud runs this before every xcodebuild action; locally it never runs.
#
# Marks the test bundle as running on Xcode Cloud, where StoreKitTest purchases
# hang (see SimulatorStoreKit in TipJarTests). A workflow variable can't reach the
# test process: Xcode Cloud rejects TEST_RUNNER_ names. PlekioTests is a
# synchronized folder, so the file lands in the test bundle as a resource.
set -e
touch "$CI_PRIMARY_REPOSITORY_PATH/PlekioTests/Support/XcodeCloud.marker"
