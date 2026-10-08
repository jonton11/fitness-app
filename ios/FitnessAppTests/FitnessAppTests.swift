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

    func testWorkoutTemplateFormPayloadPreservesSubstitutesAndAdditionalPrescriptionsWhenSwitchingDefault() throws {
        let defaultExerciseID = UUID()
        let substituteExerciseID = UUID()
        let defaultOptionID = UUID()
        let substituteOptionID = UUID()
        let firstPrescriptionID = UUID()
        let secondPrescriptionID = UUID()
        let slot = WorkoutTemplateSlot(
            id: UUID(),
            position: 1,
            label: "Upper Chest Press",
            defaultExerciseID: defaultExerciseID,
            defaultExercise: templateExerciseSummary(id: defaultExerciseID, name: "Incline Dumbbell Press"),
            restSeconds: 180,
            createdAt: "2026-10-03T12:00:00.000Z",
            updatedAt: "2026-10-03T12:00:00.000Z",
            lockVersion: 2,
            exerciseOptions: [
                WorkoutTemplateExerciseOption(
                    id: defaultOptionID,
                    position: 1,
                    exerciseID: defaultExerciseID,
                    exercise: templateExerciseSummary(id: defaultExerciseID, name: "Incline Dumbbell Press"),
                    isDefault: true,
                    startingLoadValue: 60,
                    nextLoadValue: 65,
                    calculatedNextLoadValue: 70,
                    progressionIncrement: 5,
                    createdAt: "2026-10-03T12:00:00.000Z",
                    updatedAt: "2026-10-03T12:00:00.000Z"
                ),
                WorkoutTemplateExerciseOption(
                    id: substituteOptionID,
                    position: 2,
                    exerciseID: substituteExerciseID,
                    exercise: templateExerciseSummary(id: substituteExerciseID, name: "Incline Machine Press"),
                    isDefault: false,
                    startingLoadValue: 80,
                    nextLoadValue: 85,
                    calculatedNextLoadValue: 90,
                    progressionIncrement: 10,
                    createdAt: "2026-10-03T12:00:00.000Z",
                    updatedAt: "2026-10-03T12:00:00.000Z"
                )
            ],
            setPrescriptions: [
                WorkoutTemplateSetPrescription(
                    id: firstPrescriptionID,
                    position: 1,
                    setType: .working,
                    repMin: 5,
                    repMax: 8,
                    loadStrategy: .workingLoad,
                    loadValue: nil,
                    createdAt: "2026-10-03T12:00:00.000Z",
                    updatedAt: "2026-10-03T12:00:00.000Z"
                ),
                WorkoutTemplateSetPrescription(
                    id: secondPrescriptionID,
                    position: 2,
                    setType: .warmup,
                    repMin: 10,
                    repMax: 12,
                    loadStrategy: .percentageOfWorkingLoad,
                    loadValue: 50,
                    createdAt: "2026-10-03T12:00:00.000Z",
                    updatedAt: "2026-10-03T12:00:00.000Z"
                )
            ]
        )
        let template = WorkoutTemplate(
            id: UUID(),
            name: "Upper",
            notes: nil,
            archivedAt: nil,
            createdAt: "2026-10-03T12:00:00.000Z",
            updatedAt: "2026-10-03T12:00:00.000Z",
            lockVersion: 4,
            slots: [slot]
        )
        var form = WorkoutTemplateFormState(template: template)
        form.slots[0].defaultExerciseID = substituteExerciseID
        form.slots[0].repMin = "6"

        let payload = try XCTUnwrap(form.payload(lockVersion: template.lockVersion).slots.first)

        XCTAssertEqual(form.slots[0].startingLoadValue, "80.0")
        XCTAssertEqual(form.slots[0].nextLoadValue, "85.0")
        XCTAssertEqual(form.slots[0].progressionIncrement, "10.0")
        XCTAssertEqual(payload.defaultExerciseID, substituteExerciseID)
        XCTAssertEqual(payload.exerciseOptions.map(\.id), [defaultOptionID, substituteOptionID])
        XCTAssertEqual(payload.exerciseOptions[0].startingLoadValue, 60)
        XCTAssertEqual(payload.exerciseOptions[0].nextLoadValue, 65)
        XCTAssertEqual(payload.exerciseOptions[0].progressionIncrement, 5)
        XCTAssertEqual(payload.exerciseOptions[1].exerciseID, substituteExerciseID)
        XCTAssertEqual(payload.exerciseOptions[1].startingLoadValue, 80)
        XCTAssertEqual(payload.exerciseOptions[1].nextLoadValue, 85)
        XCTAssertEqual(payload.exerciseOptions[1].progressionIncrement, 10)
        XCTAssertEqual(payload.setPrescriptions.map(\.id), [firstPrescriptionID, secondPrescriptionID])
        XCTAssertEqual(payload.setPrescriptions[0].repMin, 6)
        XCTAssertEqual(payload.setPrescriptions[1].repMin, 10)
        XCTAssertEqual(payload.setPrescriptions[1].loadValue, 50)
    }

    func testWorkoutSessionAPIClientStartsSessionWithRailsEnvelope() async throws {
        let templateID = UUID()
        let requestBox = URLRequestBox()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let urlSession = URLSession(configuration: configuration)
        let apiClient = WorkoutSessionAPIClient(
            baseURL: URL(string: "https://fitness.example")!,
            session: urlSession
        )

        URLProtocolStub.requestHandler = { request in
            requestBox.request = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 201,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let responseData = try JSONEncoder().encode([
                "workout_session": self.workoutSessionFixture(templateID: templateID)
            ])

            return (response, responseData)
        }
        defer {
            URLProtocolStub.requestHandler = nil
        }

        let session = try await apiClient.startWorkoutSession(
            templateID: templateID,
            startedAt: "2026-10-03T12:00:00.000Z"
        )

        let request = try XCTUnwrap(requestBox.request)
        let bodyData = try XCTUnwrap(request.httpBody ?? request.httpBodyStream?.readData())
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        let payload = try XCTUnwrap(body["workout_session"] as? [String: Any])

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/v1/workout_sessions")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(payload["workout_template_id"] as? String, templateID.uuidString)
        XCTAssertEqual(payload["started_at"] as? String, "2026-10-03T12:00:00.000Z")
        XCTAssertEqual(session.workoutTemplateID, templateID)
    }

    func testWorkoutSessionAPIClientListsCompletedSessionsWithRailsEnvelope() async throws {
        let requestBox = URLRequestBox()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let apiClient = WorkoutSessionAPIClient(
            baseURL: URL(string: "https://fitness.example")!,
            session: URLSession(configuration: configuration)
        )
        var completedSession = workoutSessionFixture()
        completedSession.status = .completed
        completedSession.completedAt = "2026-10-03T12:30:00.000Z"

        URLProtocolStub.requestHandler = { request in
            requestBox.request = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let responseData = try JSONSerialization.data(withJSONObject: [
                "workout_sessions": try JSONSerialization.jsonObject(
                    with: JSONEncoder().encode([completedSession])
                ),
                "meta": ["limit": 25, "offset": 50, "total": 76]
            ])

            return (response, responseData)
        }
        defer {
            URLProtocolStub.requestHandler = nil
        }

        let page = try await apiClient.listWorkoutSessions(limit: 25, offset: 50)

        let request = try XCTUnwrap(requestBox.request)
        let queryItems = try XCTUnwrap(
            URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
        )

        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/v1/workout_sessions")
        XCTAssertEqual(
            queryItems,
            [
                URLQueryItem(name: "status", value: "completed"),
                URLQueryItem(name: "limit", value: "25"),
                URLQueryItem(name: "offset", value: "50")
            ]
        )
        XCTAssertEqual(page.sessions, [completedSession])
        XCTAssertEqual(page.limit, 25)
        XCTAssertEqual(page.offset, 50)
        XCTAssertEqual(page.total, 76)
        XCTAssertTrue(page.hasNextPage)
    }

    func testWorkoutSessionAPIClientCreatesClientSnapshotWithRailsEnvelope() async throws {
        let draft = try WorkoutSessionDraft(
            template: offlineWorkoutTemplateFixture(),
            startedAt: Date(timeIntervalSince1970: 0)
        )
        let requestBox = URLRequestBox()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let apiClient = WorkoutSessionAPIClient(
            baseURL: URL(string: "https://fitness.example")!,
            session: URLSession(configuration: configuration)
        )

        URLProtocolStub.requestHandler = { request in
            requestBox.request = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 201,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (
                response,
                try JSONEncoder().encode(["workout_session": draft.session])
            )
        }
        defer {
            URLProtocolStub.requestHandler = nil
        }

        let session = try await apiClient.createWorkoutSession(payload: draft.payload)

        let request = try XCTUnwrap(requestBox.request)
        let bodyData = try XCTUnwrap(request.httpBody ?? request.httpBodyStream?.readData())
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        let payload = try XCTUnwrap(body["workout_session"] as? [String: Any])
        let exercise = try XCTUnwrap((payload["exercises"] as? [[String: Any]])?.first)
        let set = try XCTUnwrap((exercise["workout_session_sets"] as? [[String: Any]])?.first)

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/v1/workout_sessions")
        XCTAssertEqual(payload["id"] as? String, draft.session.id.uuidString)
        XCTAssertEqual(exercise["id"] as? String, draft.session.exercises[0].id.uuidString)
        XCTAssertEqual(set["id"] as? String, draft.session.exercises[0].workoutSessionSets[0].id.uuidString)
        XCTAssertEqual(set["planned_load_value"] as? Double, 70)
        XCTAssertEqual(session, draft.session)
    }

    func testWorkoutSessionDraftClonesCachedRailsPlan() throws {
        let template = offlineWorkoutTemplateFixture()
        let identifiers = [UUID(), UUID(), UUID()]
        var remainingIdentifiers = identifiers

        let draft = try WorkoutSessionDraft(
            template: template,
            startedAt: Date(timeIntervalSince1970: 0),
            makeID: { remainingIdentifiers.removeFirst() }
        )

        XCTAssertEqual(draft.session.id, identifiers[0])
        XCTAssertEqual(draft.session.startedAt, "1970-01-01T00:00:00.000Z")
        XCTAssertEqual(draft.session.workoutTemplateName, template.name)
        XCTAssertEqual(draft.session.exercises[0].id, identifiers[1])
        XCTAssertEqual(draft.session.exercises[0].plannedWorkingLoadValue, 70)
        XCTAssertEqual(draft.session.exercises[0].workoutSessionSets[0].id, identifiers[2])
        XCTAssertEqual(draft.session.exercises[0].workoutSessionSets[0].plannedLoadValue, 70)
        XCTAssertEqual(draft.payload.id, draft.session.id)
        XCTAssertEqual(draft.payload.exercises[0].workoutSessionSets[0].plannedLoadValue, 70)
    }

    func testSQLiteStoresActiveWorkoutAndConfiguration() throws {
        let database = try FitnessLocalDatabase(isStoredInMemoryOnly: true)
        let activeWorkoutStore = ActiveWorkoutStore(database: database, legacyFileURL: nil)
        let configurationStore = WorkoutConfigurationStore(database: database)
        let template = offlineWorkoutTemplateFixture()
        let draft = try WorkoutSessionDraft(template: template)
        let activeState = ActiveWorkoutState(
            session: draft.session,
            workoutTemplate: template,
            pendingSessionCreation: PendingWorkoutSessionCreation(payload: draft.payload)
        )
        let configuration = WorkoutConfigurationSnapshot(templates: [template], exercises: [])

        try activeWorkoutStore.save(activeState)
        try configurationStore.save(configuration)

        XCTAssertEqual(try activeWorkoutStore.load(), activeState)
        XCTAssertEqual(try configurationStore.load(), configuration)

        try activeWorkoutStore.clear()

        XCTAssertNil(try activeWorkoutStore.load())
        XCTAssertEqual(try configurationStore.load(), configuration)
    }

    @MainActor
    func testWorkoutTemplatesLoadRefreshesCachedConfiguration() async throws {
        let database = try FitnessLocalDatabase(isStoredInMemoryOnly: true)
        let configurationStore = WorkoutConfigurationStore(database: database)
        var cachedTemplate = offlineWorkoutTemplateFixture()
        cachedTemplate.name = "Cached Lower"
        var serverTemplate = cachedTemplate
        serverTemplate.name = "Updated Lower"
        try configurationStore.save(
            WorkoutConfigurationSnapshot(templates: [cachedTemplate], exercises: [])
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let urlSession = URLSession(configuration: configuration)
        let baseURL = URL(string: "https://fitness.example")!
        let viewModel = WorkoutTemplatesViewModel(
            templateAPIClient: WorkoutTemplateAPIClient(baseURL: baseURL, session: urlSession),
            exerciseAPIClient: ExerciseAPIClient(baseURL: baseURL, session: urlSession),
            activeWorkoutStore: activeWorkoutStore(box: ActiveWorkoutStoreBox(state: nil)),
            configurationStore: configurationStore
        )

        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data: Data
            if request.url?.path == "/api/v1/workout_templates" {
                data = try JSONEncoder().encode(["workout_templates": [serverTemplate]])
            } else {
                data = try JSONEncoder().encode(["exercises": [Exercise]()])
            }
            return (response, data)
        }
        defer {
            URLProtocolStub.requestHandler = nil
        }

        await viewModel.load()

        XCTAssertEqual(viewModel.templates.map(\.name), ["Updated Lower"])
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(try configurationStore.load()?.templates.map(\.name), ["Updated Lower"])
    }

    func testWorkoutSessionAPIClientUpdatesSessionSetWithRailsEnvelope() async throws {
        let setID = UUID()
        let requestBox = URLRequestBox()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let urlSession = URLSession(configuration: configuration)
        let apiClient = WorkoutSessionAPIClient(
            baseURL: URL(string: "https://fitness.example")!,
            session: urlSession
        )
        let payload = WorkoutSessionSetUpdatePayload(
            actualReps: 4,
            actualLoadValue: 65,
            completionState: .attemptedButTargetNotMet,
            completedAt: "2026-10-03T12:00:00.000Z",
            lockVersion: 2
        )

        URLProtocolStub.requestHandler = { request in
            requestBox.request = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            var set = self.workoutSessionSetFixture(id: setID, position: 1)
            set.actualReps = payload.actualReps
            set.actualLoadValue = payload.actualLoadValue
            set.completionState = payload.completionState
            set.completedAt = payload.completedAt
            set.lockVersion = payload.lockVersion + 1
            let responseData = try JSONEncoder().encode([
                "workout_session_set": set
            ])

            return (response, responseData)
        }
        defer {
            URLProtocolStub.requestHandler = nil
        }

        let set = try await apiClient.updateWorkoutSessionSet(id: setID, payload: payload)

        let request = try XCTUnwrap(requestBox.request)
        let bodyData = try XCTUnwrap(request.httpBody ?? request.httpBodyStream?.readData())
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        let bodyPayload = try XCTUnwrap(body["workout_session_set"] as? [String: Any])

        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.url?.path, "/api/v1/workout_session_sets/\(setID.uuidString)")
        XCTAssertEqual(bodyPayload["actual_reps"] as? Int, 4)
        XCTAssertEqual(bodyPayload["actual_load_value"] as? Double, 65)
        XCTAssertEqual(bodyPayload["completion_state"] as? String, "attempted_but_target_not_met")
        XCTAssertEqual(bodyPayload["completed_at"] as? String, "2026-10-03T12:00:00.000Z")
        XCTAssertEqual(bodyPayload["lock_version"] as? Int, 2)
        XCTAssertEqual(set.lockVersion, 3)
    }

    func testWorkoutSessionAPIClientSubstitutesSessionExerciseWithRailsEnvelope() async throws {
        let sessionExerciseID = UUID()
        let optionID = UUID()
        let requestBox = URLRequestBox()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let apiClient = WorkoutSessionAPIClient(
            baseURL: URL(string: "https://fitness.example")!,
            session: URLSession(configuration: configuration)
        )
        let payload = WorkoutSessionExerciseUpdatePayload(
            workoutTemplateExerciseOptionID: optionID,
            lockVersion: 2
        )

        URLProtocolStub.requestHandler = { request in
            requestBox.request = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            var exercise = self.workoutSessionFixture().exercises[0]
            exercise.workoutTemplateExerciseOptionID = optionID
            exercise.selectedExerciseID = UUID()
            exercise.selectedExercise.name = "Incline Smith Press"
            exercise.plannedWorkingLoadValue = 80
            exercise.lockVersion = payload.lockVersion + 1
            let responseData = try JSONEncoder().encode([
                "workout_session_exercise": exercise
            ])

            return (response, responseData)
        }
        defer {
            URLProtocolStub.requestHandler = nil
        }

        let exercise = try await apiClient.updateWorkoutSessionExercise(
            id: sessionExerciseID,
            payload: payload
        )

        let request = try XCTUnwrap(requestBox.request)
        let bodyData = try XCTUnwrap(request.httpBody ?? request.httpBodyStream?.readData())
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        let bodyPayload = try XCTUnwrap(body["workout_session_exercise"] as? [String: Any])

        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.url?.path, "/api/v1/workout_session_exercises/\(sessionExerciseID.uuidString)")
        XCTAssertEqual(bodyPayload["workout_template_exercise_option_id"] as? String, optionID.uuidString)
        XCTAssertEqual(bodyPayload["lock_version"] as? Int, 2)
        XCTAssertEqual(exercise.selectedExercise.name, "Incline Smith Press")
        XCTAssertEqual(exercise.plannedWorkingLoadValue, 80)
        XCTAssertEqual(exercise.lockVersion, 3)
    }

    func testWorkoutTemplateAPIClientCreatesNestedExerciseOption() async throws {
        let slotID = UUID()
        let exerciseID = UUID()
        let option = workoutTemplateExerciseOptionFixture(
            exerciseID: exerciseID,
            name: "Incline Machine Press"
        )
        let requestBox = URLRequestBox()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let apiClient = WorkoutTemplateAPIClient(
            baseURL: URL(string: "https://fitness.example")!,
            session: URLSession(configuration: configuration)
        )
        let exercisePayload = ExercisePayload(
            name: "Incline Machine Press",
            primaryMuscleGroup: "Chest",
            secondaryMuscleGroups: ["Shoulders"],
            loadType: .machineStack,
            notes: nil,
            externalURL: nil,
            lockVersion: nil
        )
        let payload = WorkoutTemplateExerciseOptionCreatePayload(
            workoutTemplateSlotID: slotID,
            exerciseID: exerciseID,
            exercise: exercisePayload,
            startingLoadValue: 80,
            progressionIncrement: 10
        )

        URLProtocolStub.requestHandler = { request in
            requestBox.request = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 201,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let responseData = try JSONEncoder().encode([
                "workout_template_exercise_option": option
            ])

            return (response, responseData)
        }
        defer {
            URLProtocolStub.requestHandler = nil
        }

        let createdOption = try await apiClient.createExerciseOption(payload)

        let request = try XCTUnwrap(requestBox.request)
        let bodyData = try XCTUnwrap(request.httpBody ?? request.httpBodyStream?.readData())
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        let bodyPayload = try XCTUnwrap(body["workout_template_exercise_option"] as? [String: Any])
        let nestedExercise = try XCTUnwrap(bodyPayload["exercise"] as? [String: Any])

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/v1/workout_template_exercise_options")
        XCTAssertEqual(bodyPayload["workout_template_slot_id"] as? String, slotID.uuidString)
        XCTAssertEqual(bodyPayload["exercise_id"] as? String, exerciseID.uuidString)
        XCTAssertEqual(nestedExercise["name"] as? String, "Incline Machine Press")
        XCTAssertEqual(nestedExercise["load_type"] as? String, "machine_stack")
        XCTAssertEqual(bodyPayload["starting_load_value"] as? Double, 80)
        XCTAssertEqual(bodyPayload["progression_increment"] as? Double, 10)
        XCTAssertEqual(createdOption, option)
    }

    func testWorkoutSessionAPIClientFinishesSessionWithRailsEnvelope() async throws {
        let sessionID = UUID()
        let requestBox = URLRequestBox()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let urlSession = URLSession(configuration: configuration)
        let apiClient = WorkoutSessionAPIClient(
            baseURL: URL(string: "https://fitness.example")!,
            session: urlSession
        )
        let payload = WorkoutSessionStatusPayload(
            status: .completed,
            completedAt: "2026-10-03T12:20:00.000Z",
            lockVersion: 2
        )

        URLProtocolStub.requestHandler = { request in
            requestBox.request = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            var session = self.workoutSessionFixture()
            session.status = .completed
            session.completedAt = payload.completedAt
            session.lockVersion = payload.lockVersion + 1
            let responseData = try JSONEncoder().encode([
                "workout_session": session
            ])

            return (response, responseData)
        }
        defer {
            URLProtocolStub.requestHandler = nil
        }

        let session = try await apiClient.updateWorkoutSession(id: sessionID, payload: payload)

        let request = try XCTUnwrap(requestBox.request)
        let bodyData = try XCTUnwrap(request.httpBody ?? request.httpBodyStream?.readData())
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        let bodyPayload = try XCTUnwrap(body["workout_session"] as? [String: Any])

        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.url?.path, "/api/v1/workout_sessions/\(sessionID.uuidString)")
        XCTAssertEqual(bodyPayload["status"] as? String, "completed")
        XCTAssertEqual(bodyPayload["completed_at"] as? String, "2026-10-03T12:20:00.000Z")
        XCTAssertEqual(bodyPayload["lock_version"] as? Int, 2)
        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(session.lockVersion, 3)
    }

    func testWorkoutSessionAPIClientCancelsSessionWithRailsEnvelope() async throws {
        let sessionID = UUID()
        let requestBox = URLRequestBox()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let urlSession = URLSession(configuration: configuration)
        let apiClient = WorkoutSessionAPIClient(
            baseURL: URL(string: "https://fitness.example")!,
            session: urlSession
        )
        let payload = WorkoutSessionStatusPayload(
            status: .canceled,
            completedAt: nil,
            canceledAt: "2026-10-03T12:20:00.000Z",
            lockVersion: 2
        )

        URLProtocolStub.requestHandler = { request in
            requestBox.request = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            var session = self.workoutSessionFixture()
            session.status = .canceled
            session.canceledAt = payload.canceledAt
            session.lockVersion = payload.lockVersion + 1
            let responseData = try JSONEncoder().encode([
                "workout_session": session
            ])

            return (response, responseData)
        }
        defer {
            URLProtocolStub.requestHandler = nil
        }

        let session = try await apiClient.updateWorkoutSession(id: sessionID, payload: payload)

        let request = try XCTUnwrap(requestBox.request)
        let bodyData = try XCTUnwrap(request.httpBody ?? request.httpBodyStream?.readData())
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        let bodyPayload = try XCTUnwrap(body["workout_session"] as? [String: Any])

        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.url?.path, "/api/v1/workout_sessions/\(sessionID.uuidString)")
        XCTAssertEqual(bodyPayload["status"] as? String, "canceled")
        XCTAssertEqual(bodyPayload["canceled_at"] as? String, "2026-10-03T12:20:00.000Z")
        XCTAssertNil(bodyPayload["completed_at"])
        XCTAssertEqual(bodyPayload["lock_version"] as? Int, 2)
        XCTAssertEqual(session.status, .canceled)
        XCTAssertEqual(session.lockVersion, 3)
    }

    func testActiveWorkoutStateDecodesLegacyPendingSessionCompletion() throws {
        let session = workoutSessionFixture()
        let completedAt = "2026-10-03T12:20:00.000Z"
        let pendingUpdate = PendingWorkoutSessionUpdate(
            sessionID: session.id,
            payload: WorkoutSessionStatusPayload(
                status: .completed,
                completedAt: completedAt,
                lockVersion: session.lockVersion
            )
        )
        let sessionData = try JSONEncoder().encode(session)
        let pendingUpdateData = try JSONEncoder().encode(pendingUpdate)
        var sessionObject = try XCTUnwrap(JSONSerialization.jsonObject(with: sessionData) as? [String: Any])
        var exercises = try XCTUnwrap(sessionObject["exercises"] as? [[String: Any]])
        exercises[0].removeValue(forKey: "lock_version")
        sessionObject["exercises"] = exercises
        let stateData = try JSONSerialization.data(withJSONObject: [
            "session": sessionObject,
            "pending_set_updates": [],
            "pending_session_completion": try XCTUnwrap(
                JSONSerialization.jsonObject(with: pendingUpdateData) as? [String: Any]
            ),
            "sync_issues": []
        ])

        let state = try JSONDecoder().decode(ActiveWorkoutState.self, from: stateData)

        XCTAssertEqual(state.pendingSessionUpdate, pendingUpdate)
        XCTAssertEqual(state.session.exercises[0].lockVersion, 0)
    }

    func testWorkoutSessionAPIClientIncludesResponseStatusForFailures() async throws {
        let setID = UUID()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let urlSession = URLSession(configuration: configuration)
        let apiClient = WorkoutSessionAPIClient(
            baseURL: URL(string: "https://fitness.example")!,
            session: urlSession
        )
        let payload = WorkoutSessionSetUpdatePayload(
            actualReps: 4,
            actualLoadValue: 65,
            completionState: .attemptedButTargetNotMet,
            completedAt: "2026-10-03T12:00:00.000Z",
            lockVersion: 2
        )

        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 409,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            return (response, Data())
        }
        defer {
            URLProtocolStub.requestHandler = nil
        }

        do {
            _ = try await apiClient.updateWorkoutSessionSet(id: setID, payload: payload)
            XCTFail("Expected request to fail.")
        } catch let error as WorkoutSessionAPIError {
            XCTAssertEqual(error, .requestFailed(statusCode: 409))
        }
    }

    @MainActor
    func testWorkoutHistoryCombinesPendingLocalCompletionWithServerHistory() async {
        var pendingSession = workoutSessionFixture()
        pendingSession.status = .completed
        pendingSession.completedAt = "2026-10-03T12:30:00.000Z"
        pendingSession.exercises[0].workoutSessionSets[0].actualReps = 8
        pendingSession.exercises[0].workoutSessionSets[0].actualLoadValue = 65
        pendingSession.exercises[0].workoutSessionSets[0].completionState = .completed
        let pendingUpdate = PendingWorkoutSessionUpdate(
            sessionID: pendingSession.id,
            payload: WorkoutSessionStatusPayload(
                status: .completed,
                completedAt: pendingSession.completedAt,
                lockVersion: pendingSession.lockVersion
            )
        )
        let box = ActiveWorkoutStoreBox(
            state: ActiveWorkoutState(
                session: pendingSession,
                pendingSessionUpdate: pendingUpdate
            )
        )
        var staleServerCopy = pendingSession
        staleServerCopy.exercises[0].workoutSessionSets[0].actualReps = nil
        staleServerCopy.exercises[0].workoutSessionSets[0].actualLoadValue = nil
        staleServerCopy.exercises[0].workoutSessionSets[0].completionState = .pending
        var olderServerSession = workoutSessionFixture()
        olderServerSession.status = .completed
        olderServerSession.startedAt = "2026-10-02T12:00:00.000Z"
        olderServerSession.completedAt = "2026-10-02T12:30:00.000Z"
        let viewModel = WorkoutHistoryViewModel(
            activeWorkoutStore: activeWorkoutStore(box: box),
            listWorkoutSessions: { _ in
                WorkoutSessionPage(
                    sessions: [staleServerCopy, olderServerSession],
                    limit: 50,
                    offset: 0,
                    total: 2
                )
            }
        )

        await viewModel.load()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.entries.count, 2)
        XCTAssertEqual(viewModel.entries[0].id, pendingSession.id)
        XCTAssertEqual(viewModel.entries[0].syncState, .pending)
        XCTAssertEqual(
            viewModel.entries[0].session.exercises[0].workoutSessionSets[0].actualReps,
            8
        )
        XCTAssertEqual(viewModel.entries[1].id, olderServerSession.id)
        XCTAssertNil(viewModel.entries[1].syncState)
    }

    @MainActor
    func testWorkoutHistoryKeepsLocalCompletionWhenRefreshFails() async {
        var pendingSession = workoutSessionFixture()
        pendingSession.status = .completed
        pendingSession.completedAt = "2026-10-03T12:30:00.000Z"
        let failedSet = pendingSession.exercises[0].workoutSessionSets[0]
        let payload = WorkoutSessionSetUpdatePayload(
            actualReps: 4,
            actualLoadValue: 65,
            completionState: .attemptedButTargetNotMet,
            completedAt: pendingSession.completedAt,
            lockVersion: failedSet.lockVersion
        )
        let box = ActiveWorkoutStoreBox(
            state: ActiveWorkoutState(
                session: pendingSession,
                syncIssues: [
                    WorkoutSessionSetSyncIssue(
                        setID: failedSet.id,
                        payload: payload,
                        statusCode: 409
                    )
                ]
            )
        )
        let viewModel = WorkoutHistoryViewModel(
            activeWorkoutStore: activeWorkoutStore(box: box),
            listWorkoutSessions: { _ in throw URLError(.notConnectedToInternet) }
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.entries.count, 1)
        XCTAssertEqual(viewModel.entries[0].session, pendingSession)
        XCTAssertEqual(viewModel.entries[0].syncState, .needsAttention)
        XCTAssertEqual(viewModel.errorMessage, "Could not refresh workout history.")
    }

    @MainActor
    func testWorkoutHistoryLoadsSubsequentPages() async {
        var newerSession = workoutSessionFixture()
        newerSession.status = .completed
        newerSession.startedAt = "2026-10-03T12:00:00.000Z"
        var olderSession = workoutSessionFixture(id: UUID())
        olderSession.status = .completed
        olderSession.startedAt = "2026-10-02T12:00:00.000Z"
        var requestedOffsets: [Int] = []
        let viewModel = WorkoutHistoryViewModel(
            activeWorkoutStore: activeWorkoutStore(box: ActiveWorkoutStoreBox(state: nil)),
            listWorkoutSessions: { offset in
                requestedOffsets.append(offset)
                if offset == 0 {
                    return WorkoutSessionPage(
                        sessions: [newerSession],
                        limit: 1,
                        offset: 0,
                        total: 2
                    )
                }

                return WorkoutSessionPage(
                    sessions: [olderSession],
                    limit: 1,
                    offset: 1,
                    total: 2
                )
            }
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.entries.map(\.id), [newerSession.id])
        XCTAssertTrue(viewModel.canLoadMore)

        await viewModel.loadMore()

        XCTAssertEqual(requestedOffsets, [0, 1])
        XCTAssertEqual(viewModel.entries.map(\.id), [newerSession.id, olderSession.id])
        XCTAssertFalse(viewModel.canLoadMore)
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testWorkoutHistoryKeepsLoadedPageWhenLocalStoreFails() async {
        var newerSession = workoutSessionFixture()
        newerSession.status = .completed
        newerSession.startedAt = "2026-10-03T12:00:00.000Z"
        var olderSession = workoutSessionFixture(id: UUID())
        olderSession.status = .completed
        olderSession.startedAt = "2026-10-02T12:00:00.000Z"
        let failingStore = ActiveWorkoutStore(
            load: { throw ActiveWorkoutStoreFailure.failed },
            save: { _ in },
            clear: {}
        )
        let viewModel = WorkoutHistoryViewModel(
            activeWorkoutStore: failingStore,
            listWorkoutSessions: { offset in
                WorkoutSessionPage(
                    sessions: offset == 0 ? [newerSession] : [olderSession],
                    limit: 1,
                    offset: offset,
                    total: 2
                )
            }
        )

        await viewModel.load()
        await viewModel.loadMore()

        XCTAssertEqual(viewModel.entries.map(\.id), [newerSession.id, olderSession.id])
        XCTAssertFalse(viewModel.canLoadMore)
        XCTAssertEqual(viewModel.errorMessage, "Could not load the workout awaiting sync.")
    }

    @MainActor
    func testActiveWorkoutSaveSetDefaultsLoadPersistsLocallyAndMergesServerSet() async {
        let box = ActiveWorkoutStoreBox(state: nil)
        let store = activeWorkoutStore(box: box)
        let session = workoutSessionFixture()
        let currentSet = session.exercises[0].workoutSessionSets[0]
        let viewModel = ActiveWorkoutViewModel(
            session: session,
            store: store,
            now: { Date(timeIntervalSince1970: 0) },
            updateWorkoutSessionSet: { id, payload in
                XCTAssertEqual(id, currentSet.id)
                XCTAssertEqual(payload.lockVersion, currentSet.lockVersion)

                var syncedSet = currentSet
                syncedSet.actualReps = payload.actualReps
                syncedSet.actualLoadValue = payload.actualLoadValue
                syncedSet.completionState = payload.completionState
                syncedSet.completedAt = payload.completedAt
                syncedSet.lockVersion = currentSet.lockVersion + 1
                return syncedSet
            }
        )

        viewModel.repDraft = "7"

        let didSave = await viewModel.saveCurrentSet()

        XCTAssertTrue(didSave)
        XCTAssertEqual(viewModel.session.exercises[0].workoutSessionSets[0].completionState, .completed)
        XCTAssertEqual(viewModel.session.exercises[0].workoutSessionSets[0].actualReps, 7)
        XCTAssertEqual(viewModel.session.exercises[0].workoutSessionSets[0].actualLoadValue, 65)
        XCTAssertEqual(viewModel.session.exercises[0].workoutSessionSets[0].lockVersion, 1)
        XCTAssertEqual(viewModel.currentSet?.position, 2)
        XCTAssertEqual(box.state?.session.exercises[0].workoutSessionSets[0].actualReps, 7)
        XCTAssertEqual(box.state?.session.exercises[0].workoutSessionSets[0].lockVersion, 1)
        XCTAssertEqual(box.state?.pendingSetUpdates, [])
    }

    @MainActor
    func testActiveWorkoutSaveSetMarksBelowTargetAsAttemptedButTargetNotMet() async {
        let box = ActiveWorkoutStoreBox(state: nil)
        let viewModel = ActiveWorkoutViewModel(
            session: workoutSessionFixture(),
            store: activeWorkoutStore(box: box),
            updateWorkoutSessionSet: { _, _ in
                throw URLError(.notConnectedToInternet)
            }
        )

        viewModel.repDraft = "4"

        let didSave = await viewModel.saveCurrentSet()

        XCTAssertTrue(didSave)
        XCTAssertEqual(viewModel.session.exercises[0].workoutSessionSets[0].completionState, .attemptedButTargetNotMet)
    }

    @MainActor
    func testActiveWorkoutSaveSetRejectsInvalidLoad() async {
        let box = ActiveWorkoutStoreBox(state: nil)
        let viewModel = ActiveWorkoutViewModel(
            session: workoutSessionFixture(),
            store: activeWorkoutStore(box: box),
            updateWorkoutSessionSet: { _, _ in
                XCTFail("Server sync should not run when load validation fails.")
                throw ActiveWorkoutStoreFailure.failed
            }
        )

        viewModel.repDraft = "7"
        viewModel.loadDraft = "abc"

        let didSave = await viewModel.saveCurrentSet()

        XCTAssertFalse(didSave)
        XCTAssertEqual(viewModel.errorMessage, "Enter a valid load.")
        XCTAssertEqual(viewModel.session.exercises[0].workoutSessionSets[0].completionState, .pending)
        XCTAssertNil(box.state)
    }

    @MainActor
    func testActiveWorkoutSaveSetKeepsPendingSyncWhenServerUpdateFails() async {
        let box = ActiveWorkoutStoreBox(state: nil)
        let viewModel = ActiveWorkoutViewModel(
            session: workoutSessionFixture(),
            store: activeWorkoutStore(box: box),
            updateWorkoutSessionSet: { _, _ in
                throw URLError(.notConnectedToInternet)
            }
        )

        viewModel.repDraft = "7"

        let didSave = await viewModel.saveCurrentSet()

        XCTAssertTrue(didSave)
        XCTAssertEqual(viewModel.errorMessage, "Set saved locally. Sync pending.")
        XCTAssertEqual(viewModel.pendingSyncCount, 1)
        XCTAssertEqual(box.state?.pendingSetUpdates.count, 1)
        XCTAssertEqual(box.state?.session.exercises[0].workoutSessionSets[0].actualReps, 7)
    }

    @MainActor
    func testActiveWorkoutRetriesPendingSetUpdatesFromLocalState() async throws {
        let session = workoutSessionFixture()
        let currentSet = session.exercises[0].workoutSessionSets[0]
        let pendingUpdate = PendingWorkoutSessionSetUpdate(
            setID: currentSet.id,
            payload: WorkoutSessionSetUpdatePayload(
                actualReps: 7,
                actualLoadValue: 65,
                completionState: .completed,
                completedAt: "2026-10-03T12:00:00.000Z",
                lockVersion: currentSet.lockVersion
            )
        )
        let box = ActiveWorkoutStoreBox(
            state: ActiveWorkoutState(
                session: session,
                pendingSetUpdates: [pendingUpdate]
            )
        )
        let viewModel = ActiveWorkoutViewModel(
            session: session,
            store: activeWorkoutStore(box: box),
            updateWorkoutSessionSet: { id, payload in
                XCTAssertEqual(id, pendingUpdate.setID)
                XCTAssertEqual(payload, pendingUpdate.payload)

                var syncedSet = currentSet
                syncedSet.actualReps = payload.actualReps
                syncedSet.actualLoadValue = payload.actualLoadValue
                syncedSet.completionState = payload.completionState
                syncedSet.completedAt = payload.completedAt
                syncedSet.lockVersion = currentSet.lockVersion + 1
                return syncedSet
            }
        )

        XCTAssertEqual(viewModel.pendingSyncCount, 1)

        await viewModel.retryPendingSetUpdates()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.pendingSyncCount, 0)
        XCTAssertEqual(viewModel.session.exercises[0].workoutSessionSets[0].lockVersion, 1)
        XCTAssertEqual(box.state?.pendingSetUpdates, [])
        XCTAssertEqual(box.state?.session.exercises[0].workoutSessionSets[0].lockVersion, 1)
    }

    @MainActor
    func testActiveWorkoutRetryRefreshesStalePendingSetUpdate() async {
        let session = workoutSessionFixture()
        let firstSet = session.exercises[0].workoutSessionSets[0]
        let pendingUpdate = PendingWorkoutSessionSetUpdate(
            setID: firstSet.id,
            payload: WorkoutSessionSetUpdatePayload(
                actualReps: 7,
                actualLoadValue: 65,
                completionState: .completed,
                completedAt: "2026-10-03T12:00:00.000Z",
                lockVersion: firstSet.lockVersion
            )
        )
        let box = ActiveWorkoutStoreBox(
            state: ActiveWorkoutState(
                session: session,
                pendingSetUpdates: [pendingUpdate]
            )
        )
        var updateAttempts = 0
        var refreshedSession = session
        refreshedSession.exercises[0].workoutSessionSets[0].lockVersion = 4
        let viewModel = ActiveWorkoutViewModel(
            session: session,
            store: activeWorkoutStore(box: box),
            getWorkoutSession: { id in
                XCTAssertEqual(id, session.id)
                return refreshedSession
            },
            updateWorkoutSessionSet: { id, payload in
                XCTAssertEqual(id, pendingUpdate.setID)
                updateAttempts += 1

                if updateAttempts == 1 {
                    XCTAssertEqual(payload.lockVersion, firstSet.lockVersion)
                    throw WorkoutSessionAPIError.requestFailed(statusCode: 409)
                }

                XCTAssertEqual(payload.lockVersion, 4)

                var syncedSet = firstSet
                syncedSet.actualReps = payload.actualReps
                syncedSet.actualLoadValue = payload.actualLoadValue
                syncedSet.completionState = payload.completionState
                syncedSet.completedAt = payload.completedAt
                syncedSet.lockVersion = payload.lockVersion + 1
                return syncedSet
            }
        )

        await viewModel.retryPendingSetUpdates()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(updateAttempts, 2)
        XCTAssertEqual(viewModel.pendingSyncCount, 0)
        XCTAssertEqual(viewModel.syncIssueCount, 0)
        XCTAssertEqual(viewModel.session.exercises[0].workoutSessionSets[0].lockVersion, 5)
        XCTAssertEqual(box.state?.pendingSetUpdates, [])
        XCTAssertEqual(box.state?.syncIssues, [])
    }

    @MainActor
    func testActiveWorkoutRetryKeepsStaleConflictAsSyncIssueWhenServerSetHasDifferentActuals() async {
        let session = workoutSessionFixture()
        let firstSet = session.exercises[0].workoutSessionSets[0]
        let pendingUpdate = PendingWorkoutSessionSetUpdate(
            setID: firstSet.id,
            payload: WorkoutSessionSetUpdatePayload(
                actualReps: 7,
                actualLoadValue: 65,
                completionState: .completed,
                completedAt: "2026-10-03T12:00:00.000Z",
                lockVersion: firstSet.lockVersion
            )
        )
        let box = ActiveWorkoutStoreBox(
            state: ActiveWorkoutState(
                session: session,
                pendingSetUpdates: [pendingUpdate]
            )
        )
        var updateAttempts = 0
        var refreshedSession = session
        refreshedSession.exercises[0].workoutSessionSets[0].actualReps = 5
        refreshedSession.exercises[0].workoutSessionSets[0].actualLoadValue = 60
        refreshedSession.exercises[0].workoutSessionSets[0].completionState = .attemptedButTargetNotMet
        refreshedSession.exercises[0].workoutSessionSets[0].completedAt = "2026-10-03T12:01:00.000Z"
        refreshedSession.exercises[0].workoutSessionSets[0].lockVersion = 4
        let viewModel = ActiveWorkoutViewModel(
            session: session,
            store: activeWorkoutStore(box: box),
            getWorkoutSession: { id in
                XCTAssertEqual(id, session.id)
                return refreshedSession
            },
            updateWorkoutSessionSet: { _, _ in
                updateAttempts += 1

                if updateAttempts > 1 {
                    XCTFail("Conflicting server actuals should not be overwritten with a refreshed lock_version.")
                }

                throw WorkoutSessionAPIError.requestFailed(statusCode: 409)
            }
        )

        await viewModel.retryPendingSetUpdates()

        XCTAssertEqual(updateAttempts, 1)
        XCTAssertEqual(viewModel.errorMessage, "Some set syncs need attention.")
        XCTAssertEqual(viewModel.pendingSyncCount, 0)
        XCTAssertEqual(viewModel.syncIssueCount, 1)
        XCTAssertEqual(box.state?.pendingSetUpdates, [])
        XCTAssertEqual(box.state?.syncIssues.count, 1)
        XCTAssertEqual(box.state?.syncIssues.first?.setID, pendingUpdate.setID)
        XCTAssertEqual(box.state?.syncIssues.first?.payload, pendingUpdate.payload)
        XCTAssertEqual(box.state?.syncIssues.first?.statusCode, 409)
    }

    @MainActor
    func testActiveWorkoutRetryMovesValidationFailureToSyncIssueAndContinuesQueue() async {
        let session = workoutSessionFixture()
        let firstSet = session.exercises[0].workoutSessionSets[0]
        let secondSet = session.exercises[0].workoutSessionSets[1]
        let firstPendingUpdate = PendingWorkoutSessionSetUpdate(
            setID: firstSet.id,
            payload: WorkoutSessionSetUpdatePayload(
                actualReps: 7,
                actualLoadValue: 65,
                completionState: .completed,
                completedAt: "2026-10-03T12:00:00.000Z",
                lockVersion: firstSet.lockVersion
            )
        )
        let secondPendingUpdate = PendingWorkoutSessionSetUpdate(
            setID: secondSet.id,
            payload: WorkoutSessionSetUpdatePayload(
                actualReps: 8,
                actualLoadValue: 70,
                completionState: .completed,
                completedAt: "2026-10-03T12:05:00.000Z",
                lockVersion: secondSet.lockVersion
            )
        )
        let box = ActiveWorkoutStoreBox(
            state: ActiveWorkoutState(
                session: session,
                pendingSetUpdates: [firstPendingUpdate, secondPendingUpdate]
            )
        )
        let viewModel = ActiveWorkoutViewModel(
            session: session,
            store: activeWorkoutStore(box: box),
            updateWorkoutSessionSet: { id, payload in
                if id == firstPendingUpdate.setID {
                    throw WorkoutSessionAPIError.requestFailed(statusCode: 422)
                }

                XCTAssertEqual(id, secondPendingUpdate.setID)
                XCTAssertEqual(payload, secondPendingUpdate.payload)

                var syncedSet = secondSet
                syncedSet.actualReps = payload.actualReps
                syncedSet.actualLoadValue = payload.actualLoadValue
                syncedSet.completionState = payload.completionState
                syncedSet.completedAt = payload.completedAt
                syncedSet.lockVersion = payload.lockVersion + 1
                return syncedSet
            }
        )

        await viewModel.retryPendingSetUpdates()

        XCTAssertEqual(viewModel.errorMessage, "Some set syncs need attention.")
        XCTAssertEqual(viewModel.pendingSyncCount, 0)
        XCTAssertEqual(viewModel.syncIssueCount, 1)
        XCTAssertEqual(viewModel.session.exercises[0].workoutSessionSets[1].lockVersion, 1)
        XCTAssertEqual(box.state?.pendingSetUpdates, [])
        XCTAssertEqual(box.state?.syncIssues.count, 1)
        XCTAssertEqual(box.state?.syncIssues.first?.setID, firstPendingUpdate.setID)
        XCTAssertEqual(box.state?.syncIssues.first?.statusCode, 422)
    }

    @MainActor
    func testActiveWorkoutSaveSetDoesNotMutateSessionWhenLocalPersistenceFails() async {
        let store = ActiveWorkoutStore(
            load: { nil },
            save: { _ in throw ActiveWorkoutStoreFailure.failed },
            clear: {}
        )
        let viewModel = ActiveWorkoutViewModel(
            session: workoutSessionFixture(),
            store: store,
            now: { Date(timeIntervalSince1970: 0) },
            updateWorkoutSessionSet: { _, _ in
                XCTFail("Server sync should not run when local persistence fails.")
                throw ActiveWorkoutStoreFailure.failed
            }
        )

        viewModel.repDraft = "7"

        let didSave = await viewModel.saveCurrentSet()

        XCTAssertFalse(didSave)
        XCTAssertEqual(viewModel.errorMessage, "Could not save set.")
        XCTAssertEqual(viewModel.session.exercises[0].workoutSessionSets[0].completionState, .pending)
        XCTAssertNil(viewModel.session.exercises[0].workoutSessionSets[0].actualReps)
    }

    @MainActor
    func testActiveWorkoutSaveSetRequiresReps() async {
        let box = ActiveWorkoutStoreBox(state: nil)
        let viewModel = ActiveWorkoutViewModel(
            session: workoutSessionFixture(),
            store: activeWorkoutStore(box: box),
            updateWorkoutSessionSet: { _, _ in
                XCTFail("Server sync should not run when validation fails.")
                throw ActiveWorkoutStoreFailure.failed
            }
        )

        viewModel.repDraft = ""

        let didSave = await viewModel.saveCurrentSet()

        XCTAssertFalse(didSave)
        XCTAssertEqual(viewModel.errorMessage, "Enter reps before saving.")
        XCTAssertEqual(viewModel.session.exercises[0].workoutSessionSets[0].completionState, .pending)
    }

    @MainActor
    func testActiveWorkoutSkipExercisePreservesPerformedSetsAndQueuesRemainingSets() async {
        let box = ActiveWorkoutStoreBox(state: nil)
        var session = workoutSessionFixture()
        session.exercises[0].workoutSessionSets[0].actualReps = 7
        session.exercises[0].workoutSessionSets[0].actualLoadValue = 65
        session.exercises[0].workoutSessionSets[0].completionState = .completed
        session.exercises[0].workoutSessionSets[0].completedAt = "2026-10-03T12:00:00.000Z"
        let viewModel = ActiveWorkoutViewModel(
            session: session,
            store: activeWorkoutStore(box: box),
            updateWorkoutSessionSet: { _, _ in
                throw URLError(.notConnectedToInternet)
            }
        )

        let didSkip = await viewModel.skipSelectedExercise()

        XCTAssertTrue(didSkip)
        XCTAssertEqual(viewModel.pendingSyncCount, 1)
        XCTAssertEqual(viewModel.session.exercises[0].status, .completed)
        XCTAssertEqual(viewModel.session.exercises[0].workoutSessionSets[0].completionState, .completed)
        XCTAssertEqual(viewModel.session.exercises[0].workoutSessionSets[1].completionState, .notPerformed)
        XCTAssertEqual(box.state?.pendingSetUpdates.count, 1)
        XCTAssertEqual(box.state?.pendingSetUpdates.first?.payload.completionState, .notPerformed)
        XCTAssertNil(box.state?.pendingSetUpdates.first?.payload.actualReps)
        XCTAssertNil(box.state?.pendingSetUpdates.first?.payload.completedAt)
    }

    @MainActor
    func testActiveWorkoutCancelPersistsLocallyWhenServerIsUnavailable() async {
        let box = ActiveWorkoutStoreBox(state: nil)
        let session = workoutSessionFixture()
        let viewModel = ActiveWorkoutViewModel(
            session: session,
            store: activeWorkoutStore(box: box),
            now: { Date(timeIntervalSince1970: 0) },
            updateWorkoutSession: { _, _ in
                throw URLError(.notConnectedToInternet)
            }
        )

        let didCancel = await viewModel.cancelWorkout()

        XCTAssertTrue(didCancel)
        XCTAssertEqual(viewModel.errorMessage, "Workout saved locally. Cancel sync pending.")
        XCTAssertEqual(viewModel.pendingSyncCount, 1)
        XCTAssertEqual(viewModel.session.status, .canceled)
        XCTAssertNil(viewModel.session.completedAt)
        XCTAssertEqual(viewModel.session.canceledAt, "1970-01-01T00:00:00.000Z")
        XCTAssertEqual(box.state?.pendingSessionUpdate?.payload.status, .canceled)
        XCTAssertEqual(box.state?.pendingSessionUpdate?.payload.canceledAt, "1970-01-01T00:00:00.000Z")
    }

    @MainActor
    func testActiveWorkoutSubstitutesPendingExerciseAndPersistsServerPlan() async {
        let templateID = UUID()
        let slotID = UUID()
        let option = workoutTemplateExerciseOptionFixture(
            exerciseID: UUID(),
            name: "Incline Smith Press"
        )
        var session = workoutSessionFixture(templateID: templateID)
        session.exercises[0].workoutTemplateSlotID = slotID
        session.exercises[0].lockVersion = 4
        let box = ActiveWorkoutStoreBox(state: nil)
        let template = workoutTemplateFixture(
            id: templateID,
            slotID: slotID,
            exerciseOptions: [option]
        )
        let viewModel = ActiveWorkoutViewModel(
            session: session,
            workoutTemplate: template,
            store: activeWorkoutStore(box: box),
            updateWorkoutSessionExercise: { id, payload in
                XCTAssertEqual(id, session.exercises[0].id)
                XCTAssertEqual(payload.workoutTemplateExerciseOptionID, option.id)
                XCTAssertEqual(payload.lockVersion, 4)

                var updatedExercise = session.exercises[0]
                updatedExercise.workoutTemplateExerciseOptionID = option.id
                updatedExercise.selectedExerciseID = option.exerciseID
                updatedExercise.selectedExercise = WorkoutSessionExerciseSummary(
                    id: option.exerciseID,
                    name: option.exercise.name,
                    loadType: option.exercise.loadType
                )
                updatedExercise.plannedWorkingLoadValue = 80
                updatedExercise.progressionIncrement = 10
                updatedExercise.lockVersion = 5
                updatedExercise.workoutSessionSets[0].plannedLoadValue = 80
                updatedExercise.workoutSessionSets[1].plannedLoadValue = 80
                return updatedExercise
            }
        )

        let didSubstitute = await viewModel.substituteSelectedExercise(with: option)

        XCTAssertTrue(didSubstitute)
        XCTAssertEqual(viewModel.session.exercises[0].selectedExercise.name, "Incline Smith Press")
        XCTAssertEqual(viewModel.session.exercises[0].plannedWorkingLoadValue, 80)
        XCTAssertEqual(viewModel.session.exercises[0].lockVersion, 5)
        XCTAssertEqual(box.state?.session, viewModel.session)
    }

    @MainActor
    func testActiveWorkoutCreatesAndSelectsNewSubstitute() async {
        let templateID = UUID()
        let slotID = UUID()
        let exerciseID = UUID()
        let createdOption = workoutTemplateExerciseOptionFixture(
            exerciseID: exerciseID,
            name: "Incline Machine Press"
        )
        var session = workoutSessionFixture(templateID: templateID)
        session.exercises[0].workoutTemplateSlotID = slotID
        let template = workoutTemplateFixture(id: templateID, slotID: slotID)
        let box = ActiveWorkoutStoreBox(state: nil)
        var form = ExerciseFormState()
        form.name = "Incline Machine Press"
        form.primaryMuscleGroup = "Chest"
        form.loadType = .machineStack
        let viewModel = ActiveWorkoutViewModel(
            session: session,
            workoutTemplate: template,
            store: activeWorkoutStore(box: box),
            updateWorkoutSessionExercise: { _, payload in
                XCTAssertEqual(payload.workoutTemplateExerciseOptionID, createdOption.id)
                var updatedExercise = session.exercises[0]
                updatedExercise.workoutTemplateExerciseOptionID = createdOption.id
                updatedExercise.selectedExerciseID = createdOption.exerciseID
                updatedExercise.selectedExercise = WorkoutSessionExerciseSummary(
                    id: createdOption.exerciseID,
                    name: createdOption.exercise.name,
                    loadType: createdOption.exercise.loadType
                )
                updatedExercise.lockVersion += 1
                return updatedExercise
            },
            createExerciseOption: { payload in
                XCTAssertEqual(payload.workoutTemplateSlotID, slotID)
                XCTAssertEqual(payload.exerciseID, exerciseID)
                XCTAssertEqual(payload.exercise?.name, "Incline Machine Press")
                XCTAssertEqual(payload.exercise?.loadType, .machineStack)
                XCTAssertEqual(payload.startingLoadValue, 80)
                XCTAssertEqual(payload.progressionIncrement, 10)
                return createdOption
            }
        )

        let didAdd = await viewModel.addAndSelectSubstitute(
            exerciseID: exerciseID,
            form: form,
            startingLoadValue: 80,
            progressionIncrement: 10
        )

        XCTAssertTrue(didAdd)
        XCTAssertEqual(viewModel.session.exercises[0].selectedExercise.name, "Incline Machine Press")
        XCTAssertTrue(viewModel.workoutTemplate?.slots[0].exerciseOptions.contains(createdOption) == true)
        XCTAssertEqual(box.state?.session, viewModel.session)
    }

    @MainActor
    func testActiveWorkoutFinishPersistsLocallyWhenServerIsUnavailable() async {
        let box = ActiveWorkoutStoreBox(state: nil)
        var session = workoutSessionFixture()
        session.exercises[0].workoutSessionSets[0].actualReps = 7
        session.exercises[0].workoutSessionSets[0].actualLoadValue = 65
        session.exercises[0].workoutSessionSets[0].completionState = .completed
        session.exercises[0].workoutSessionSets[0].completedAt = "2026-10-03T12:00:00.000Z"
        let viewModel = ActiveWorkoutViewModel(
            session: session,
            store: activeWorkoutStore(box: box),
            now: { Date(timeIntervalSince1970: 0) },
            updateWorkoutSession: { _, _ in
                throw URLError(.notConnectedToInternet)
            }
        )

        let didFinish = await viewModel.finishWorkout()

        XCTAssertTrue(didFinish)
        XCTAssertEqual(viewModel.errorMessage, "Workout saved locally. Finish sync pending.")
        XCTAssertEqual(viewModel.pendingSyncCount, 1)
        XCTAssertEqual(viewModel.session.status, .completed)
        XCTAssertEqual(viewModel.session.completedAt, "1970-01-01T00:00:00.000Z")
        XCTAssertEqual(viewModel.session.exercises[0].status, .completed)
        XCTAssertEqual(viewModel.session.exercises[0].workoutSessionSets[0].completionState, .completed)
        XCTAssertEqual(viewModel.session.exercises[0].workoutSessionSets[1].completionState, .notPerformed)
        XCTAssertEqual(box.state?.session.status, .completed)
        XCTAssertEqual(box.state?.pendingSessionUpdate?.payload.lockVersion, session.lockVersion)
    }

    @MainActor
    func testActiveWorkoutFinishDoesNotSyncCompletionWhenSyncIssueExists() async {
        let session = workoutSessionFixture()
        let firstSet = session.exercises[0].workoutSessionSets[0]
        let pendingPayload = WorkoutSessionSetUpdatePayload(
            actualReps: 7,
            actualLoadValue: 65,
            completionState: .completed,
            completedAt: "2026-10-03T12:00:00.000Z",
            lockVersion: firstSet.lockVersion
        )
        let box = ActiveWorkoutStoreBox(
            state: ActiveWorkoutState(
                session: session,
                syncIssues: [
                    WorkoutSessionSetSyncIssue(
                        setID: firstSet.id,
                        payload: pendingPayload,
                        statusCode: 409
                    )
                ]
            )
        )
        let viewModel = ActiveWorkoutViewModel(
            session: session,
            store: activeWorkoutStore(box: box),
            now: { Date(timeIntervalSince1970: 0) },
            updateWorkoutSession: { _, _ in
                XCTFail("Completion sync should wait until set sync issues are resolved.")
                throw ActiveWorkoutStoreFailure.failed
            }
        )

        let didFinish = await viewModel.finishWorkout()

        XCTAssertTrue(didFinish)
        XCTAssertEqual(viewModel.errorMessage, "Some set syncs need attention.")
        XCTAssertEqual(viewModel.pendingSyncCount, 1)
        XCTAssertEqual(viewModel.syncIssueCount, 1)
        XCTAssertEqual(viewModel.session.status, .completed)
        XCTAssertEqual(box.state?.session.status, .completed)
        XCTAssertEqual(box.state?.pendingSessionUpdate?.payload.lockVersion, session.lockVersion)
        XCTAssertEqual(box.state?.syncIssues.count, 1)
    }

    @MainActor
    func testActiveWorkoutRetryPreservesPendingCompletionWhenSetSyncSucceedsBeforeFinishSyncFailure() async {
        var session = workoutSessionFixture()
        let firstSet = session.exercises[0].workoutSessionSets[0]
        let pendingUpdate = PendingWorkoutSessionSetUpdate(
            setID: firstSet.id,
            payload: WorkoutSessionSetUpdatePayload(
                actualReps: 7,
                actualLoadValue: 65,
                completionState: .completed,
                completedAt: "2026-10-03T12:00:00.000Z",
                lockVersion: firstSet.lockVersion
            )
        )
        session.exercises[0].workoutSessionSets[0].actualReps = pendingUpdate.payload.actualReps
        session.exercises[0].workoutSessionSets[0].actualLoadValue = pendingUpdate.payload.actualLoadValue
        session.exercises[0].workoutSessionSets[0].completionState = pendingUpdate.payload.completionState
        session.exercises[0].workoutSessionSets[0].completedAt = pendingUpdate.payload.completedAt
        let box = ActiveWorkoutStoreBox(
            state: ActiveWorkoutState(
                session: session,
                pendingSetUpdates: [pendingUpdate]
            )
        )
        let viewModel = ActiveWorkoutViewModel(
            session: session,
            store: activeWorkoutStore(box: box),
            now: { Date(timeIntervalSince1970: 0) },
            updateWorkoutSession: { _, _ in
                throw URLError(.notConnectedToInternet)
            },
            updateWorkoutSessionSet: { id, payload in
                XCTAssertEqual(id, pendingUpdate.setID)
                XCTAssertEqual(payload, pendingUpdate.payload)

                var syncedSet = firstSet
                syncedSet.actualReps = payload.actualReps
                syncedSet.actualLoadValue = payload.actualLoadValue
                syncedSet.completionState = payload.completionState
                syncedSet.completedAt = payload.completedAt
                syncedSet.lockVersion = payload.lockVersion + 1
                return syncedSet
            }
        )

        let didFinish = await viewModel.finishWorkout()

        XCTAssertTrue(didFinish)
        XCTAssertEqual(viewModel.errorMessage, "Workout saved locally. Finish sync pending.")
        XCTAssertEqual(viewModel.pendingSyncCount, 1)
        XCTAssertEqual(viewModel.syncIssueCount, 0)
        XCTAssertEqual(box.state?.pendingSetUpdates, [])
        XCTAssertEqual(box.state?.pendingSessionUpdate?.payload.lockVersion, session.lockVersion)
        XCTAssertEqual(box.state?.session.exercises[0].workoutSessionSets[0].lockVersion, firstSet.lockVersion + 1)
    }

    @MainActor
    func testActiveWorkoutFinishSyncClearsLocalActiveWorkoutState() async {
        let box = ActiveWorkoutStoreBox(state: nil)
        let session = workoutSessionFixture()
        let viewModel = ActiveWorkoutViewModel(
            session: session,
            store: activeWorkoutStore(box: box),
            now: { Date(timeIntervalSince1970: 0) },
            updateWorkoutSession: { id, payload in
                XCTAssertEqual(id, session.id)
                XCTAssertEqual(payload.status, .completed)
                XCTAssertEqual(payload.completedAt, "1970-01-01T00:00:00.000Z")
                XCTAssertEqual(payload.lockVersion, session.lockVersion)

                let completedAt = try XCTUnwrap(payload.completedAt)
                var syncedSession = session.finishingForTest(completedAt: completedAt)
                syncedSession.lockVersion = payload.lockVersion + 1
                return syncedSession
            }
        )

        let didFinish = await viewModel.finishWorkout()

        XCTAssertTrue(didFinish)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.pendingSyncCount, 0)
        XCTAssertEqual(viewModel.session.status, .completed)
        XCTAssertEqual(viewModel.session.lockVersion, 1)
        XCTAssertNil(box.state)
    }

    @MainActor
    func testActiveWorkoutRetryClearsPendingCompletionWhenServerAlreadyFinishedSession() async {
        let session = workoutSessionFixture()
        let completedAt = "2026-10-03T12:45:00.000Z"
        let pendingCompletion = PendingWorkoutSessionUpdate(
            sessionID: session.id,
            payload: WorkoutSessionStatusPayload(
                status: .completed,
                completedAt: completedAt,
                lockVersion: session.lockVersion
            )
        )
        let localCompletedSession = session.finishingForTest(completedAt: completedAt)
        var serverCompletedSession = localCompletedSession
        serverCompletedSession.lockVersion = session.lockVersion + 1
        let box = ActiveWorkoutStoreBox(
            state: ActiveWorkoutState(
                session: localCompletedSession,
                pendingSessionUpdate: pendingCompletion
            )
        )
        let viewModel = ActiveWorkoutViewModel(
            session: session,
            store: activeWorkoutStore(box: box),
            getWorkoutSession: { id in
                XCTAssertEqual(id, session.id)
                return serverCompletedSession
            },
            updateWorkoutSession: { id, payload in
                XCTAssertEqual(id, session.id)
                XCTAssertEqual(payload, pendingCompletion.payload)
                throw WorkoutSessionAPIError.requestFailed(statusCode: 409)
            }
        )

        await viewModel.retryPendingSessionUpdate()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.pendingSyncCount, 0)
        XCTAssertEqual(viewModel.session.status, .completed)
        XCTAssertEqual(viewModel.session.lockVersion, 1)
        XCTAssertNil(box.state)
    }

    @MainActor
    func testActiveWorkoutRetryKeepsPendingCompletionWhenServerFinishConflicts() async {
        let session = workoutSessionFixture()
        let completedAt = "2026-10-03T12:45:00.000Z"
        let pendingCompletion = PendingWorkoutSessionUpdate(
            sessionID: session.id,
            payload: WorkoutSessionStatusPayload(
                status: .completed,
                completedAt: completedAt,
                lockVersion: session.lockVersion
            )
        )
        let localCompletedSession = session.finishingForTest(completedAt: completedAt)
        var serverCompletedSession = localCompletedSession
        serverCompletedSession.completedAt = "2026-10-03T12:50:00.000Z"
        serverCompletedSession.lockVersion = session.lockVersion + 1
        let box = ActiveWorkoutStoreBox(
            state: ActiveWorkoutState(
                session: localCompletedSession,
                pendingSessionUpdate: pendingCompletion
            )
        )
        let viewModel = ActiveWorkoutViewModel(
            session: session,
            store: activeWorkoutStore(box: box),
            getWorkoutSession: { id in
                XCTAssertEqual(id, session.id)
                return serverCompletedSession
            },
            updateWorkoutSession: { _, _ in
                throw WorkoutSessionAPIError.requestFailed(statusCode: 409)
            }
        )

        await viewModel.retryPendingSessionUpdate()

        XCTAssertEqual(viewModel.errorMessage, "Workout finish sync needs attention.")
        XCTAssertEqual(viewModel.pendingSyncCount, 1)
        XCTAssertEqual(viewModel.session.completedAt, completedAt)
        XCTAssertEqual(box.state?.pendingSessionUpdate, pendingCompletion)
    }

    @MainActor
    func testWorkoutTemplatesStartWorkoutPersistsClientSnapshotBeforeNetworkSync() async throws {
        let template = offlineWorkoutTemplateFixture()
        let box = ActiveWorkoutStoreBox(state: nil)
        let identifiers = [UUID(), UUID(), UUID()]
        var remainingIdentifiers = identifiers
        let viewModel = WorkoutTemplatesViewModel(
            activeWorkoutStore: activeWorkoutStore(box: box),
            now: { Date(timeIntervalSince1970: 0) },
            makeID: { remainingIdentifiers.removeFirst() }
        )

        let startedSession = await viewModel.startWorkout(template: template)
        let session = try XCTUnwrap(startedSession)

        XCTAssertEqual(session.id, identifiers[0])
        XCTAssertEqual(session.exercises[0].id, identifiers[1])
        XCTAssertEqual(session.exercises[0].workoutSessionSets[0].id, identifiers[2])
        XCTAssertEqual(session.startedAt, "1970-01-01T00:00:00.000Z")
        XCTAssertEqual(viewModel.activeSession, session)
        XCTAssertEqual(viewModel.activeWorkoutTemplate, template)
        XCTAssertEqual(box.state?.session, session)
        XCTAssertEqual(box.state?.workoutTemplate, template)
        XCTAssertEqual(box.state?.pendingSessionCreation?.payload.id, session.id)
    }

    @MainActor
    func testActiveWorkoutCreatesServerSnapshotBeforeReplayingSetUpdates() async throws {
        let template = offlineWorkoutTemplateFixture()
        let draft = try WorkoutSessionDraft(template: template)
        let set = draft.session.exercises[0].workoutSessionSets[0]
        let pendingSetUpdate = PendingWorkoutSessionSetUpdate(
            setID: set.id,
            payload: WorkoutSessionSetUpdatePayload(
                actualReps: 8,
                actualLoadValue: 70,
                completionState: .completed,
                completedAt: "2026-10-03T12:30:00.000Z",
                lockVersion: set.lockVersion
            )
        )
        var localSession = draft.session
        localSession.exercises[0].workoutSessionSets[0].actualReps = pendingSetUpdate.payload.actualReps
        localSession.exercises[0].workoutSessionSets[0].actualLoadValue = pendingSetUpdate.payload.actualLoadValue
        localSession.exercises[0].workoutSessionSets[0].completionState = pendingSetUpdate.payload.completionState
        localSession.exercises[0].workoutSessionSets[0].completedAt = pendingSetUpdate.payload.completedAt
        let box = ActiveWorkoutStoreBox(
            state: ActiveWorkoutState(
                session: localSession,
                workoutTemplate: template,
                pendingSessionCreation: PendingWorkoutSessionCreation(payload: draft.payload),
                pendingSetUpdates: [pendingSetUpdate]
            )
        )
        var didCreateSession = false
        let viewModel = ActiveWorkoutViewModel(
            session: localSession,
            workoutTemplate: template,
            store: activeWorkoutStore(box: box),
            createWorkoutSession: { payload in
                XCTAssertEqual(payload, draft.payload)
                didCreateSession = true
                return draft.session
            },
            updateWorkoutSessionSet: { id, payload in
                XCTAssertTrue(didCreateSession)
                XCTAssertEqual(id, set.id)
                XCTAssertEqual(payload, pendingSetUpdate.payload)
                var syncedSet = set
                syncedSet.actualReps = payload.actualReps
                syncedSet.actualLoadValue = payload.actualLoadValue
                syncedSet.completionState = payload.completionState
                syncedSet.completedAt = payload.completedAt
                syncedSet.lockVersion += 1
                return syncedSet
            }
        )

        XCTAssertEqual(viewModel.pendingSyncCount, 2)

        await viewModel.retryPendingSync()

        XCTAssertTrue(didCreateSession)
        XCTAssertEqual(viewModel.pendingSyncCount, 0)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(box.state?.pendingSessionCreation)
        XCTAssertEqual(box.state?.pendingSetUpdates, [])
        XCTAssertEqual(box.state?.session.exercises[0].workoutSessionSets[0].lockVersion, 1)
    }

    @MainActor
    func testActiveWorkoutRetriesSessionCreationWithoutReplacingLocalProgress() async throws {
        let template = offlineWorkoutTemplateFixture()
        let draft = try WorkoutSessionDraft(template: template)
        var localSession = draft.session
        localSession.exercises[0].workoutSessionSets[0].actualReps = 8
        localSession.exercises[0].workoutSessionSets[0].actualLoadValue = 70
        localSession.exercises[0].workoutSessionSets[0].completionState = .completed
        localSession.exercises[0].workoutSessionSets[0].completedAt = "2026-10-03T12:30:00.000Z"
        let box = ActiveWorkoutStoreBox(
            state: ActiveWorkoutState(
                session: localSession,
                workoutTemplate: template,
                pendingSessionCreation: PendingWorkoutSessionCreation(payload: draft.payload)
            )
        )
        var attemptCount = 0
        let viewModel = ActiveWorkoutViewModel(
            session: localSession,
            workoutTemplate: template,
            store: activeWorkoutStore(box: box),
            createWorkoutSession: { _ in
                attemptCount += 1
                if attemptCount == 1 {
                    throw URLError(.notConnectedToInternet)
                }
                return draft.session
            }
        )

        await viewModel.retryPendingSessionCreation()

        XCTAssertEqual(viewModel.pendingSyncCount, 1)
        XCTAssertEqual(viewModel.errorMessage, "Workout saved locally. Start sync pending.")
        XCTAssertNotNil(box.state?.pendingSessionCreation)

        await viewModel.retryPendingSessionCreation()

        XCTAssertEqual(attemptCount, 2)
        XCTAssertEqual(viewModel.pendingSyncCount, 0)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.session, localSession)
        XCTAssertEqual(box.state?.session, localSession)
        XCTAssertNil(box.state?.pendingSessionCreation)
    }

    @MainActor
    func testWorkoutTemplatesStartWorkoutDoesNotOverwriteExistingActiveWorkoutState() async throws {
        let existingSession = workoutSessionFixture()
        let existingSet = existingSession.exercises[0].workoutSessionSets[0]
        let pendingUpdate = PendingWorkoutSessionSetUpdate(
            setID: existingSet.id,
            payload: WorkoutSessionSetUpdatePayload(
                actualReps: 7,
                actualLoadValue: 65,
                completionState: .completed,
                completedAt: "2026-10-03T12:00:00.000Z",
                lockVersion: existingSet.lockVersion
            )
        )
        let existingState = ActiveWorkoutState(
            session: existingSession,
            pendingSetUpdates: [pendingUpdate],
            syncIssues: [
                WorkoutSessionSetSyncIssue(
                    setID: existingSet.id,
                    payload: pendingUpdate.payload,
                    statusCode: 409
                )
            ]
        )
        let box = ActiveWorkoutStoreBox(state: existingState)
        let viewModel = WorkoutTemplatesViewModel(
            activeWorkoutStore: activeWorkoutStore(box: box)
        )

        let startedSession = await viewModel.startWorkout(template: workoutTemplateFixture())

        XCTAssertNil(startedSession)
        XCTAssertNil(viewModel.startingTemplateID)
        XCTAssertEqual(viewModel.activeSession, existingSession)
        XCTAssertEqual(viewModel.errorMessage, "Finish or cancel the active workout before starting another.")
        XCTAssertEqual(box.state, existingState)
    }

    private func activeWorkoutStore(box: ActiveWorkoutStoreBox) -> ActiveWorkoutStore {
        ActiveWorkoutStore(
            load: { box.state },
            save: { box.state = $0 },
            clear: { box.state = nil }
        )
    }

    private func workoutSessionFixture(
        id sessionID: UUID = UUID(),
        templateID: UUID = UUID()
    ) -> WorkoutSession {
        let exerciseID = UUID()
        let exerciseRowID = UUID()

        return WorkoutSession(
            id: sessionID,
            workoutTemplateID: templateID,
            workoutTemplateName: "Upper",
            status: .active,
            startedAt: "2026-10-03T12:00:00.000Z",
            completedAt: nil,
            canceledAt: nil,
            createdAt: "2026-10-03T12:00:00.000Z",
            updatedAt: "2026-10-03T12:00:00.000Z",
            lockVersion: 0,
            exercises: [
                WorkoutSessionExercise(
                    id: exerciseRowID,
                    workoutTemplateSlotID: nil,
                    workoutTemplateExerciseOptionID: nil,
                    position: 1,
                    label: "Incline Dumbbell Press",
                    selectedExerciseID: exerciseID,
                    selectedExercise: WorkoutSessionExerciseSummary(
                        id: exerciseID,
                        name: "Incline Dumbbell Press",
                        loadType: .lb
                    ),
                    restSeconds: 180,
                    plannedWorkingLoadValue: 65,
                    progressionIncrement: 5,
                    status: .pending,
                    lockVersion: 0,
                    createdAt: "2026-10-03T12:00:00.000Z",
                    updatedAt: "2026-10-03T12:00:00.000Z",
                    workoutSessionSets: [
                        workoutSessionSetFixture(position: 1),
                        workoutSessionSetFixture(position: 2)
                    ]
                )
            ]
        )
    }

    private func workoutSessionSetFixture(id: UUID = UUID(), position: Int) -> WorkoutSessionSet {
        WorkoutSessionSet(
            id: id,
            workoutTemplateSetPrescriptionID: nil,
            position: position,
            setType: .working,
            targetRepMin: 5,
            targetRepMax: 8,
            loadStrategy: .workingLoad,
            prescribedLoadValue: nil,
            plannedLoadValue: 65,
            actualReps: nil,
            actualLoadValue: nil,
            completionState: .pending,
            completedAt: nil,
            lockVersion: 0,
            createdAt: "2026-10-03T12:00:00.000Z",
            updatedAt: "2026-10-03T12:00:00.000Z"
        )
    }

    private func templateExerciseSummary(id: UUID, name: String) -> TemplateExerciseSummary {
        TemplateExerciseSummary(
            id: id,
            name: name,
            primaryMuscleGroup: "Chest",
            loadType: .lb,
            archivedAt: nil
        )
    }

    private func workoutTemplateFixture(
        id templateID: UUID = UUID(),
        slotID: UUID = UUID(),
        exerciseOptions: [WorkoutTemplateExerciseOption] = []
    ) -> WorkoutTemplate {
        let exerciseID = UUID()

        return WorkoutTemplate(
            id: templateID,
            name: "Lower",
            notes: nil,
            archivedAt: nil,
            createdAt: "2026-10-03T12:00:00.000Z",
            updatedAt: "2026-10-03T12:00:00.000Z",
            lockVersion: 0,
            slots: [
                WorkoutTemplateSlot(
                    id: slotID,
                    position: 1,
                    label: "Squat",
                    defaultExerciseID: exerciseID,
                    defaultExercise: TemplateExerciseSummary(
                        id: exerciseID,
                        name: "Squat",
                        primaryMuscleGroup: "Legs",
                        loadType: .lb,
                        archivedAt: nil
                    ),
                    restSeconds: 180,
                    createdAt: "2026-10-03T12:00:00.000Z",
                    updatedAt: "2026-10-03T12:00:00.000Z",
                    lockVersion: 0,
                    exerciseOptions: exerciseOptions,
                    setPrescriptions: []
                )
            ]
        )
    }

    private func offlineWorkoutTemplateFixture() -> WorkoutTemplate {
        let templateID = UUID()
        let slotID = UUID()
        let exerciseID = UUID()
        let prescriptionID = UUID()
        let exercise = TemplateExerciseSummary(
            id: exerciseID,
            name: "Back Squat",
            primaryMuscleGroup: "Legs",
            loadType: .lb,
            archivedAt: nil
        )
        let option = WorkoutTemplateExerciseOption(
            id: UUID(),
            position: 1,
            exerciseID: exerciseID,
            exercise: exercise,
            isDefault: true,
            startingLoadValue: 65,
            nextLoadValue: nil,
            calculatedNextLoadValue: 70,
            progressionIncrement: 5,
            plannedWorkingLoadValue: 70,
            plannedSessionSets: [
                WorkoutTemplateSessionSetPlan(
                    workoutTemplateSetPrescriptionID: prescriptionID,
                    plannedLoadValue: 70
                )
            ],
            createdAt: "2026-10-03T12:00:00.000Z",
            updatedAt: "2026-10-03T12:00:00.000Z"
        )
        let prescription = WorkoutTemplateSetPrescription(
            id: prescriptionID,
            position: 1,
            setType: .working,
            repMin: 5,
            repMax: 8,
            loadStrategy: .workingLoad,
            loadValue: nil,
            createdAt: "2026-10-03T12:00:00.000Z",
            updatedAt: "2026-10-03T12:00:00.000Z"
        )

        return WorkoutTemplate(
            id: templateID,
            name: "Lower",
            notes: nil,
            archivedAt: nil,
            createdAt: "2026-10-03T12:00:00.000Z",
            updatedAt: "2026-10-03T12:00:00.000Z",
            lockVersion: 0,
            slots: [
                WorkoutTemplateSlot(
                    id: slotID,
                    position: 1,
                    label: "Squat",
                    defaultExerciseID: exerciseID,
                    defaultExercise: exercise,
                    restSeconds: 180,
                    createdAt: "2026-10-03T12:00:00.000Z",
                    updatedAt: "2026-10-03T12:00:00.000Z",
                    lockVersion: 0,
                    exerciseOptions: [option],
                    setPrescriptions: [prescription]
                )
            ]
        )
    }

    private func workoutTemplateExerciseOptionFixture(
        exerciseID: UUID,
        name: String
    ) -> WorkoutTemplateExerciseOption {
        WorkoutTemplateExerciseOption(
            id: UUID(),
            position: 2,
            exerciseID: exerciseID,
            exercise: templateExerciseSummary(id: exerciseID, name: name),
            isDefault: false,
            startingLoadValue: 80,
            nextLoadValue: nil,
            calculatedNextLoadValue: nil,
            progressionIncrement: 10,
            createdAt: "2026-10-03T12:00:00.000Z",
            updatedAt: "2026-10-03T12:00:00.000Z"
        )
    }
}

