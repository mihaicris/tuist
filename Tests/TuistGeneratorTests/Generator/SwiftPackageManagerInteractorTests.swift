
import FileSystem
import Foundation
import Path
import TuistCore
import TuistSupport
import XcodeGraph
import XcodeProj
import XCTest

@testable import TuistGenerator
@testable import TuistTesting

final class SwiftPackageManagerInteractorTests: TuistTestCase {
    private var subject: SwiftPackageManagerInteractor!
    private var system: MockSystem!
    private var fileSystem: FileSysteming!

    override func setUp() {
        super.setUp()
        system = MockSystem()
        fileSystem = FileSystem()
        subject = SwiftPackageManagerInteractor(
            fileSystem: fileSystem,
            system: system
        )
    }

    override func tearDown() {
        system = nil
        fileSystem = nil
        subject = nil
        super.tearDown()
    }

    func test_generate_addsPackageDependencyManager_withRemotePackageDependency() async throws {
        // Given
        let temporaryPath = try temporaryPath()
        let target = anyTarget(dependencies: [
            .package(product: "Example", type: .runtime),
        ])
        let package = Package.remote(url: "http://some.remote/repo.git", requirement: .exact("branch"))
        let project = Project.test(
            path: temporaryPath,
            name: "Test",
            settings: .default,
            targets: [target],
            packages: [package]
        )
        let graph = Graph.test(
            path: project.path,
            packages: [project.path: ["Test": package]],
            dependencies: [GraphDependency.packageProduct(path: project.path, product: "Test", type: .runtime): Set()]
        )
        let graphTraverser = GraphTraverser(graph: graph)

        let workspacePath = temporaryPath.appending(component: "\(project.name).xcworkspace")
        system.succeedCommand(["xcodebuild", "-resolvePackageDependencies", "-workspace", workspacePath.pathString, "-list"])
        try await createFiles(["\(workspacePath.basename)/xcshareddata/swiftpm/Package.resolved"])

        // When
        try await subject.install(graphTraverser: graphTraverser, workspaceName: workspacePath.basename)

        // Then
        let exists = try await fileSystem.exists(temporaryPath.appending(component: ".package.resolved"))
        XCTAssertTrue(exists)
    }

    func test_generate_addsPackageDependencyManager_withLocalPackageDependency() async throws {
        // Given
        let temporaryPath = try temporaryPath()
        let target = anyTarget(dependencies: [
            .package(product: "Example", type: .runtime),
        ])
        let package = try Package.local(path: AbsolutePath(validating: "/Package/"))
        let project = Project.test(
            path: temporaryPath,
            name: "Test",
            settings: .default,
            targets: [target],
            packages: [package]
        )
        let graph = Graph.test(
            path: project.path,
            packages: [project.path: ["Test": package]],
            dependencies: [GraphDependency.packageProduct(path: project.path, product: "Test", type: .runtime): Set()]
        )
        let graphTraverser = GraphTraverser(graph: graph)

        let workspacePath = temporaryPath.appending(component: "\(project.name).xcworkspace")
        system.succeedCommand(["xcodebuild", "-resolvePackageDependencies", "-workspace", workspacePath.pathString, "-list"])
        try await createFiles(["\(workspacePath.basename)/xcshareddata/swiftpm/Package.resolved"])

        // When
        try await subject.install(graphTraverser: graphTraverser, workspaceName: workspacePath.basename)

        // Then
        let exists = try await fileSystem.exists(temporaryPath.appending(component: ".package.resolved"))
        XCTAssertTrue(exists)
    }

    func test_generate_usesSystemGitCredentials() async throws {
        // Given
        let temporaryPath = try temporaryPath()

        let target = anyTarget(dependencies: [
            .package(product: "Example", type: .runtime),
        ])
        let package = Package.remote(url: "http://some.remote/repo.git", requirement: .exact("branch"))
        let project = Project.test(
            path: temporaryPath,
            name: "Test",
            settings: .default,
            targets: [target],
            packages: [package]
        )
        let graph = Graph.test(
            path: project.path,
            packages: [project.path: ["Test": package]],
            dependencies: [GraphDependency.packageProduct(path: project.path, product: "Test", type: .macro): Set()]
        )
        let graphTraverser = GraphTraverser(graph: graph)

        let workspacePath = temporaryPath.appending(component: "\(project.name).xcworkspace")
        system
            .succeedCommand([
                "xcodebuild",
                "-resolvePackageDependencies",
                "-scmProvider",
                "system",
                "-workspace",
                workspacePath.pathString,
                "-list",
            ])
        try await createFiles(["\(workspacePath.basename)/xcshareddata/swiftpm/Package.resolved"])

        // When
        try await subject.install(
            graphTraverser: graphTraverser,
            workspaceName: workspacePath.basename,
            configGeneratedProjectOptions: .test(
                compatibleXcodeVersions: .all,
                generationOptions: .test(resolveDependenciesWithSystemScm: true)
            )
        )

        // Then
        let exists = try await fileSystem.exists(temporaryPath.appending(component: ".package.resolved"))
        XCTAssertTrue(exists)
    }

