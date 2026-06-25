import Foundation

/// Reads only the bytes appended to a file since a remembered offset.
/// Returns whole lines and the new offset (always at a line boundary), so a
/// partially-written trailing line is left for the next poll.
enum IncrementalFileReader {

    static func readNewLines(path: String, from offset: UInt64) -> (lines: [String], newOffset: UInt64) {
        guard let handle = FileHandle(forReadingAtPath: path) else {
            return ([], offset)
        }
        defer { try? handle.close() }

        let fileSize: UInt64 = (try? handle.seekToEnd()) ?? 0
        if fileSize <= offset {
            return ([], offset) // nothing new (or file truncated/rotated)
        }
        do {
            try handle.seek(toOffset: offset)
        } catch {
            return ([], offset)
        }
        let data = (try? handle.readToEnd()) ?? Data()
        guard !data.isEmpty else { return ([], offset) }

        // Consume up to and including the last newline.
        guard let lastNewline = data.lastIndex(of: 0x0A) else {
            return ([], offset) // no complete line yet
        }
        let consumed = data[..<(lastNewline + 1)]
        let newOffset = offset + UInt64(consumed.count)

        let text = String(decoding: consumed, as: UTF8.self)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        return (lines, newOffset)
    }
}

/// Lenient ISO-8601 parsing (with and without fractional seconds).
enum ISO8601 {
    // ISO8601DateFormatter parsing is internally thread-safe; these instances
    // are configured once and never mutated.
    nonisolated(unsafe) private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func date(from string: String) -> Date? {
        withFraction.date(from: string) ?? plain.date(from: string)
    }
}
