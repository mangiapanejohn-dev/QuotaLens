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
        // A file smaller than the remembered offset was truncated or replaced
        // (compaction, rotation). Restart from the top: keeping the stale offset
        // would block every future read of this file. Callers de-dupe by
        // `dedupeKey`, so re-reading already-seen lines is safe.
        var start = offset
        if fileSize < offset {
            start = 0
        } else if fileSize == offset {
            return ([], offset) // nothing new
        }
        do {
            try handle.seek(toOffset: start)
        } catch {
            return ([], start)
        }
        let data = (try? handle.readToEnd()) ?? Data()
        guard !data.isEmpty else { return ([], start) }

        // Consume up to and including the last newline.
        guard let lastNewline = data.lastIndex(of: 0x0A) else {
            return ([], start) // no complete line yet
        }
        let consumed = data[..<(lastNewline + 1)]
        let newOffset = start + UInt64(consumed.count)

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
