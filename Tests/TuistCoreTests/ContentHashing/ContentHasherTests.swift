import Path
import TuistSupport
import XCTest
@testable import TuistCore
@testable import TuistTesting

final class ContentHasherTests: TuistUnitTestCase {
    private var subject: ContentHasher!
    private var mockFileHandler: MockFileHandler!

    override func setUp() {
        super.setUp()
        mockFileHandler = MockFileHandler(temporaryDirectory: { try self.temporaryPath() })
        subject = ContentHasher(fileHandler: mockFileHandler)
    }

    override func tearDown() {
        subject = nil
        mockFileHandler = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_hashstring_foo_returnsItsMd5() throws {
        // Given
        let hash = try subject.hash("foo")

        // Then
        XCTAssertEqual(hash, "acbd18db4cc2f85cedef654fccc4a4d8") // This is the md5 of "foo"
    }

    func test_hashstring_bar_returnsItsMd5() throws {
        // Given
        let hash = try subject.hash("bar")

        // Then
        XCTAssertEqual(hash, "37b51d194a7513e45b56f6524f2d51f2") // This is the md5 of "bar"
    }

    func test_hashstrings_foo_bar_returnsAnotherMd5() throws {
        // Given
        let hash = try subject.hash(["foo", "bar"])

        // Then
        XCTAssertEqual(hash, "3858f62230ac3c915f300c664312c63f") // This is the md5 of "foobar"
    }

    func test_hashdict_returnsMd5OfConcatenation() throws {
        // Given
        let hash = try subject.hash(["1": "foo", "2": "bar"])
        let expectedHash = try subject.hash("1:foo-2:bar")
        // Then
        XCTAssertEqual(hash, expectedHash)
    }

    func test_hashFile_hashesTheExpectedFile() async throws {
        // Given
        let path = try writeToTemporaryPath(content: "foo")

        // When
        let hash = try await subject.hash(path: path)

        // Then
        XCTAssertEqual(hash, "acbd18db4cc2f85cedef654fccc4a4d8") // This is the md5 of "foo"
    }

    func test_hashFile_isNotHarcoded() async throws {
        // Given
        let path = try writeToTemporaryPath(content: "bar")

        // When
        let hash = try await subject.hash(path: path)

        // Then
        XCTAssertEqual(hash, "37b51d194a7513e45b56f6524f2d51f2") // This is the md5 of "bar"
    }

    func test_hashFile_whenFileDoesntExist_itThrowsFileNotFound() async throws {
        // Given
        let wrongPath = try AbsolutePath(validating: "/shakirashakira")

        // Then
        await XCTAssertThrowsSpecific(
            try await subject.hash(path: wrongPath),
            FileHandlerError.fileNotFound(wrongPath)
        )
    }

    func test_hash_sortedContentsOfADirectorySkippingDSStore() async throws {
        // given
        let folderPath = try temporaryPath().appending(component: "assets.xcassets")
        try mockFileHandler.createFolder(folderPath)

        let files = [
            "foo": "bar",
            "foo2": "bar2",
            ".ds_store": "should be ignored",
            ".DS_STORE": "should be ignored too",
        ]

        try writeFiles(to: folderPath, files: files)

        // When
        let hash = try await subject.hash(path: folderPath)

        // Then
        XCTAssertEqual(hash, "224e2539f52203eb33728acd228b4432-37b51d194a7513e45b56f6524f2d51f2")
        // This is the md5 of "bar", a dash, md5 of "bar2", in sorted order according to the file name
        // and .DS_STORE should be ignored
    }

    func test_hash_ContentsOfADirectoryIncludingSymbolicLinksWithRelativePaths() async throws {
        // Given
        try await fileSystem.runInTemporaryDirectory(prefix: UUID().uuidString) { temporaryDirectory in
            let symbolicPath = temporaryDirectory.appending(component: "symbolic")
            let destinationPath = temporaryDirectory.appending(component: "destination")
            try await fileSystem.writeText("destination", at: destinationPath)
            try await fileSystem.createSymbolicLink(from: symbolicPath, to: RelativePath(validating: "destination"))
            try await fileSystem.createSymbolicLink(
                from: temporaryDirectory.appending(component: "non-existent-symbolic"),
                to: RelativePath(validating: "non-existent")
            )
            try await fileSystem.writeText("foo", at: temporaryDirectory.appending(component: "foo.txt"))

            // When
            let hash = try await subject.hash(path: temporaryDirectory)

            // Then
            XCTAssertEqual(
                hash,
                "6990a54322d9232390a784c5c9247dd6-6990a54322d9232390a784c5c9247dd6-acbd18db4cc2f85cedef654fccc4a4d8"
            )
        }
    }

    // MARK: - Private

    private func writeToTemporaryPath(fileName: String = "foo", content: String = "foo") throws -> AbsolutePath {
        let path = try temporaryPath().appending(component: fileName)
        try mockFileHandler.write(content, path: path, atomically: true)
        return path
    }

    private func writeFiles(to folder: AbsolutePath, files: [String: String]) throws {
        for file in files {
            try mockFileHandler.write(file.value, path: folder.appending(component: file.key), atomically: true)
        }
    }
}
