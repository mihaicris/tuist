import Foundation
import Mockable
import Path
import ProjectDescription
import TuistCore
import TuistDependencies
import TuistLoader
import TuistPlugin
import TuistSupport
import XcodeGraph

/// A utility for loading a graph for a given Manifest path on disk
///
/// - Any configured plugins are loaded
/// - All referenced manifests are loaded
/// - All manifests are concurrently transformed to models
/// - A graph is loaded from the models
///
/// - Note: This is a simplified implementation that loads a graph without applying any mappers or running any linters
@Mockable
public protocol ManifestGraphLoading {
    /// Loads a Workspace or Project Graph at a given path based on manifest availability
    /// - Parameters:
    ///   - path: Path to load
    ///   - disableSandbox: Whether to disable loading the manifest in a sandboxed environment.
    /// - Note: This will search for a Workspace manifest first, then fallback to searching for a Project manifest
    func load(path: AbsolutePath, disableSandbox: Bool) async throws
        -> (Graph, [SideEffectDescriptor], MapperEnvironment, [LintingIssue])
    // swiftlint:disable:previous large_tuple
}

public final class ManifestGraphLoader: ManifestGraphLoading {
    private let configLoader: ConfigLoading
    private let manifestLoader: ManifestLoading
    private let recursiveManifestLoader: RecursiveManifestLoading
    private let converter: ManifestModelConverting
    private let graphLoader: GraphLoading
    private let pluginsService: PluginServicing
    private let swiftPackageManagerGraphLoader: SwiftPackageManagerGraphLoading
    private let graphLoaderLinter: CircularDependencyLinting
    private let manifestLinter: ManifestLinting
    private let workspaceMapper: WorkspaceMapping
    private let graphMapper: GraphMapping
    private let packageSettingsLoader: PackageSettingsLoading
    private let manifestFilesLocator: ManifestFilesLocating

    public convenience init(
        manifestLoader: ManifestLoading,
        workspaceMapper: WorkspaceMapping,
        graphMapper: GraphMapping
    ) {
        self.init(
            configLoader: ConfigLoader(manifestLoader: manifestLoader),
            manifestLoader: manifestLoader,
            recursiveManifestLoader: RecursiveManifestLoader(manifestLoader: manifestLoader),
            converter: ManifestModelConverter(
                manifestLoader: manifestLoader
            ),
            graphLoader: GraphLoader(),
            pluginsService: PluginService(manifestLoader: manifestLoader),
            swiftPackageManagerGraphLoader: SwiftPackageManagerGraphLoader(manifestLoader: manifestLoader),
            graphLoaderLinter: CircularDependencyLinter(),
            manifestLinter: ManifestLinter(),
            workspaceMapper: workspaceMapper,
            graphMapper: graphMapper,
            packageSettingsLoader: PackageSettingsLoader(manifestLoader: manifestLoader),
            manifestFilesLocator: ManifestFilesLocator()
        )
    }

    init(
        configLoader: ConfigLoading,
        manifestLoader: ManifestLoading,
        recursiveManifestLoader: RecursiveManifestLoader,
        converter: ManifestModelConverting,
        graphLoader: GraphLoading,
        pluginsService: PluginServicing,
        swiftPackageManagerGraphLoader: SwiftPackageManagerGraphLoading,
        graphLoaderLinter: CircularDependencyLinting,
        manifestLinter: ManifestLinting,
        workspaceMapper: WorkspaceMapping,
        graphMapper: GraphMapping,
        packageSettingsLoader: PackageSettingsLoading,
        manifestFilesLocator: ManifestFilesLocating
    ) {
        self.configLoader = configLoader
        self.manifestLoader = manifestLoader
        self.recursiveManifestLoader = recursiveManifestLoader
        self.converter = converter
        self.graphLoader = graphLoader
        self.pluginsService = pluginsService
        self.swiftPackageManagerGraphLoader = swiftPackageManagerGraphLoader
        self.graphLoaderLinter = graphLoaderLinter
        self.manifestLinter = manifestLinter
        self.workspaceMapper = workspaceMapper
        self.graphMapper = graphMapper
        self.packageSettingsLoader = packageSettingsLoader
        self.manifestFilesLocator = manifestFilesLocator
    }

