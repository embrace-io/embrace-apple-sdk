//
//  EmbraceTraceView.swift
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI
#if !EMBRACE_COCOAPOD_BUILDING_SDK
import EmbraceCommonInternal
import EmbraceConfiguration
import EmbraceOTelInternal
import EmbraceSemantics
#endif
import OpenTelemetryApi

@available(iOS 14, *)
public struct EmbraceTraceSurface<Content: View>: View {
    
    let name: String
    private let content: () -> Content
    
    @Environment(\.embraceTraceSurfaceParent)
    private var parentUUID: UUID?

    @StateObject
    private var state: EmbraceTraceSurfaceState = EmbraceTraceSurfaceState()
    
    @ObservedObject
    private var tracker = SurfaceTracker.shared
    
    public init(
        _ name: String,
        content: @escaping () -> Content
    ) {
        self.name = name
        self.content = content
    }
    
    public var body: some View {
        content()
            .overlay {
                VStack(alignment: .leading) {
                    Spacer()
                        .frame(height: 80)
                    Text("\(state.id)")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(radius: 10)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .border(
                    tracker.topSurface?.id == state.id ? .green : .red,
                    width: 2
                )
            }
            .environment(\.embraceTraceSurfaceParent, state.id)
            .background {
                EmbraceTraceSurfaceViewRepresentable { window in
                    RunLoop.main.perform(inModes: [.common]) {
                        state.window = window
                        visiblityPreferenceChanged()
                    }
                }
            }
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .preference(
                            key: VisibilityFramePreferenceKey.self,
                            value: [state.id: proxy.frame(in: .global)]
                        )
                }
            )
            .onPreferenceChange(VisibilityFramePreferenceKey.self) { values in
                state.frame = values[state.id] ?? .zero
                visiblityPreferenceChanged()
            }
            .onDisappear {
                state.visibleBasedOnAppearance = false
                SurfaceTracker.shared.removeSurface(id: state.id)
            }
            .onAppear {
                state.visibleBasedOnAppearance = true
                SurfaceTracker.shared.addSurface(
                    id: state.id,
                    parentId: parentUUID,
                    name: name,
                    visible: state.isVisible,
                    coverage: Int(state.percentCoverage * 100)
                )
            }
            .onChange(of: state.isVisible) { _ in
                SurfaceTracker.shared.updateSurface(
                    id: state.id,
                    visible: state.isVisible,
                    coverage: Int(state.percentCoverage * 100)
                )
            }
    }
    
    private func visiblityPreferenceChanged() {
        let frame = state.frame
        guard frame.width > 0, frame.height > 0 else {
            state.percentCoverage = 0
            return
        }
        
        guard let window = state.window else {
            state.percentCoverage = 0
            return
        }
        
        let visibleRect = frame.intersection(window.bounds)
        guard visibleRect.width > 0, visibleRect.height > 0 else {
            state.percentCoverage = 0
            return
        }
        
        let visibleArea = visibleRect.width * visibleRect.height
        let totalArea = frame.width * frame.height
        
        let percentage = visibleArea / totalArea
        let newCoverage = max(0, min(1, percentage))
        if state.percentCoverage != newCoverage {
            state.percentCoverage = newCoverage
            SurfaceTracker.shared.updateSurface(
                id: state.id,
                visible: state.isVisible,
                coverage: Int(state.percentCoverage * 100)
            )
        }
    }
}

@MainActor
class EmbraceTraceSurfaceState: ObservableObject {
    
    let id: UUID = UUID()

    var frame: CGRect = .zero
    var window: UIWindow? = nil
    
    var visibleBasedOnAppearance: Bool = false {
        didSet {
            _updateVisibility()
        }
    }
    var percentCoverage: Double = 0 {
        didSet {
            _updateVisibility()
        }
    }
    
    @Published
    public private(set) var isVisible: Bool = false
    
    private func _updateVisibility() {
        let newIsVisible = (percentCoverage > 0 && visibleBasedOnAppearance)
        if isVisible != newIsVisible {
            isVisible = newIsVisible
        }
    }
}

@MainActor
public class SurfaceTracker: ObservableObject {
    
    public static let shared = SurfaceTracker()
    
    public struct SurfaceInfo: Comparable, Equatable {
        public let id: UUID
        public let parentId: UUID?
        public let name: String
        public internal(set) var coverage: Int
        public private(set) var visible: Bool = false
        public private(set) var visibilityTimestamp: UInt64 = 0
        
