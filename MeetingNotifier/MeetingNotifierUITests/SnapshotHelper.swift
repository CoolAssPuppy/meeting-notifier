// SnapshotHelper.swift for macOS
// Simplified version for macOS screenshot capture
// Compatible with Fastlane's snapshot tool

import Foundation
import XCTest

var deviceLanguage = ""
var locale = ""

@MainActor
func setupSnapshot(_ app: XCUIApplication, waitForAnimations: Bool = true) {
    Snapshot.setupSnapshot(app, waitForAnimations: waitForAnimations)
}

@MainActor
func snapshot(_ name: String, timeWaitingForIdle: TimeInterval = 20) {
    Snapshot.snapshot(name, timeWaitingForIdle: timeWaitingForIdle)
}

@MainActor
public class Snapshot: NSObject {
    static var app: XCUIApplication?
    static var waitForAnimations = true
    static var cacheDirectory: URL?

    public class func setupSnapshot(_ app: XCUIApplication, waitForAnimations: Bool = true) {
        Snapshot.app = app
        Snapshot.waitForAnimations = waitForAnimations

        // Set up cache directory for screenshots
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        if let cachePath = paths.first {
            cacheDirectory = cachePath.appendingPathComponent("tools.fastlane")
            try? FileManager.default.createDirectory(at: cacheDirectory!, withIntermediateDirectories: true)
        }

        print("📸 Snapshot setup complete")
        print("📂 Screenshots will be saved to: \(cacheDirectory?.path ?? "unknown")")
    }

    public class func snapshot(_ name: String, timeWaitingForIdle: TimeInterval = 20) {
        guard let testApp = app else {
            print("⚠️ Snapshot: app not set up. Call setupSnapshot first.")
            return
        }

        if waitForAnimations {
            sleep(1) // Give animations time to settle
        }

        print("📸 Taking snapshot: \(name)")

        // Try to find and capture the frontmost window
        var screenshot: XCUIScreenshot?

        // First, try to capture any visible window
        if testApp.windows.count > 0 {
            print("   Found \(testApp.windows.count) window(s)")
            // Capture the first visible window
            let window = testApp.windows.firstMatch
            if window.exists {
                screenshot = window.screenshot()
                print("   Captured window screenshot")
            }
        }

        // If no window found, try to capture the whole app
        if screenshot == nil {
            screenshot = testApp.screenshot()
            print("   Captured app screenshot")
        }

        // Fallback to screen capture
        if screenshot == nil {
            screenshot = XCUIScreen.main.screenshot()
            print("   Fallback to screen screenshot")
        }

        // Save to cache directory
        if let cacheDir = cacheDirectory, let screenshot = screenshot {
            let fileName = "\(name).png"
            let fileURL = cacheDir.appendingPathComponent(fileName)

            do {
                try screenshot.pngRepresentation.write(to: fileURL)
                print("✅ Saved screenshot to: \(fileURL.path)")
            } catch {
                print("❌ Failed to save screenshot: \(error)")
            }
        } else {
            print("⚠️ Cache directory not set up or screenshot failed")
        }
    }
}

// Compatibility with older Snapshot versions
@MainActor
@available(*, deprecated, message: "use setupSnapshot(:) instead")
func setLanguage(_ app: XCUIApplication) {
    setupSnapshot(app)
}

@MainActor
@available(*, deprecated, message: "use snapshot(:) instead")
func takeSnapshot(_ name: String) {
    snapshot(name)
}
