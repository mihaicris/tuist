import Path
import TuistSupport
import XcodeGraph
import XCTest
@testable import TuistCore
@testable import TuistTesting

final class FrameworkLoaderErrorTests: TuistUnitTestCase {
    func test_type_when_frameworkNotFound() {
        // Given
        let path = try! AbsolutePath(validating: "/frameworks/tuist.framework")
        let subject = FrameworkLoaderError.frameworkNotFound(path)

        // When
        let got = subject.type

        // Then
        XCTAssertEqual(got, .abort)
    }

    func test_description_when_frameworkNotFound() {
        // Given
        let path = try! AbsolutePath(validating: "/frameworks/tuist.framework")
        let subject = FrameworkLoaderError.frameworkNotFound(path)

        // When
        let got = subject.description

        // Then
        XCTAssertEqual(got, "Couldn't find framework at \(path.pathString)")
    }
}

final class FrameworkLoaderTests: TuistUnitTestCase {
    var frameworkMetadataProvider: MockFrameworkMetadataProvider!
    var subject: FrameworkLoader!

    override func setUp() {
        super.setUp()
        frameworkMetadataProvider = MockFrameworkMetadataProvider()
        subject = FrameworkLoader(frameworkMetadataProvider: frameworkMetadataProvider)
    }

    override func tearDown() {
        frameworkMetadataProvider = nil
        subject = nil
        super.tearDown()
    }

    func test_load_when_the_framework_doesnt_exist() async throws {
        // Given
        let path = try temporaryPath()
        let frameworkPath = path.appending(component: "tuist.framework")

        // Then
        await XCTAssertThrowsSpecific(
            try await subject.load(path: frameworkPath, status: .required),
            FrameworkLoaderError.frameworkNotFound(frameworkPath)
        )
    }

    func test_load_when_the_framework_exists() async throws {
        // Given
        let path = try temporaryPath()
        let binaryPath = path.appending(component: "tuist")
        let frameworkPath = path.appending(component: "tuist.framework")
        let dsymPath = path.appending(component: "tuist.dSYM")
        let bcsymbolmapPaths = [path.appending(component: "tuist.bcsymbolmap")]
        let architectures = [BinaryArchitecture.armv7s]
        let linking = BinaryLinking.dynamic

        try FileHandler.shared.touch(frameworkPath)

        frameworkMetadataProvider.loadMetadataStub = {
            FrameworkMetadata(
                path: $0,
                binaryPath: binaryPath,
                dsymPath: dsymPath,
                bcsymbolmapPaths: bcsymbolmapPaths,
                linking: linking,
                architectures: architectures,
                status: .required
            )
        }

        // When
        let got = try await subject.load(path: frameworkPath, status: .required)

        // Then
        XCTAssertEqual(
            got,
            .framework(
                path: frameworkPath,
                binaryPath: binaryPath,
                dsymPath: dsymPath,
                bcsymbolmapPaths: bcsymbolmapPaths,
                linking: linking,
                architectures: architectures,
                status: .required
            )
        )
    }
}
