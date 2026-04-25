import Foundation

/// Async reader for a Unix domain socket. Reads line-delimited JSON messages.
actor SocketClient {
    private let socketPath: String
    private var fileDescriptor: Int32 = -1

    init(socketPath: String) {
        self.socketPath = socketPath
    }

    func connect() throws {
        fileDescriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fileDescriptor >= 0 else {
            throw SocketError.createFailed
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let pathPtr = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self)
            socketPath.withCString { src in
                _ = strcpy(pathPtr, src)
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let result = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.connect(fileDescriptor, sockaddrPtr, addrLen)
            }
        }

        guard result == 0 else {
            close(fileDescriptor)
            fileDescriptor = -1
            throw SocketError.connectFailed(errno: errno)
        }
    }

    func disconnect() {
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    /// Reads lines from the socket as an async stream.
    nonisolated func lines() -> AsyncStream<String> {
        AsyncStream { continuation in
            let task = Task {
                var buffer = Data()
                let chunkSize = 4096
                let readBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
                defer { readBuf.deallocate() }

                while !Task.isCancelled {
                    let fd = await self.fileDescriptor
                    guard fd >= 0 else { break }

                    let bytesRead = read(fd, readBuf, chunkSize)
                    if bytesRead <= 0 { break }

                    buffer.append(readBuf, count: bytesRead)

                    // Extract complete lines (delimited by newline)
                    while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                        let lineData = buffer[buffer.startIndex..<newlineIndex]
                        buffer = Data(buffer[(newlineIndex + 1)...])
                        if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                            continuation.yield(line)
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

enum SocketError: Error, LocalizedError {
    case createFailed
    case connectFailed(errno: Int32)

    var errorDescription: String? {
        switch self {
        case .createFailed: "Failed to create socket"
        case .connectFailed(let e): "Failed to connect: \(String(cString: strerror(e)))"
        }
    }
}
