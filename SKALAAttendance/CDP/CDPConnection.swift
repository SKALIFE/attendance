import Foundation

protocol CDPTransport: Sendable {
    func send(_ data: Data) async throws
    func receive() async throws -> Data
    func close() async
}

protocol CDPWebSocketTask: Sendable {
    func resume() async
    func send(_ message: URLSessionWebSocketTask.Message) async throws
    func receive() async throws -> URLSessionWebSocketTask.Message
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) async
}

extension URLSessionWebSocketTask: CDPWebSocketTask {}

actor URLSessionWebSocketTransport: CDPTransport {
    private let session: URLSession
    private let task: any CDPWebSocketTask
    private var pendingReceives: [UUID: CheckedContinuation<Data, any Error>] = [:]
    private var receiveTask: Task<Void, Never>?
    private var isClosed = false

    init(url: URL) {
        let session = URLSession(configuration: .ephemeral)
        self.session = session
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
    }

    init(session: URLSession, task: any CDPWebSocketTask) async {
        self.session = session
        self.task = task
        await task.resume()
    }

    func send(_ data: Data) async throws {
        guard !isClosed else {
            throw CDPClientError.connectionClosed
        }
        guard let message = String(data: data, encoding: .utf8) else {
            throw CDPClientError.invalidMessage
        }
        try await task.send(.string(message))
    }

    func receive() async throws -> Data {
        guard !isClosed else {
            throw CDPClientError.connectionClosed
        }

        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !isClosed else {
                    continuation.resume(throwing: CDPClientError.connectionClosed)
                    return
                }
                pendingReceives[id] = continuation
                startReceiveIfNeeded()
            }
        } onCancel: {
            Task { await self.cancelPendingReceive(id: id) }
        }
    }

    func close() async {
        guard !isClosed else { return }
        isClosed = true
        receiveTask?.cancel()
        receiveTask = nil
        await task.cancel(with: .goingAway, reason: nil)
        failPendingReceives(with: CDPClientError.connectionClosed)
    }

    private func startReceiveIfNeeded() {
        guard !isClosed, receiveTask == nil, !pendingReceives.isEmpty else { return }

        let task = task
        receiveTask = Task { [weak self, task] in
            do {
                let message = try await task.receive()
                await self?.handle(message)
            } catch {
                await self?.handle(error)
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) async {
        receiveTask = nil
        guard !isClosed else { return }

        let data: Data
        switch message {
        case .data(let value):
            data = value
        case .string(let value):
            data = Data(value.utf8)
        @unknown default:
            await closeAfterFailure(CDPClientError.invalidMessage)
            return
        }

        guard let id = pendingReceives.keys.first,
              let continuation = pendingReceives.removeValue(forKey: id) else {
            return
        }
        continuation.resume(returning: data)
        startReceiveIfNeeded()
    }

    private func handle(_ error: any Error) async {
        receiveTask = nil
        await closeAfterFailure(error)
    }

    private func cancelPendingReceive(id: UUID) {
        guard let continuation = pendingReceives.removeValue(forKey: id) else { return }
        continuation.resume(throwing: CancellationError())
    }

    private func closeAfterFailure(_ error: any Error) async {
        guard !isClosed else { return }
        isClosed = true
        await task.cancel(with: .goingAway, reason: nil)
        failPendingReceives(with: error)
    }

    private func failPendingReceives(with error: any Error) {
        let continuations = pendingReceives.values
        pendingReceives.removeAll()
        continuations.forEach { $0.resume(throwing: error) }
    }
}
