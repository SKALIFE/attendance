import XCTest
import Foundation
@testable import SKALAAttendance

final class CDPTests: XCTestCase {
    actor FakeCDPTransport: CDPTransport {
        private(set) var sent: [Data] = []
        private var responses: [Data]
        private(set) var closed = false

        init(responses: [String]) {
            self.responses = responses.map { Data($0.utf8) }
        }

        func send(_ data: Data) async throws {
            sent.append(data)
        }

        func receive() async throws -> Data {
            while responses.isEmpty && !closed {
                try await Task.sleep(for: .milliseconds(10))
            }
            if closed {
                throw CDPClientError.connectionClosed
            }
            return responses.removeFirst()
        }

        func sentCount() -> Int {
            sent.count
        }

        func close() async {
            closed = true
        }

        func sentData() -> [Data] {
            sent
        }
    }

    actor FakeWebSocketTask: CDPWebSocketTask {
        private var messages: [URLSessionWebSocketTask.Message]
        private var sentMessages: [URLSessionWebSocketTask.Message] = []
        private var pendingReceive: CheckedContinuation<URLSessionWebSocketTask.Message, any Error>?
        private var wasResumed = false
        private var wasCancelled = false

        init(messages: [URLSessionWebSocketTask.Message]) {
            self.messages = messages
        }

        func resume() async {
            wasResumed = true
        }

        func send(_ message: URLSessionWebSocketTask.Message) async throws {
            sentMessages.append(message)
        }

        func receive() async throws -> URLSessionWebSocketTask.Message {
            if wasCancelled {
                throw CDPClientError.connectionClosed
            }
            if !messages.isEmpty {
                return messages.removeFirst()
            }
            return try await withCheckedThrowingContinuation { continuation in
                pendingReceive = continuation
            }
        }

        func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) async {
            wasCancelled = true
            pendingReceive?.resume(throwing: CDPClientError.connectionClosed)
            pendingReceive = nil
        }

        func isReceivePending() -> Bool {
            pendingReceive != nil
        }

        func lifecycleState() -> (resumed: Bool, cancelled: Bool) {
            (wasResumed, wasCancelled)
        }

