import XCTest
@testable import QuotaLens

final class IncrementalFileReaderTests: XCTestCase {

    private var directory: URL!
    private var path: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuotaLensTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        path = directory.appendingPathComponent("events.jsonl").path
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    /// Atomically replaces the file, standing in for compaction/rotation.
    private func write(_ contents: String) {
        try! contents.write(toFile: path, atomically: true, encoding: .utf8)
    }

    func testReadsOnlyNewlyAppendedLines() {
        write("a\n")
        let (lines, offset) = IncrementalFileReader.readNewLines(path: path, from: 0)
        XCTAssertEqual(lines, ["a"])

        write("a\nb\n")
        let (appended, _) = IncrementalFileReader.readNewLines(path: path, from: offset)
        XCTAssertEqual(appended, ["b"], "Only the appended line should be returned")
    }

    func testTruncatedFileIsRereadFromStart() {
        write("a\nb\nc\n")
        let (lines, offset) = IncrementalFileReader.readNewLines(path: path, from: 0)
        XCTAssertEqual(lines.count, 3)
        XCTAssertGreaterThan(offset, 0)

        write("d\n") // file shrank — a stale offset would stall this file forever
        let (afterTruncate, newOffset) = IncrementalFileReader.readNewLines(path: path, from: offset)
        XCTAssertEqual(afterTruncate, ["d"], "A truncated file must be re-read from offset 0")
        XCTAssertEqual(newOffset, 2)
    }

    func testPartialTrailingLineIsDeferred() {
        write("a\nb") // last line not terminated yet
        let (lines, offset) = IncrementalFileReader.readNewLines(path: path, from: 0)
        XCTAssertEqual(lines, ["a"], "An unterminated trailing line waits for the next poll")
        XCTAssertEqual(offset, 2)

        write("a\nb\n")
        let (completed, _) = IncrementalFileReader.readNewLines(path: path, from: offset)
        XCTAssertEqual(completed, ["b"])
    }

    func testNoNewDataKeepsOffset() {
        write("a\n")
        let (_, offset) = IncrementalFileReader.readNewLines(path: path, from: 0)
        let (lines, unchanged) = IncrementalFileReader.readNewLines(path: path, from: offset)
        XCTAssertTrue(lines.isEmpty)
        XCTAssertEqual(unchanged, offset)
    }
}
