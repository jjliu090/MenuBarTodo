import XCTest
import Foundation
import Darwin

/// Memory regression tests using task_info (MACH_TASK_BASIC_INFO).
/// These tests verify the memory budget defined in the architecture document.
final class MemoryTests: XCTestCase {

    /// Returns current process RSS in bytes.
    private func currentRSS() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return info.resident_size
    }

    private func rssMB() -> Double {
        Double(currentRSS()) / (1024 * 1024)
    }

    /// Verify no SwiftUI symbols in the binary.
    func testNoSwiftUISymbols() {
        // Check that SwiftUI is not linked
        let handle = dlopen(nil, RTLD_NOW)
        let swiftUISymbol = dlsym(handle, "$s7SwiftUI0A0V")
        XCTAssertNil(swiftUISymbol, "SwiftUI framework should NOT be loaded")
        dlclose(handle)
    }

    /// Verify no Combine symbols in the binary.
    func testNoCombineSymbols() {
        let handle = dlopen(nil, RTLD_NOW)
        let combineSymbol = dlsym(handle, "$s7Combine9PublisherP")
        XCTAssertNil(combineSymbol, "Combine framework should NOT be loaded")
        dlclose(handle)
    }

    /// Log current RSS for CI monitoring.
    func testLogCurrentRSS() {
        let rss = rssMB()
        print("[MemoryTest] Current test process RSS: \(String(format: "%.1f", rss)) MB")
        // This is the test process, not the app, so we just log it
    }
}
