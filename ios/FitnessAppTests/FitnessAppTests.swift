import XCTest
@testable import FitnessApp

final class FitnessAppTests: XCTestCase {
    @MainActor
    func testContentViewInitializes() {
        _ = ContentView()
    }

    func testExerciseFormPayloadNormalizesSecondaryMuscleGroups() {
        var form = ExerciseFormState()
        form.name = "Cable Lateral Raise"
        form.primaryMuscleGroup = "Shoulders"
        form.secondaryMuscleGroups = "Traps, , Upper back"
        form.loadType = .machineStack
        form.notes = "  "
        form.externalURL = "https://example.com/cable-lateral-raise"

        let payload = form.payload(lockVersion: 4)

        XCTAssertEqual(payload.name, "Cable Lateral Raise")
        XCTAssertEqual(payload.primaryMuscleGroup, "Shoulders")
        XCTAssertEqual(payload.secondaryMuscleGroups, ["Traps", "Upper back"])
        XCTAssertEqual(payload.loadType, .machineStack)
        XCTAssertNil(payload.notes)
        XCTAssertEqual(payload.externalURL, "https://example.com/cable-lateral-raise")
        XCTAssertEqual(payload.lockVersion, 4)
    }
}
