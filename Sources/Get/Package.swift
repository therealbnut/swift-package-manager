/*
 This source file is part of the Swift.org open source project

 Copyright 2015 - 2016 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import PackageModel

import struct PackageDescription.Version

extension Package: Fetchable {
    var children: [(String, Range<Version>)] {
        return manifest.package.dependencies.map{ ($0.url, $0.versionRange) }
    }

    var currentVersion: Version {
        return self.version!
    }

    func constrain(to versionRange: Range<Version>) -> Version? {
        return nil
    }

    var availableVersions: [Version] {
        return [currentVersion]
    }

    func setCurrentVersion(_ newValue: Version) throws {
        throw Get.Error.invalidDependencyGraph(url)
    }
}
