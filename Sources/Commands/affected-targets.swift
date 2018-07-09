/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Basic
import PackageModel
import PackageGraph

import Foundation

func dumpAffectedTargetsOf(
    graph: PackageGraph,
    files: [AbsolutePath],
    mode: ShowDependenciesMode)
{
//    let dumper: DependenciesDumper
//    switch mode {
//    case .text:
//        dumper = PlainTextDumper()
//    case .dot:
//        dumper = DotDumper()
//    case .json:
//        dumper = JSONDumper()
//    case .flatlist:
//        dumper = FlatListDumper()
//    }
//    dumper.dump(dependenciesOf: rootPackage)

    let sourcePaths = Set(files)

    struct Result {
        var dependencies: Set<ResolvedTarget> = []
        var sources: Set<AbsolutePath> = []
    }

    var targets: [ResolvedTarget: Result] = [:]
    var packages: [ResolvedPackage: Result] = [:]

    for reachableTarget in graph.reachableTargets {
        // Traverse in reverse order, so that dependencies are handled first.
        var recursiveDeps = reachableTarget.recursiveDependencies
        recursiveDeps.reverse()
        recursiveDeps.append(reachableTarget)
        for target in recursiveDeps {
            let paths = target.sources.paths
                .filter(sourcePaths.contains)
            // if paths, recursively add target deps

            let dependencies = target.dependencies
                .compactMap { $0.target }
                .filter(targets.keys.contains)
            if !paths.isEmpty || !dependencies.isEmpty {
                targets[target, default: .init()].sources
                    .formUnion(paths)
                targets[target, default: .init()].dependencies
                    .formUnion(dependencies)
            }
        }
    }

    for package in graph.rootPackages {
        if sourcePaths.contains(package.path) {
            packages[package, default: .init()].sources.insert(package.path)
        }
        let dependencies = package.targets.filter(targets.keys.contains)
        if !dependencies.isEmpty {
            packages[package, default: .init()].dependencies
                .formUnion(dependencies)
        }
    }

    var results: [AffectedResult] = []

    results.append(contentsOf: packages.map { pair in
        return AffectedResult(
            name: pair.key.name,
            type: .package,
            sources: pair.value.sources.map { $0.asString },
            dependencies: pair.value.dependencies.map { $0.name })
    })
    results.append(contentsOf: targets.map { pair in
        let type: AffectedResult.ResultType
        switch pair.key.type {
        case .executable: type = .executable
        case .library: type = .library
        case .systemModule: type = .systemModule
        case .test: type = .test
        }
        return AffectedResult(
            name: pair.key.name,
            type: type,
            sources: pair.value.sources.map { $0.asString },
            dependencies: pair.value.dependencies.map { $0.name })
    })

    let jsonEncoder = JSONEncoder()
    jsonEncoder.outputFormatting = .prettyPrinted
    let data = try! jsonEncoder.encode(results)
    print(String(data: data, encoding: .utf8) ?? "fail")
}

private struct AffectedResult: Codable {
    enum ResultType: String, Codable {
        case executable = "executable"
        case library = "library"
        case systemModule = "systemModule"
        case test = "test"
        case package = "package"
    }

    var name: String
    var type: ResultType
    var sources: [String]
    var dependencies: [String]
}

private extension ResolvedTarget.Dependency {
    func hasDependency(in targets: Set<ResolvedTarget>) -> Bool {
        if let target = self.target, targets.contains(target) {
            return true
        }
        return false
    }
}

private func compareName(_ lhs: ResolvedTarget, _ rhs: ResolvedTarget) -> Bool {
    return lhs.name < rhs.name
}
