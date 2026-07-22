import Foundation

actor CDPClient {
    private let baseURL: URL
    private var transport: (any CDPTransport)?
    private var nextID = 1
    private var pending: [Int: CheckedContinuation<CDPResponse, any Error>] = [:]
    private var responseBacklog: [Int: CDPResponse] = [:]
    private var receiveTask: Task<Void, Never>?
    private var eventSubscribers: [(CDPEvent) -> Void] = []

    init(baseURL: URL, transport: (any CDPTransport)? = nil) {
        self.baseURL = baseURL
        self.transport = transport
    }

    func subscribeToEvents(_ handler: @escaping (CDPEvent) -> Void) {
        eventSubscribers.append(handler)
    }

    func connect(to webSocketURL: URL) {
        transport = URLSessionWebSocketTransport(url: webSocketURL)
        startReceiveLoopIfNeeded()
    }

    func encode(_ command: CDPCommand) throws -> Data {
        let requestID = nextRequestID()
        return try encode(command, id: requestID)
    }

    private func encode(_ command: CDPCommand, id: Int) throws -> Data {
        let payload: [String: Any] = [
            "id": id,
            "method": command.method,
            "params": command.params.jsonObject
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    }

    @discardableResult
    func send(_ command: CDPCommand, timeout: Duration = .seconds(5)) async throws -> CDPResponse {
        guard let transport else {
            throw CDPClientError.notConnected
        }
        let requestID = nextRequestID()
        let data = try encode(command, id: requestID)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CDPResponse, any Error>) in
                pending[requestID] = continuation
                startReceiveLoopIfNeeded()
                Task {
                    do {
                        try await transport.send(data)
                        deliverBackloggedResponse(id: requestID)
                        try await Task.sleep(for: timeout)
                        timeoutPendingResponse(id: requestID)
                    } catch {
                        failPendingResponse(id: requestID, error: error)
                    }
                }
            }
            .checkedForCommandError()
        } onCancel: {
            Task { await cancelPendingResponse(id: requestID) }
        }
    }

    func close() async {
        receiveTask?.cancel()
        receiveTask = nil
        pending.values.forEach { $0.resume(throwing: CDPClientError.connectionClosed) }
        pending.removeAll()
        responseBacklog.removeAll()
        await transport?.close()
        transport = nil
    }

    func versionEndpoint() -> URL {
        baseURL.appendingPathComponent("json/version")
    }

    func listEndpoint() -> URL {
        baseURL.appendingPathComponent("json/list")
    }

    private func nextRequestID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    private func startReceiveLoopIfNeeded() {
        guard receiveTask == nil else { return }
        receiveTask = Task { [weak self] in
            guard let self else { return }
            await self.receiveLoop()
        }
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            guard let transport else {
                failPending(with: CDPClientError.notConnected)
                return
            }
            do {
                guard let response = try decodeResponse(try await transport.receive()) else {
                    continue
                }
                resolve(response)
            } catch {
                failPending(with: error)
                return
            }
        }
    }

    private func cancelPendingResponse(id: Int) {
        guard let continuation = pending.removeValue(forKey: id) else {
            return
        }
        continuation.resume(throwing: CancellationError())
    }

    private func timeoutPendingResponse(id: Int) {
        guard let continuation = pending.removeValue(forKey: id) else {
            return
        }
        continuation.resume(throwing: CDPClientError.commandTimedOut(id))
    }

    private func failPendingResponse(id: Int, error: any Error) {
        guard let continuation = pending.removeValue(forKey: id) else {
            return
        }
        continuation.resume(throwing: error)
    }

    private func deliverBackloggedResponse(id: Int) {
        guard let response = responseBacklog.removeValue(forKey: id) else {
            return
        }
        resolve(response)
    }

    private func resolve(_ response: CDPResponse) {
        guard let continuation = pending.removeValue(forKey: response.id) else {
            responseBacklog[response.id] = response
            return
        }
        continuation.resume(returning: response)
    }

    private func failPending(with error: any Error) {
        let continuations = pending.values
        pending.removeAll()
        continuations.forEach { $0.resume(throwing: error) }
    }

    private func decodeResponse(_ data: Data) throws -> CDPResponse? {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CDPClientError.invalidMessage
        }
        if let id = object["id"] as? Int {
            let resultObject = object["result"] as? [String: Any] ?? [:]
            let errorObject = object["error"] as? [String: Any]
            let error = errorObject.flatMap { object -> CDPError? in
                guard let code = object["code"] as? Int,
                      let message = object["message"] as? String else {
                    return nil
                }
                return CDPError(code: code, message: message)
            }
            return CDPResponse(id: id, result: resultObject.cdpValues, error: error)
        }
        if let method = object["method"] as? String {
            let params = (object["params"] as? [String: Any] ?? [:]).cdpValues
            let event = CDPEvent(method: method, params: params)
            eventSubscribers.forEach { $0(event) }
        }
        return nil
    }
}

private extension CDPResponse {
    func checkedForCommandError() throws -> CDPResponse {
        if let error {
            throw CDPClientError.commandFailed(error)
        }
        return self
    }
}

private extension Dictionary where Key == String, Value == CDPValue {
    var jsonObject: [String: Any] {
        mapValues { $0.jsonObject }
    }
}

private extension Dictionary where Key == String, Value == Any {
    var cdpValues: [String: CDPValue] {
        compactMapValues { CDPValue(jsonObject: $0) }
    }
}

private extension CDPValue {
    init?(jsonObject: Any) {
        switch jsonObject {
        case let value as String:
            self = .string(value)
        case let value as Int:
            self = .int(value)
        case let value as Double:
            self = .double(value)
        case let value as Bool:
            self = .bool(value)
        case let value as [String: Any]:
            self = .object(value.cdpValues)
        case let value as [Any]:
            self = .array(value.compactMap(CDPValue.init(jsonObject:)))
        default:
            return nil
        }
    }

    var jsonObject: Any {
        switch self {
        case .string(let value): value
        case .int(let value): value
        case .double(let value): value
        case .bool(let value): value
        case .object(let value): value.jsonObject
        case .array(let value): value.map(\.jsonObject)
        }
    }
}