private enum ActiveWorkoutStoreFailure: Error {
    case failed
}

private final class ActiveWorkoutStoreBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedState: ActiveWorkoutState?

    var state: ActiveWorkoutState? {
        get {
            lock.withLock {
                storedState
            }
        }
        set {
            lock.withLock {
                storedState = newValue
            }
        }
    }

    init(state: ActiveWorkoutState?) {
        storedState = state
    }
}

private final class URLRequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRequest: URLRequest?

    var request: URLRequest? {
        get {
            lock.withLock {
                storedRequest
            }
        }
        set {
            lock.withLock {
                storedRequest = newValue
            }
        }
    }
}

private final class URLProtocolStub: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension NSLock {
    func withLock<Result>(_ body: () -> Result) -> Result {
        lock()
        defer {
            unlock()
        }

        return body()
    }
}

private extension InputStream {
    func readData() throws -> Data {
        open()
        defer {
            close()
        }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)

        while hasBytesAvailable {
            let bytesRead = read(&buffer, maxLength: buffer.count)

            if bytesRead > 0 {
                data.append(buffer, count: bytesRead)
            } else if bytesRead < 0 {
                throw streamError ?? URLError(.cannotDecodeRawData)
            } else {
                break
            }
        }

        return data
    }
}

private extension WorkoutSession {
    func finishingForTest(completedAt: String) -> WorkoutSession {
        var updatedSession = self
        updatedSession.status = .completed
        updatedSession.completedAt = completedAt

        for exerciseIndex in updatedSession.exercises.indices {
            updatedSession.exercises[exerciseIndex].status = .skipped

            for setIndex in updatedSession.exercises[exerciseIndex].workoutSessionSets.indices {
                updatedSession.exercises[exerciseIndex].workoutSessionSets[setIndex].completionState = .notPerformed
            }
        }

        return updatedSession
    }
}
