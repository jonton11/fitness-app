import Foundation

struct ExerciseFormState: Equatable {
    var name: String
    var primaryMuscleGroup: String
    var secondaryMuscleGroups: String
    var loadType: LoadType
    var notes: String
    var externalURL: String

    init(exercise: Exercise? = nil) {
        name = exercise?.name ?? ""
        primaryMuscleGroup = exercise?.primaryMuscleGroup ?? ""
        secondaryMuscleGroups = exercise?.secondaryMuscleGroups.joined(separator: ", ") ?? ""
        loadType = exercise?.loadType ?? .lb
        notes = exercise?.notes ?? ""
        externalURL = exercise?.externalURL ?? ""
    }

    func payload(lockVersion: Int?) -> ExercisePayload {
        ExercisePayload(
            name: name,
            primaryMuscleGroup: primaryMuscleGroup,
            secondaryMuscleGroups: secondaryMuscleGroups
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty },
            loadType: loadType,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            externalURL: externalURL.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            lockVersion: lockVersion
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
