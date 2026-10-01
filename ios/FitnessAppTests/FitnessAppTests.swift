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

    func testWorkoutTemplateFormPayloadBuildsSlotPrescription() {
        let exerciseID = UUID()
        var form = WorkoutTemplateFormState()
        form.name = "Upper Body"
        form.notes = "  "
        form.slots = [
            WorkoutTemplateSlotFormState(defaultExerciseID: exerciseID)
        ]
        form.slots[0].label = "Upper Chest Press"
        form.slots[0].restSeconds = "180"
        form.slots[0].startingLoadValue = "60"
        form.slots[0].nextLoadValue = "65"
        form.slots[0].progressionIncrement = "5"
        form.slots[0].setType = .warmup
        form.slots[0].repMin = "4"
        form.slots[0].repMax = "6"
        form.slots[0].loadStrategy = .percentageOfWorkingLoad
        form.slots[0].loadValue = "65"

        let payload = form.payload(lockVersion: 2)

        XCTAssertEqual(payload.name, "Upper Body")
        XCTAssertNil(payload.notes)
        XCTAssertEqual(payload.lockVersion, 2)
        XCTAssertEqual(payload.slots.count, 1)
        XCTAssertEqual(payload.slots[0].label, "Upper Chest Press")
        XCTAssertEqual(payload.slots[0].defaultExerciseID, exerciseID)
        XCTAssertEqual(payload.slots[0].exerciseOptions[0].startingLoadValue, 60)
        XCTAssertEqual(payload.slots[0].exerciseOptions[0].nextLoadValue, 65)
        XCTAssertEqual(payload.slots[0].exerciseOptions[0].progressionIncrement, 5)
        XCTAssertEqual(payload.slots[0].setPrescriptions[0].setType, .warmup)
        XCTAssertEqual(payload.slots[0].setPrescriptions[0].loadValue, 65)
    }
}
