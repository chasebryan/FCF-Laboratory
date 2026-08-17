import Darwin
import FCFPTY
import Foundation

@MainActor
final class TerminalSession: ObservableObject, Identifiable, @unchecked Sendable {
    let id: UUID
    let title: String
    let workingDirectory: URL

    @Published private(set) var output = ""
    @Published private(set) var isRunning = false
    @Published private(set) var failureMessage: String?

    private var masterFD: Int32 = -1
    private var childPID: pid_t = 0
    private var readSource: DispatchSourceRead?
    private var transcript = TerminalTranscript()

    init(id: UUID = UUID(), title: String = "Terminal", workingDirectory: URL) {
        self.id = id
        self.title = title
        self.workingDirectory = workingDirectory.standardizedFileURL
    }

    func start(columns: Int = 100, rows: Int = 30) {
        guard !isRunning else { return }

        var native = fcf_terminal_pty(master_fd: -1, child_pid: 0)
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let result = workingDirectory.path.withCString { cwd in
            shell.withCString { shellPath in
                fcf_terminal_pty_open(cwd, shellPath, Int32(columns), Int32(rows), &native)
            }
        }

        guard result == 0 else {
            failureMessage = "Unable to open terminal PTY (errno \(result))."
            return
        }

        masterFD = native.master_fd
        childPID = native.child_pid
        isRunning = true
        failureMessage = nil
        installReader(for: native.master_fd)
    }

    func send(_ data: Data) {
        guard isRunning, masterFD >= 0, !data.isEmpty else { return }
        data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            _ = fcf_terminal_pty_write(masterFD, base, bytes.count)
        }
    }

    func send(_ string: String) {
        send(Data(string.utf8))
    }

    func resize(columns: Int, rows: Int) {
        guard isRunning, masterFD >= 0 else { return }
        _ = fcf_terminal_pty_resize(masterFD, Int32(max(columns, 20)), Int32(max(rows, 4)))
    }

    func stop() {
        readSource?.cancel()
        readSource = nil
        if masterFD >= 0 {
            fcf_terminal_pty_close(masterFD)
            masterFD = -1
        }
        if childPID > 0 {
            var status: Int32 = 0
            _ = waitpid(childPID, &status, WNOHANG)
            childPID = 0
        }
        isRunning = false
    }

    private func installReader(for fd: Int32) {
        let source = DispatchSource.makeReadSource(
            fileDescriptor: fd,
            queue: DispatchQueue(label: "org.freecomputation.fcf-laboratory.pty.\(id.uuidString)", qos: .userInitiated)
        )

        source.setEventHandler { [weak self] in
            var bytes = [UInt8](repeating: 0, count: 8_192)
            let count = bytes.withUnsafeMutableBytes { buffer -> Int in
                guard let base = buffer.baseAddress else { return 0 }
                return Int(fcf_terminal_pty_read(fd, base, buffer.count))
            }

            if count > 0 {
                let chunk = String(decoding: bytes.prefix(count), as: UTF8.self)
                Task { @MainActor [weak self] in
                    self?.append(chunk)
                }
            } else if count == 0 || count < -2 {
                Task { @MainActor [weak self] in
                    self?.finishAfterEOF()
                }
            }
        }

        source.setCancelHandler {}
        readSource = source
        source.resume()
    }

    private func append(_ chunk: String) {
        transcript.ingest(chunk)
        output = transcript.value
    }

    private func finishAfterEOF() {
        guard isRunning else { return }
        readSource?.cancel()
        readSource = nil
        if masterFD >= 0 {
            fcf_terminal_pty_close(masterFD)
            masterFD = -1
        }
        if childPID > 0 {
            var status: Int32 = 0
            _ = waitpid(childPID, &status, WNOHANG)
            childPID = 0
        }
        isRunning = false
    }
}

private struct TerminalTranscript {
    private enum EscapeState {
        case normal
        case escape
        case csi
        case osc
        case oscEscape
    }

    private(set) var value = ""
    private var state: EscapeState = .normal
    private let maxCharacters = 2_000_000
    private let trimCharacters = 400_000

    mutating func ingest(_ chunk: String) {
        for scalar in chunk.unicodeScalars {
            switch state {
            case .normal:
                switch scalar.value {
                case 0x1B:
                    state = .escape
                case 0x08:
                    if !value.isEmpty, value.last != "\n" { value.removeLast() }
                case 0x0D:
                    if value.last != "\n" { value.append("\n") }
                case 0x0A, 0x09:
                    value.unicodeScalars.append(scalar)
                case 0x20...0x10FFFF:
                    value.unicodeScalars.append(scalar)
                default:
                    break
                }
            case .escape:
                if scalar == "[" {
                    state = .csi
                } else if scalar == "]" {
                    state = .osc
                } else {
                    state = .normal
                }
            case .csi:
                if scalar.value >= 0x40 && scalar.value <= 0x7E {
                    state = .normal
                }
            case .osc:
                if scalar.value == 0x07 {
                    state = .normal
                } else if scalar.value == 0x1B {
                    state = .oscEscape
                }
            case .oscEscape:
                state = scalar == "\\" ? .normal : .osc
            }
        }

        if value.count > maxCharacters {
            let index = value.index(value.startIndex, offsetBy: min(trimCharacters, value.count))
            value.removeSubrange(value.startIndex..<index)
            value.insert(contentsOf: "[older terminal output trimmed]\n", at: value.startIndex)
        }
    }
}