        func sent() -> [URLSessionWebSocketTask.Message] {
            sentMessages
        }
    }

    func testCDPClient_whenEncodingCommands_incrementsJSONRPCIDs() async throws {
        let client = CDPClient(baseURL: URL(string: "http://127.0.0.1:1234")!)

        let first = try await json(client.encode(.pageEnable))
        let second = try await json(client.encode(.pageReload))

        XCTAssertEqual(first["id"] as? Int, 1)
        XCTAssertEqual(first["method"] as? String, "Page.enable")
        XCTAssertEqual(second["id"] as? Int, 2)
        XCTAssertEqual(second["method"] as? String, "Page.reload")
    }

    func testMobileEmulationProfile_whenBuilt_usesAndroidChromeAndClientHints() {
        let profile = MobileEmulationProfile()

        let ua = profile.userAgent(chromeMajorVersion: 150)
        let command = profile.userAgentCommand(chromeMajorVersion: 150)

        XCTAssertTrue(ua.contains("Android 15"))
        XCTAssertTrue(ua.contains("Chrome/150.0.0.0"))
        XCTAssertEqual(command.method, "Emulation.setUserAgentOverride")
        XCTAssertEqual(command.params["platform"], .string("Android"))
        XCTAssertNotNil(command.params["userAgentMetadata"])
    }

    func testCDPClient_whenSendingCommand_usesTransportAndMatchesResponseID() async throws {
        let transport = FakeCDPTransport(responses: [#"{"id":1,"result":{"frameId":"frame-1"}}"#])
        let client = CDPClient(baseURL: URL(string: "http://127.0.0.1:1234")!, transport: transport)

        let response = try await client.send(.navigate(to: AppConstants.attendanceURL))

        let sentCount = await transport.sentCount()
        XCTAssertEqual(sentCount, 1)
        XCTAssertEqual(response.id, 1)
        XCTAssertEqual(response.result["frameId"], .string("frame-1"))
    }

    func testCDPClient_whenReceivingEventBeforeResponse_ignoresEventAndMatchesResponse() async throws {
        let transport = FakeCDPTransport(responses: [
            #"{"method":"Page.loadEventFired","params":{"timestamp":1.0}}"#,
            #"{"id":1,"result":{"frameId":"frame-1"}}"#
        ])
        let client = CDPClient(baseURL: URL(string: "http://127.0.0.1:1234")!, transport: transport)

        let response = try await client.send(.navigate(to: AppConstants.attendanceURL))

        XCTAssertEqual(response.id, 1)
        XCTAssertEqual(response.result["frameId"], .string("frame-1"))
    }

    func testCDPClient_whenResponseDoesNotArrive_timesOutAndClosesTransport() async throws {
        let transport = FakeCDPTransport(responses: [])
        let client = CDPClient(baseURL: URL(string: "http://127.0.0.1:1234")!, transport: transport)

        do {
            _ = try await client.send(.pageReload, timeout: .milliseconds(20))
            XCTFail("Expected command timeout")
        } catch let error as CDPClientError {
            XCTAssertEqual(error, .commandTimedOut(1))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        await client.close()
        let closed = await transport.closed
        XCTAssertTrue(closed)
    }

    func testCDPClient_whenSendTaskIsCancelled_resumesWithCancellationError() async throws {
        let transport = FakeCDPTransport(responses: [])
        let client = CDPClient(baseURL: URL(string: "http://127.0.0.1:1234")!, transport: transport)

        let task = Task {
            try await client.send(.pageReload, timeout: .seconds(5))
        }
        while await transport.sentCount() == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }

        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected command cancellation")
        } catch is CancellationError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWindowController_whenSettingBounds_usesWindowIDFromTarget() async throws {
        let transport = FakeCDPTransport(responses: [
            #"{"id":1,"result":{"windowId":42}}"#,
            #"{"id":2,"result":{}}"#,
            #"{"id":3,"result":{"windowId":42,"bounds":{"left":12,"top":24,"width":430,"height":900}}}"#
        ])
        let client = CDPClient(baseURL: URL(string: "http://127.0.0.1:1234")!, transport: transport)
        let controller = CDPWindowController(client: client)

        let appliedBounds = try await controller.setBounds(WindowBounds(x: 10, y: 20, width: 430, height: 900))

        let sent = try await transport.sentData().map(json)
        XCTAssertEqual(sent.map { $0["method"] as? String }, ["Browser.getWindowForTarget", "Browser.setWindowBounds", "Browser.getWindowForTarget"])
        XCTAssertEqual(sent[1]["id"] as? Int, 2)
        let params = try XCTUnwrap(sent[1]["params"] as? [String: Any])
        XCTAssertEqual(params["windowId"] as? Int, 42)
        let bounds = try XCTUnwrap(params["bounds"] as? [String: Any])
        XCTAssertEqual(bounds["width"] as? Int, 430)
        XCTAssertEqual(appliedBounds, WindowBounds(x: 12, y: 24, width: 430, height: 900))
    }

    func testWindowController_whenReadingCurrentBounds_decodesCDPBounds() async throws {
        let transport = FakeCDPTransport(responses: [
            #"{"id":1,"result":{"windowId":42,"bounds":{"left":11,"top":22,"width":430,"height":900}}}"#
        ])
        let client = CDPClient(baseURL: URL(string: "http://127.0.0.1:1234")!, transport: transport)
        let controller = CDPWindowController(client: client)

        let bounds = try await controller.currentBounds()

        XCTAssertEqual(bounds, WindowBounds(x: 11, y: 22, width: 430, height: 900))
    }

    func testNavigationCommand_whenCreated_targetsAttendanceURLOnlyAfterEmulation() {
        let command = CDPCommand.navigate(to: AppConstants.attendanceURL)

        XCTAssertEqual(command.method, "Page.navigate")
        XCTAssertEqual(command.params["url"], .string("https://att.skala-ai.com/"))
    }

    func testCreateTargetCommand_whenCreated_usesAboutBlankURL() {
        let command = CDPCommand.createTarget(url: URL(string: "about:blank")!)

        XCTAssertEqual(command.method, "Target.createTarget")
        XCTAssertEqual(command.params["url"], .string("about:blank"))
    }

    func testURLSessionWebSocketTransport_whenReceivingStringAndData_returnsData() async throws {
        let task = FakeWebSocketTask(messages: [
            .string(#"{"id":1}"#),
            .data(Data(#"{"id":2}"#.utf8))
        ])
        let transport = await URLSessionWebSocketTransport(
            session: URLSession(configuration: .ephemeral),
            task: task
        )

        let stringMessage = try await transport.receive()
        let dataMessage = try await transport.receive()
        try await transport.send(Data(#"{"id":3}"#.utf8))
        let lifecycle = await task.lifecycleState()
        let sent = await task.sent()

        XCTAssertEqual(stringMessage, Data(#"{"id":1}"#.utf8))
        XCTAssertEqual(dataMessage, Data(#"{"id":2}"#.utf8))
        guard case .string(#"{"id":3}"#)? = sent.first else {
            return XCTFail("Expected CDP payload to use a text WebSocket frame")
        }
        XCTAssertTrue(lifecycle.resumed)
        XCTAssertFalse(lifecycle.cancelled)
    }

    func testURLSessionWebSocketTransport_whenSendingInvalidUTF8_throwsInvalidMessage() async throws {
        let task = FakeWebSocketTask(messages: [])
        let transport = await URLSessionWebSocketTransport(
            session: URLSession(configuration: .ephemeral),
            task: task
        )

        do {
            try await transport.send(Data([0xC3, 0x28]))
            XCTFail("Expected invalid UTF-8 to be rejected")
        } catch let error as CDPClientError {
            XCTAssertEqual(error, .invalidMessage)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let sent = await task.sent()
        XCTAssertTrue(sent.isEmpty)
    }

    func testURLSessionWebSocketTransport_whenClosed_resumesPendingReceiveAndCancelsTask() async throws {
        let task = FakeWebSocketTask(messages: [])
        let transport = await URLSessionWebSocketTransport(
            session: URLSession(configuration: .ephemeral),
            task: task
        )
        let firstReceive = Task { try await transport.receive() }

        while !(await task.isReceivePending()) {
            try await Task.sleep(for: .milliseconds(10))
        }
        let secondReceive = Task { try await transport.receive() }
        try await Task.sleep(for: .milliseconds(10))
        await transport.close()

        for receive in [firstReceive, secondReceive] {
            do {
                _ = try await receive.value
                XCTFail("Expected pending receive to close")
            } catch let error as CDPClientError {
                XCTAssertEqual(error, .connectionClosed)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
        let lifecycle = await task.lifecycleState()
        XCTAssertTrue(lifecycle.cancelled)
    }

    private func json(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
