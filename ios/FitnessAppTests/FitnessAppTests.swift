import XCTest
@testable import FitnessApp

final class FitnessAppTests: XCTestCase {
    @MainActor
    func testContentViewInitializes() {
        _ = ContentView()
    }
}
