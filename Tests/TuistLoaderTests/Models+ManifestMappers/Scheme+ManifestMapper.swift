import Foundation
import Path
import ProjectDescription
import TuistCore
import TuistSupport
import XcodeGraph
import XCTest

@testable import TuistLoader
@testable import TuistTesting

final class SchemeManifestMapperTests: TuistUnitTestCase {
    func test_from_when_the_scheme_has_no_actions() async throws {
        // Given
        let manifest = ProjectDescription.Scheme.test(
            name: "Scheme",
            shared: false
        )
        let projectPath = try AbsolutePath(validating: "/somepath/Project")
        let rootDirectory = try temporaryPath()
        let generatorPaths = GeneratorPaths(
            manifestDirectory: projectPath,
            rootDirectory: rootDirectory
        )

        // When
        let model = try await XcodeGraph.Scheme.from(manifest: manifest, generatorPaths: generatorPaths)

        // Then
        try assert(scheme: model, matches: manifest, path: projectPath, generatorPaths: generatorPaths)
    }

    func test_from_when_the_scheme_has_actions() async throws {
        // Given
        let arguments = ProjectDescription.Arguments.test(
            environment: ["FOO": "BAR", "FIZ": "BUZZ"],
            launchArguments: [
                .launchArgument(name: "--help", isEnabled: true),
                .launchArgument(name: "subcommand", isEnabled: false),
            ]
        )

        let projectPath = try AbsolutePath(validating: "/somepath")
        let rootDirectory = try temporaryPath()
        let generatorPaths = GeneratorPaths(
            manifestDirectory: projectPath,
            rootDirectory: rootDirectory
        )

        let buildAction = ProjectDescription.BuildAction.test(targets: ["A", "B"])
        let runActions = ProjectDescription.RunAction.test(
            configuration: .release,
            executable: "A",
            arguments: arguments
        )
        let testAction = ProjectDescription.TestAction.test(
            targets: ["B"],
            arguments: arguments,
            configuration: .debug,
            coverage: true
        )
        let manifest = ProjectDescription.Scheme.test(
            name: "Scheme",
            shared: true,
            buildAction: buildAction,
            testAction: testAction,
            runAction: runActions
        )

        // When
        let model = try await XcodeGraph.Scheme.from(manifest: manifest, generatorPaths: generatorPaths)

        // Then
        try assert(scheme: model, matches: manifest, path: projectPath, generatorPaths: generatorPaths)
    }
}
