//
//  EmbraceSurfaceTracker.swift
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceSemantics
import OpenTelemetryApi
import SwiftUI

@MainActor
public class EmbraceSurfaceTracker: ObservableObject {

    public struct SurfaceInfo: Comparable, Equatable {
        public let id: UUID
        public let parentId: UUID?
        public let name: String
        public let attributes: [String: String]?
        public private(set) var coverage: Int
        public private(set) var visible: Bool = false
        public private(set) var visibilityTimestamp: UInt64 = 0

        @discardableResult
        internal mutating func update(visible: Bool, coverage: Int) -> Bool {
            var changed: Bool = false
            if self.visible != visible {
                self.visible = visible
                self.visibilityTimestamp = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
                changed = true
            }
            if self.coverage != coverage {
                self.coverage = coverage
                changed = true
            }
            return changed
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }

        public static func < (lhs: Self, rhs: Self) -> Bool {
            if lhs.visible && !rhs.visible {
                return true
            }
            if !lhs.visible && rhs.visible {
                return false
            }
            if lhs.parentId == rhs.parentId {
                return lhs.coverage > rhs.coverage
            }
            if lhs.visibilityTimestamp > rhs.visibilityTimestamp {
                return true
            }
            return false
        }
    }

    public private(set) var topSurface: SurfaceInfo?
    private var topSurfaceSpan: OpenTelemetryApi.Span?
    private var surfaces: [SurfaceInfo] = []

    func addSurface(
        id: UUID,
        parentId: UUID?,
        name: String,
        attributes: [String: String]?,
        visible: Bool,
        coverage: Int,
        logger: EmbraceTraceViewLogger
    ) {
        guard surfaces.firstIndex(where: { $0.id == id }) == nil else {
            print("[SurfaceTracker] trying to add surface '\(id)' but we already have it")
            return
        }

        var surface = SurfaceInfo(
            id: id,
            parentId: parentId,
            name: name,
            attributes: attributes,
            coverage: coverage
        )
        surface.update(visible: visible, coverage: coverage)
        surfaces.append(surface)
        updateTopSurface(logger: logger)
    }

    func removeSurface(id: UUID, logger: EmbraceTraceViewLogger) {
        guard let idx = surfaces.firstIndex(where: { $0.id == id }) else {
            print("[SurfaceTracker] trying to remove surface '\(id)' but it's not in our list")
            return
        }
        surfaces.remove(at: idx)
        updateTopSurface(logger: logger)
    }

    func updateSurface(id: UUID, visible: Bool, coverage: Int, logger: EmbraceTraceViewLogger) {
        guard let idx = surfaces.firstIndex(where: { $0.id == id }) else {
            print("[SurfaceTracker] trying to update surface '\(id)' but it's not in our list")
            return
        }

        if surfaces[idx].update(visible: visible, coverage: coverage) {
            updateTopSurface(logger: logger)
            // logSurfaceStack(stack)
        }
    }

    private func logSurfaceStack(_ stack: [SurfaceInfo]) {
        print("[SurfaceTracker]")
        print("[SurfaceTracker] surface stack:")
        for s in surfaces {
            print("[SurfaceTracker] \(s.name) {")
            print("[SurfaceTracker]     id: \(s.id)")
            print("[SurfaceTracker]     parentId: \(s.parentId?.uuidString ?? "")")
            print("[SurfaceTracker]     visible: \(s.visible)")
            print("[SurfaceTracker]     coverage: \(s.coverage)")
            print("[SurfaceTracker]     ts: \(s.visibilityTimestamp)")
            print("[SurfaceTracker]     isTop: \(s == topSurface)")
            print("[SurfaceTracker] }")
        }
    }

    private func logChangeOfTopSurface(
        surface: SurfaceInfo?,
        logger: EmbraceTraceViewLogger
    ) {
        let now = Date()

        // end the current surface span
        topSurfaceSpan?.end(time: now)
        topSurfaceSpan = nil

        if let surface {
            print("[SurfaceTracker:\(Unmanaged.passUnretained(self).toOpaque())] top \(surface.name) \(surface.id)")

            // Span event to mark the change of top surface
            logger.mark(
                surface.name,
                semantics: SpanSemantics.SwiftUISurface.navigatedToSurface,
                time: now,
                attributes: surface.attributes
            )

            // Span to indicate the duration on this surface
            topSurfaceSpan = logger.startSpan(
                surface.name,
                semantics: SpanSemantics.SwiftUISurface.currentSurface,
                time: now,
                attributes: surface.attributes,
                autoTerminationCode: .userAbandon
            )

        } else {
            print("[SurfaceTracker:\(Unmanaged.passUnretained(self).toOpaque())] top (none)")
        }
    }

    @discardableResult
    private func updateTopSurface(logger: EmbraceTraceViewLogger) -> [SurfaceInfo] {
        let stack = surfaces.filter({ $0.visible }).sorted()
        let surface = stack.first
        if surface != topSurface {
            topSurface = surface
            logChangeOfTopSurface(surface: surface, logger: logger)
        }
        return stack
    }
}

private struct EmbraceSurfaceTrackerKey: EnvironmentKey {
    @MainActor
    static let defaultValue = EmbraceSurfaceTracker()
}

extension EnvironmentValues {
    public var embraceSurfaceTracker: EmbraceSurfaceTracker {
        get { self[EmbraceSurfaceTrackerKey.self] }
        set { self[EmbraceSurfaceTrackerKey.self] = newValue }
    }
}
