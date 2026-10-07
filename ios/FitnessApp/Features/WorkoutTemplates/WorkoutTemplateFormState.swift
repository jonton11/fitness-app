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
    var defaultExerciseID: UUID? {
        didSet {
            guard defaultExerciseID != oldValue else {
                return
            }

            loadProgressionDrafts(for: defaultExerciseID)
        }
    }
    var restSeconds: String
    var startingLoadValue: String
    var nextLoadValue: String
    var progressionIncrement: String
    var setType: SetType
    var repMin: String
    var repMax: String
    var loadStrategy: LoadStrategy
    var loadValue: String
    private var existingExerciseOptions: [WorkoutTemplateExerciseOption]
    private var existingSetPrescriptions: [WorkoutTemplateSetPrescription]

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
        existingExerciseOptions = []
        existingSetPrescriptions = []
    }

    init(slot: WorkoutTemplateSlot) {
        let defaultOption = slot.exerciseOptions.first { $0.exerciseID == slot.defaultExerciseID }
        let firstPrescription = slot.setPrescriptions.sortedByPosition.first

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
        existingExerciseOptions = slot.exerciseOptions
        existingSetPrescriptions = slot.setPrescriptions
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
            exerciseOptions: exerciseOptionPayloads(defaultExerciseID: defaultExerciseID),
            setPrescriptions: setPrescriptionPayloads()
        )
    }

    private func exerciseOptionPayloads(defaultExerciseID: UUID) -> [WorkoutTemplateExerciseOptionPayload] {
        let optionPayloads = existingExerciseOptions.map { option in
            WorkoutTemplateExerciseOptionPayload(
                id: option.id,
                position: option.position,
                exerciseID: option.exerciseID,
                startingLoadValue: option.exerciseID == defaultExerciseID
                    ? startingLoadValue.optionalDouble
                    : option.startingLoadValue,
                nextLoadValue: option.exerciseID == defaultExerciseID
                    ? nextLoadValue.optionalDouble
                    : option.nextLoadValue,
                progressionIncrement: option.exerciseID == defaultExerciseID
                    ? progressionIncrement.optionalDouble
                    : option.progressionIncrement
            )
        }

        guard optionPayloads.contains(where: { $0.exerciseID == defaultExerciseID }) else {
            return optionPayloads + [
                WorkoutTemplateExerciseOptionPayload(
                    position: (optionPayloads.map(\.position).max() ?? 0) + 1,
                    exerciseID: defaultExerciseID,
                    startingLoadValue: startingLoadValue.optionalDouble,
                    nextLoadValue: nextLoadValue.optionalDouble,
                    progressionIncrement: progressionIncrement.optionalDouble
                )
            ]
        }

        return optionPayloads
    }

    private mutating func loadProgressionDrafts(for exerciseID: UUID?) {
        let option = existingExerciseOptions.first { $0.exerciseID == exerciseID }
        startingLoadValue = option?.startingLoadValue.draftString ?? ""
        nextLoadValue = option?.nextLoadValue.draftString ?? ""
        progressionIncrement = option?.progressionIncrement.draftString ?? ""
    }

    private func setPrescriptionPayloads() -> [WorkoutTemplateSetPrescriptionPayload] {
        guard let firstPrescriptionID = existingSetPrescriptions.sortedByPosition.first?.id else {
            return [editedSetPrescriptionPayload(id: nil, position: 1)]
        }

        return existingSetPrescriptions.map { prescription in
            guard prescription.id == firstPrescriptionID else {
                return WorkoutTemplateSetPrescriptionPayload(
                    id: prescription.id,
                    position: prescription.position,
                    setType: prescription.setType,
                    repMin: prescription.repMin,
                    repMax: prescription.repMax,
                    loadStrategy: prescription.loadStrategy,
                    loadValue: prescription.loadValue
                )
            }

            return editedSetPrescriptionPayload(id: prescription.id, position: prescription.position)
        }
    }

    private func editedSetPrescriptionPayload(
        id: UUID?,
        position: Int
    ) -> WorkoutTemplateSetPrescriptionPayload {
        WorkoutTemplateSetPrescriptionPayload(
            id: id,
            position: position,
            setType: setType,
            repMin: Int(repMin) ?? 0,
            repMax: Int(repMax) ?? 0,
            loadStrategy: loadStrategy,
            loadValue: loadStrategy.requiresValue ? loadValue.optionalDouble : nil
        )
    }
}

private extension Array where Element == WorkoutTemplateSetPrescription {
    var sortedByPosition: [Element] {
        sorted { $0.position < $1.position }
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
