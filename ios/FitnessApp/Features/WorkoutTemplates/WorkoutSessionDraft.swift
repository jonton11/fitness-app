import Foundation

struct WorkoutSessionDraft {
    var session: WorkoutSession
    var payload: WorkoutSessionCreatePayload

    init(
        template: WorkoutTemplate,
        startedAt: Date = Date(),
        makeID: () -> UUID = UUID.init
    ) throws {
        let timestamp = startedAt.apiTimestamp
        let sessionID = makeID()
        var sessionExercises: [WorkoutSessionExercise] = []

        for slot in template.slots.sorted(by: { $0.position < $1.position }) {
            guard let option = slot.exerciseOptions.first(where: { $0.isDefault }) ??
                    slot.exerciseOptions.first(where: { $0.exerciseID == slot.defaultExerciseID }) else {
                throw WorkoutSessionDraftError.missingDefaultExerciseOption
            }

            let sessionExerciseID = makeID()
            let plannedSetsByPrescriptionID = Dictionary(
                uniqueKeysWithValues: (option.plannedSessionSets ?? []).map {
                    ($0.workoutTemplateSetPrescriptionID, $0.plannedLoadValue)
                }
            )
            var sessionSets: [WorkoutSessionSet] = []

            for prescription in slot.setPrescriptions.sorted(by: { $0.position < $1.position }) {
                let setID = makeID()
                let plannedLoadValue = plannedSetsByPrescriptionID[prescription.id] ?? nil
                sessionSets.append(
                    WorkoutSessionSet(
                        id: setID,
                        workoutTemplateSetPrescriptionID: prescription.id,
                        position: prescription.position,
                        setType: prescription.setType,
                        targetRepMin: prescription.repMin,
                        targetRepMax: prescription.repMax,
                        loadStrategy: prescription.loadStrategy,
                        prescribedLoadValue: prescription.loadValue,
                        plannedLoadValue: plannedLoadValue,
                        actualReps: nil,
                        actualLoadValue: nil,
                        completionState: .pending,
                        completedAt: nil,
                        lockVersion: 0,
                        createdAt: timestamp,
                        updatedAt: timestamp
                    )
                )
            }

            sessionExercises.append(
                WorkoutSessionExercise(
                    id: sessionExerciseID,
                    workoutTemplateSlotID: slot.id,
                    workoutTemplateExerciseOptionID: option.id,
                    position: slot.position,
                    label: slot.label,
                    selectedExerciseID: option.exerciseID,
                    selectedExercise: WorkoutSessionExerciseSummary(
                        id: option.exercise.id,
                        name: option.exercise.name,
                        loadType: option.exercise.loadType
                    ),
                    restSeconds: slot.restSeconds,
                    plannedWorkingLoadValue: option.plannedWorkingLoadValue,
                    progressionIncrement: option.progressionIncrement,
                    status: .pending,
                    lockVersion: 0,
                    createdAt: timestamp,
                    updatedAt: timestamp,
                    workoutSessionSets: sessionSets
                )
            )
        }

        session = WorkoutSession(
            id: sessionID,
            workoutTemplateID: template.id,
            workoutTemplateName: template.name,
            status: .active,
            startedAt: timestamp,
            completedAt: nil,
            canceledAt: nil,
            createdAt: timestamp,
            updatedAt: timestamp,
            lockVersion: 0,
            exercises: sessionExercises
        )
        payload = WorkoutSessionCreatePayload(session: session)
    }
}

enum WorkoutSessionDraftError: Error {
    case missingDefaultExerciseOption
}

private extension WorkoutSessionCreatePayload {
    init(session: WorkoutSession) {
        self.init(
            id: session.id,
            workoutTemplateID: session.workoutTemplateID,
            workoutTemplateName: session.workoutTemplateName,
            startedAt: session.startedAt,
            exercises: session.exercises.map(WorkoutSessionExerciseCreatePayload.init)
        )
    }
}

private extension WorkoutSessionExerciseCreatePayload {
    init(exercise: WorkoutSessionExercise) {
        self.init(
            id: exercise.id,
            workoutTemplateSlotID: exercise.workoutTemplateSlotID,
            workoutTemplateExerciseOptionID: exercise.workoutTemplateExerciseOptionID,
            selectedExerciseID: exercise.selectedExerciseID,
            position: exercise.position,
            label: exercise.label,
            selectedExerciseName: exercise.selectedExercise.name,
            selectedExerciseLoadType: exercise.selectedExercise.loadType,
            restSeconds: exercise.restSeconds,
            plannedWorkingLoadValue: exercise.plannedWorkingLoadValue,
            progressionIncrement: exercise.progressionIncrement,
            workoutSessionSets: exercise.workoutSessionSets.map(WorkoutSessionSetCreatePayload.init)
        )
    }
}

private extension WorkoutSessionSetCreatePayload {
    init(set: WorkoutSessionSet) {
        self.init(
            id: set.id,
            workoutTemplateSetPrescriptionID: set.workoutTemplateSetPrescriptionID,
            position: set.position,
            setType: set.setType,
            targetRepMin: set.targetRepMin,
            targetRepMax: set.targetRepMax,
            loadStrategy: set.loadStrategy,
            prescribedLoadValue: set.prescribedLoadValue,
            plannedLoadValue: set.plannedLoadValue
        )
    }
}