    // swiftlint:disable:next function_body_length
    public func load(
        path: AbsolutePath,
        disableSandbox: Bool
    ) async throws -> (Graph, [SideEffectDescriptor], MapperEnvironment, [LintingIssue]) { // swiftlint:disable:this large_tuple
        try await manifestLoader.validateHasRootManifest(at: path)

        // Load Plugins
        let plugins = try await loadPlugins(at: path)

        // Load Workspace
        var allManifests = try await recursiveManifestLoader.loadWorkspace(at: path, disableSandbox: disableSandbox)
        let isSPMProjectOnly = allManifests.projects.isEmpty
        let hasExternalDependencies = allManifests.projects.values.contains { $0.containsExternalDependencies }

        // Load DependenciesGraph

        let dependenciesGraph: XcodeGraph.DependenciesGraph
        let packageSettings: TuistCore.PackageSettings?

        // Load SPM graph only if is SPM Project only or the workspace is using external dependencies
        if let packagePath = try await manifestFilesLocator.locatePackageManifest(at: path),
           isSPMProjectOnly || hasExternalDependencies
        {
            let loadedPackageSettings = try await packageSettingsLoader.loadPackageSettings(
                at: packagePath.parentDirectory,
                with: plugins,
                disableSandbox: disableSandbox
            )

            let manifestsDependencyGraph = try await swiftPackageManagerGraphLoader.load(
                packagePath: packagePath,
                packageSettings: loadedPackageSettings
            )
            dependenciesGraph = try await converter.convert(dependenciesGraph: manifestsDependencyGraph, path: path)
            packageSettings = loadedPackageSettings
        } else {
            packageSettings = nil
            dependenciesGraph = .none
        }

        // Merge SPM graph
        if let packageSettings {
            allManifests = try await recursiveManifestLoader.loadAndMergePackageProjects(
                in: allManifests,
                packageSettings: packageSettings,
                disableSandbox: disableSandbox
            )
        }

        let (workspaceModels, manifestProjects) = (
            try await converter.convert(manifest: allManifests.workspace, path: allManifests.path),
            allManifests.projects
        )

        // Lint Manifests
        let workspaceLintingIssues = manifestLinter.lint(workspace: allManifests.workspace)
        let projectLintingIssues = manifestProjects.flatMap { manifestLinter.lint(project: $0.value) }
        let lintingIssues = workspaceLintingIssues + projectLintingIssues
        try lintingIssues.printAndThrowErrorsIfNeeded()

        // Convert to models
        let projectsModels = try await convert(
            projects: manifestProjects,
            plugins: plugins,
            externalDependencies: dependenciesGraph.externalDependencies
        ) +
            dependenciesGraph.externalProjects.values

        // Check circular dependencies
        try graphLoaderLinter.lintWorkspace(workspace: workspaceModels, projects: projectsModels)

        // Apply any registered model mappers
        let (updatedModels, modelMapperSideEffects) = try await workspaceMapper.map(
            workspace: .init(workspace: workspaceModels, projects: projectsModels)
        )

        // Load graph
        let graphLoader = GraphLoader()
        let graph = try await graphLoader.loadWorkspace(
            workspace: updatedModels.workspace,
            projects: updatedModels.projects
        )

        if await RunMetadataStorage.current.graph == nil {
            await RunMetadataStorage.current.update(graph: graph)
        }

        // Apply graph mappers
        let (mappedGraph, graphMapperSideEffects, environment) = try await graphMapper.map(
            graph: graph,
            environment: MapperEnvironment()
        )

        return (
            mappedGraph,
            modelMapperSideEffects + graphMapperSideEffects,
            environment,
            lintingIssues
        )
    }

    private func convert(
        projects: [AbsolutePath: ProjectDescription.Project],
        plugins: Plugins,
        externalDependencies: [String: [XcodeGraph.TargetDependency]]
    ) async throws -> [XcodeGraph.Project] {
        let tuples = projects.map { (path: $0.key, manifest: $0.value) }
        return try await tuples.concurrentMap {
            try await self.converter.convert(
                manifest: $0.manifest,
                path: $0.path,
                plugins: plugins,
                externalDependencies: externalDependencies,
                type: .local
            )
        }
    }

    @discardableResult
    func loadPlugins(at path: AbsolutePath) async throws -> Plugins {
        let config = try await configLoader.loadConfig(path: path)
        if let configGeneratedProjectOptions = config.project.generatedProject {
            let plugins = try await pluginsService.loadPlugins(using: configGeneratedProjectOptions)
            try manifestLoader.register(plugins: plugins)
            return plugins
        } else {
            return Plugins(projectDescriptionHelpers: [], templatePaths: [], resourceSynthesizers: [])
        }
    }
}
