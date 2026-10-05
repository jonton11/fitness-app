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
        let payload = WorkoutSessionFinishPayload(
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

        let session = try await apiClient.finishWorkoutSession(id: sessionID, payload: payload)

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
            finishWorkoutSession: { _, _ in
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
        XCTAssertEqual(box.state?.pendingSessionCompletion?.payload.lockVersion, session.lockVersion)
    }

    @MainActor
    func testActiveWorkoutFinishSyncClearsLocalActiveWorkoutState() async {
        let box = ActiveWorkoutStoreBox(state: nil)
        let session = workoutSessionFixture()
        let viewModel = ActiveWorkoutViewModel(
            session: session,
            store: activeWorkoutStore(box: box),
            now: { Date(timeIntervalSince1970: 0) },
            finishWorkoutSession: { id, payload in
                XCTAssertEqual(id, session.id)
                XCTAssertEqual(payload.status, .completed)
                XCTAssertEqual(payload.completedAt, "1970-01-01T00:00:00.000Z")
                XCTAssertEqual(payload.lockVersion, session.lockVersion)

                var syncedSession = session.finishingForTest(completedAt: payload.completedAt)
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
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let sessionAPIClient = WorkoutSessionAPIClient(
            baseURL: URL(string: "https://fitness.example")!,
            session: URLSession(configuration: configuration)
        )
        let viewModel = WorkoutTemplatesViewModel(
            sessionAPIClient: sessionAPIClient,
            activeWorkoutStore: activeWorkoutStore(box: box)
        )

        URLProtocolStub.requestHandler = { _ in
            XCTFail("Starting a new workout should not call the API while active local state exists.")
            throw URLError(.badServerResponse)
        }
        defer {
            URLProtocolStub.requestHandler = nil
        }

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

    private func workoutSessionFixture(templateID: UUID = UUID()) -> WorkoutSession {
        let sessionID = UUID()
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

    private func workoutTemplateFixture() -> WorkoutTemplate {
        let templateID = UUID()
        let exerciseID = UUID()
        let slotID = UUID()

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
                    exerciseOptions: [],
                    setPrescriptions: []
                )
            ]
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