        internal mutating func update(visibility: Bool) {
            visible = visibility
            updateClock()
        }
        
        internal mutating func updateClock() {
            visibilityTimestamp = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        }
        
        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
        
        public static func < (lhs: Self, rhs: Self) -> Bool {
            if lhs.id == rhs.id {
                return lhs.coverage > rhs.coverage
            }
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
    
    @Published
    private(set) var topSurface: SurfaceInfo? = nil {
        didSet {
            if let topSurface {
                print("[SurfaceTracker] top \(topSurface.name) \(topSurface.id)")
                
                Embrace.client?.buildSpan(
                    name: "emb-swiftui.surface.\(topSurface.name).nav-to",
                    type: SpanType.viewLoad,
                ).startSpan().end()
                
            } else {
                print("[SurfaceTracker] top (none)")
            }
        }
    }

    private var surfaces: [SurfaceInfo] = []
    
    private init() {}
    
    func addSurface(id: UUID, parentId: UUID?, name: String, visible: Bool, coverage: Int) {
        guard surfaces.firstIndex(where: { $0.id == id }) == nil else {
            print("[SurfaceTracker] trying to add surface '\(id)' but we already have it")
            return
        }
        
        var surface = SurfaceInfo(
            id: id,
            parentId: parentId,
            name: name,
            coverage: coverage
        )
        surface.update(visibility: visible)
        surfaces.append(surface)
        updateTopSurface()
    }
    
    func removeSurface(id: UUID) {
        guard let idx = surfaces.firstIndex(where: { $0.id == id }) else {
            print("[SurfaceTracker] trying to remove surface '\(id)' but it's not in our list")
            return
        }
        surfaces.remove(at: idx)
        updateTopSurface()
    }
    
    func updateSurface(id: UUID, visible: Bool, coverage: Int) {
        guard let idx = surfaces.firstIndex(where: { $0.id == id }) else {
            print("[SurfaceTracker] trying to update surface '\(id)' but it's not in our list")
            return
        }
        var changed: Bool = false
        
        if surfaces[idx].visible != visible {
            surfaces[idx].update(visibility: visible)
            changed = true
        }
        if surfaces[idx].coverage != coverage {
            surfaces[idx].coverage = coverage
            changed = true
        }
        if changed {
            let stack = updateTopSurface()
            //logSurfaceStack(stack)
        }
    }
    
    private func logSurfaceStack(_ stack: [SurfaceInfo]) {
        print("[SurfaceTracker]")
        print("[SurfaceTracker] surface stack:")
        for s in surfaces {
            print("[SurfaceTracker] \(s.name) {")
            print("[SurfaceTracker]     id: \(s.id)")
            print("[SurfaceTracker]     parentId: \(s.parentId)")
            print("[SurfaceTracker]     visible: \(s.visible)")
            print("[SurfaceTracker]     coverage: \(s.coverage)")
            print("[SurfaceTracker]     ts: \(s.visibilityTimestamp)")
            print("[SurfaceTracker]     isTop: \(s == topSurface)")
            print("[SurfaceTracker] }")
        }
    }
    
    @discardableResult
    private func updateTopSurface() -> [SurfaceInfo] {
        let stack = surfaces.filter({ $0.visible }).sorted()
        let surface = stack.first
        if surface != topSurface {
            topSurface = surface
        }
        return stack
    }
}

struct VisibilityFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
private struct EmbraceTraceSurfaceParentEnvironmentKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
extension EnvironmentValues {
    /// Provides access to the shared `EmbraceTraceViewContext` for the current view subtree.
    var embraceTraceSurfaceParent: UUID? {
        get { self[EmbraceTraceSurfaceParentEnvironmentKey.self] }
        set { self[EmbraceTraceSurfaceParentEnvironmentKey.self] = newValue }
    }
}

class EmbraceTraceSurfaceUIView: UIView {
    let windowChanged: (UIWindow?) -> Void
    
    init(windowChanged: @escaping (UIWindow?) -> Void) {
        self.windowChanged = windowChanged
        super.init(frame: .zero)
        self.backgroundColor = UIColor.clear
        self.isUserInteractionEnabled = false
    }
    
    override func didMoveToWindow() {
        windowChanged(window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct EmbraceTraceSurfaceViewRepresentable: UIViewRepresentable {
    
    let windowChanged: (UIWindow?) -> Void
    
    func makeUIView(context: Context) -> UIView {
        return EmbraceTraceSurfaceUIView(windowChanged: windowChanged)
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
    }
}
