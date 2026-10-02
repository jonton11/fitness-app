import Foundation

struct WorkoutTemplateFormState: Equatable {
    var name: String
    var notes: String
    var slots: [WorkoutTemplateSlotFormState]

    init(template: WorkoutTemplate? = nil) {
        name = template?.name ?? ""
        notes = template?.notes ?? ""
        slots = template?.slots.map(WorkoutTemplateSlotFormState.init(slot:)) ?? []
    }

    func payload(lockVersion: Int?) -> WorkoutTemplatePayload {
        WorkoutTemplatePayload(
            name: name,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            archivedAt: nil,
            lockVersion: lockVersion,
            slots: slots.enumerated().compactMap { index, slot in
                slot.payload(position: index + 1)
            }
        )
    }
}

struct WorkoutTemplateSlotFormState: Identifiable, Equatable {
    var localID = UUID()
    var id: UUID?
    var lockVersion: Int?
    var label: String
    var defaultExerciseID: UUID?
    var restSeconds: String
    var startingLoadValue: String
    var nextLoadValue: String
    var progressionIncrement: String
    var setType: SetType
    var repMin: String
    var repMax: String
    var loadStrategy: LoadStrategy
    var loadValue: String

    init(defaultExerciseID: UUID?) {
        id = nil
        lockVersion = nil
        label = ""
        self.defaultExerciseID = defaultExerciseID
        restSeconds = "180"
        startingLoadValue = ""
        nextLoadValue = ""
        progressionIncrement = ""
        setType = .working
        repMin = "5"
        repMax = "8"
        loadStrategy = .workingLoad
        loadValue = ""
    }

    init(slot: WorkoutTemplateSlot) {
        let defaultOption = slot.exerciseOptions.first { $0.exerciseID == slot.defaultExerciseID }
        let firstPrescription = slot.setPrescriptions.first

        id = slot.id
        lockVersion = slot.lockVersion
        label = slot.label
        defaultExerciseID = slot.defaultExerciseID
        restSeconds = String(slot.restSeconds)
        startingLoadValue = defaultOption?.startingLoadValue.draftString ?? ""
        nextLoadValue = defaultOption?.nextLoadValue.draftString ?? ""
        progressionIncrement = defaultOption?.progressionIncrement.draftString ?? ""
        setType = firstPrescription?.setType ?? .working
        repMin = firstPrescription.map { String($0.repMin) } ?? "5"
        repMax = firstPrescription.map { String($0.repMax) } ?? "8"
        loadStrategy = firstPrescription?.loadStrategy ?? .workingLoad
        loadValue = firstPrescription?.loadValue.draftString ?? ""
    }

    func payload(position: Int) -> WorkoutTemplateSlotPayload? {
        guard let defaultExerciseID else {
            return nil
        }

        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty else {
            return nil
        }

        return WorkoutTemplateSlotPayload(
            id: id,
            position: position,
            label: trimmedLabel,
            defaultExerciseID: defaultExerciseID,
            restSeconds: Int(restSeconds) ?? 0,
            lockVersion: lockVersion,
            exerciseOptions: [
                WorkoutTemplateExerciseOptionPayload(
                    position: 1,
                    exerciseID: defaultExerciseID,
                    startingLoadValue: startingLoadValue.optionalDouble,
                    nextLoadValue: nextLoadValue.optionalDouble,
                    progressionIncrement: progressionIncrement.optionalDouble
                )
            ],
            setPrescriptions: [
                WorkoutTemplateSetPrescriptionPayload(
                    position: 1,
                    setType: setType,
                    repMin: Int(repMin) ?? 0,
                    repMax: Int(repMax) ?? 0,
                    loadStrategy: loadStrategy,
                    loadValue: loadStrategy.requiresValue ? loadValue.optionalDouble : nil
                )
            ]
        )
    }
}

private extension LoadStrategy {
    var requiresValue: Bool {
        self == .percentageOfWorkingLoad || self == .explicit
    }
}

private extension Optional where Wrapped == Double {
    var draftString: String {
        guard let self else {
            return ""
        }

        return String(self)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    var optionalDouble: Double? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : Double(trimmedValue)
    }
}
