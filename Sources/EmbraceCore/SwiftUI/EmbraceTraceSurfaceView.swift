//
//  EmbraceTraceSurfaceView.swift
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

@available(iOS 14, tvOS 14, *)
public struct EmbraceTraceSurfaceView<Content: View>: View {
    
    private let name: String
    private let content: () -> Content
    
    @Environment(\.embraceSurfaceParent)
    private var parentUUID: UUID?
    
    @Environment(\.embraceTraceViewLogger)
    internal var logger: EmbraceTraceViewLogger
    
    @StateObject
    internal var state = SurfaceState()

    @ObservedObject
    internal var tracker = EmbraceSurfaceTracker.shared

    public init(
        _ name: String,
        content: @escaping () -> Content
    ) {
        self.name = name
        self.content = content
    }
    
    public var body: some View {
        content()
            .environment(\.embraceSurfaceParent, state.id)
            .emb_iOS13safe_background {
                EmbraceTraceSurfaceViewRepresentable { window in
                    RunLoop.main.perform(inModes: [.common]) {
                        state.window = window
                        frameChanged()
                    }
                }
            }
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .preference(
                            key: EmbraceSurfaceViewFramePreferenceKey.self,
                            value: [state.id: proxy.frame(in: .global)]
                        )
                }
            )
            .onPreferenceChange(EmbraceSurfaceViewFramePreferenceKey.self) { values in
                state.frame = values[state.id] ?? .zero
                frameChanged()
            }
            .onDisappear {
                state.visibleBasedOnAppearance = false
                tracker.removeSurface(id: state.id, logger: logger)
            }
            .onAppear {
                state.visibleBasedOnAppearance = true
                tracker.addSurface(
                    id: state.id,
                    parentId: parentUUID,
                    name: name,
                    visible: state.isVisible,
                    coverage: Int(state.percentCoverage * 100),
                    logger: logger
                )
            }
            .onChange(of: state.isVisible) { _ in
                tracker.updateSurface(
                    id: state.id,
                    visible: state.isVisible,
                    coverage: Int(state.percentCoverage * 100),
                    logger: logger
                )
            }
    }
}

