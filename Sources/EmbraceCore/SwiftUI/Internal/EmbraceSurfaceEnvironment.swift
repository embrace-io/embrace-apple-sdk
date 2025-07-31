//
//  EmbraceSurfaceEnvironment.swift
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//
import SwiftUI

struct EmbraceSurfaceViewFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
private struct EmbraceSurfaceParentEnvironmentKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
extension EnvironmentValues {
    var embraceSurfaceParent: UUID? {
        get { self[EmbraceSurfaceParentEnvironmentKey.self] }
        set { self[EmbraceSurfaceParentEnvironmentKey.self] = newValue }
    }
}
