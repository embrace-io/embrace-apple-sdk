//
//  EmbraceTraceView.swift
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

@available(iOS 14, *)
public struct EmbraceTraceSurface<Content: View>: View {
    
    let name: String
    private let content: () -> Content
    
    @Environment(\.embraceTraceSurfaceParent)
    private var parentUUID: UUID?
    
    @State
    private var state = EmbraceTraceSurfaceState()

    public init(
        _ name: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.name = name
        self.content = content
    }
    
    public var body: some View {
        content()
            .environment(\.embraceTraceSurfaceParent, state.id)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .frame(width: 0, height: 0)
                        .preference(
                            key: VisibilityFramePreferenceKey.self,
                            value: [state.id: proxy.frame(in: .global)]
                        )
                }
            )
            .onPreferenceChange(VisibilityFramePreferenceKey.self) { values in
                guard let frame = values[state.id],
                      frame.width > 0, frame.height > 0,
                      let window = windowOfInterest else {
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
                }
            }
            .onDisappear {
                if state.percentCoverage > 0 {
                    state.percentCoverage = 0
                }
                state.visibleBasedOnAppearance = false
            }
            .onAppear {
                state.visibleBasedOnAppearance = true
            }
            .onChange(of: state.isVisible) { _ in
                print("[LIFECYCLE:surface:\(name)] visible: \(state.isVisible), parent: \(parentUUID)")
            }
    }
}

class EmbraceTraceSurfaceState {
    
    let id: UUID = UUID()
    
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
    public private(set) var isVisible: Bool = false
    
    private func _updateVisibility() {
        let newIsVisible = (percentCoverage > 0 && visibleBasedOnAppearance)
        if isVisible != newIsVisible {
            isVisible = newIsVisible
        }
    }
}

struct VisibilityFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    var windowOfInterest: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
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