    func test_generate_linksRootPackageResolved_before_resolving() async throws {
        // Given
        let temporaryPath = try temporaryPath()
        let target = anyTarget(dependencies: [
            .package(product: "Example", type: .runtime),
        ])
        let package = Package.remote(url: "http://some.remote/repo.git", requirement: .exact("branch"))
        let project = Project.test(
            path: temporaryPath,
            name: "Test",
            settings: .default,
            targets: [target],
            packages: [
                package,
            ]
        )
        let graph = Graph.test(
            path: project.path,
            packages: [project.path: ["Test": package]],
            dependencies: [GraphDependency.packageProduct(path: project.path, product: "Test", type: .runtime): Set()]
        )
        let graphTraverser = GraphTraverser(graph: graph)

        let workspace = Workspace.test(
            name: project.name,
            projects: [project.path]
        )
        let rootPackageResolvedPath = temporaryPath.appending(component: ".package.resolved")
        try FileHandler.shared.write("package", path: rootPackageResolvedPath, atomically: false)

        let workspacePath = temporaryPath.appending(component: workspace.name + ".xcworkspace")
        system.succeedCommand(["xcodebuild", "-resolvePackageDependencies", "-workspace", workspacePath.pathString, "-list"])

        // When
        try await subject.install(graphTraverser: graphTraverser, workspaceName: workspacePath.basename)

        // Then
        let workspacePackageResolvedPath = temporaryPath
            .appending(try RelativePath(validating: "\(workspace.name).xcworkspace/xcshareddata/swiftpm/Package.resolved"))
        XCTAssertEqual(
            try FileHandler.shared.readTextFile(workspacePackageResolvedPath),
            "package"
        )
        try FileHandler.shared.write("changedPackage", path: rootPackageResolvedPath, atomically: false)
        XCTAssertEqual(
            try FileHandler.shared.readTextFile(workspacePackageResolvedPath),
            "changedPackage"
        )
    }

    func test_generate_doesNotAddPackageDependencyManager() async throws {
        // Given
        let temporaryPath = try temporaryPath()
        let target = anyTarget()
        let project = Project.test(
            path: temporaryPath,
            name: "Test",
            settings: .default,
            targets: [target]
        )
        let graph = Graph.test()
        let graphTraverser = GraphTraverser(graph: graph)

        let workspace = Workspace.test(projects: [project.path])
        let workspacePath = temporaryPath.appending(component: workspace.name + ".xcworkspace")

        // When
        try await subject.install(graphTraverser: graphTraverser, workspaceName: workspacePath.basename)

        // Then
        let exists = try await fileSystem.exists(temporaryPath.appending(component: ".package.resolved"))
        XCTAssertFalse(exists)
    }

    func test_generate_sets_cloned_source_packages_dir_path() async throws {
        // Given
        let temporaryPath = try temporaryPath()
        let spmPath = temporaryPath.appending(component: "spm")
        let target = anyTarget(dependencies: [
            .package(product: "Example", type: .runtime),
        ])
        let package = Package.remote(url: "http://some.remote/repo.git", requirement: .exact("branch"))
        let project = Project.test(
            path: temporaryPath,
            name: "Test",
            settings: .default,
            targets: [target],
            packages: [package]
        )
        let graph = Graph.test(
            path: project.path,
            packages: [project.path: ["Test": package]],
            dependencies: [GraphDependency.packageProduct(path: project.path, product: "Test", type: .runtime): Set()]
        )
        let graphTraverser = GraphTraverser(graph: graph)

        let workspacePath = temporaryPath.appending(component: "\(project.name).xcworkspace")
        system.succeedCommand([
            "xcodebuild",
            "-resolvePackageDependencies",
            "-clonedSourcePackagesDirPath",
            "\(spmPath.pathString)/\(project.name)",
            "-workspace",
            workspacePath.pathString,
            "-list",
        ])
        try await createFiles(["\(workspacePath.basename)/xcshareddata/swiftpm/Package.resolved"])

        // When
        try await subject.install(
            graphTraverser: graphTraverser,
            workspaceName: workspacePath.basename,
            configGeneratedProjectOptions: .test(generationOptions: .test(
                clonedSourcePackagesDirPath: temporaryPath
                    .appending(component: "spm")
            ))
        )

        // Then
        let exists = try await fileSystem.exists(temporaryPath.appending(component: ".package.resolved"))
        XCTAssertTrue(exists)
    }

    // MARK: - Helpers

    func anyTarget(dependencies: [TargetDependency] = []) -> Target {
        Target.test(
            infoPlist: nil,
            entitlements: nil,
            settings: nil,
            dependencies: dependencies
        )
    }
}
