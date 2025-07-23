//
//  EmbraceSurfaceInternal.swift
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

@available(iOS 14, tvOS 14, *)
extension EmbraceTraceSurfaceView {
    
    internal func frameChanged() {
        // not sure i want to debounce here.
        // debounce causes the updates to wait
        // until almost no movement to update
        // the top surface which can be a bit late.
        /*
        state.debounceFrameUpdate {
            performFrameUpdatesAfterDebounce()
        }
        */
        performFrameUpdatesAfterDebounce()
    }
    
    private func performFrameUpdatesAfterDebounce() {
        
        let newPercentage: Double
        defer {
            let newCoverage = max(0, min(1, newPercentage))
            if state.percentCoverage != newCoverage {
                state.percentCoverage = newCoverage
                tracker.updateSurface(
                    id: state.id,
                    visible: state.isVisible,
                    coverage: Int(state.percentCoverage * 100),
                    logger: logger
                )
            }
        }
        
        let frame = state.frame
        guard !frame.isEmpty, let window = state.window else {
            newPercentage = 0
            return
        }
        
        
        let visibleRect = frame.intersection(window.bounds)
        guard !visibleRect.isEmpty else {
            newPercentage = 0
            return
        }
        
        let visibleArea = visibleRect.width * visibleRect.height
        let totalArea = frame.width * frame.height
        
        newPercentage = visibleArea / totalArea
    }
}

@available(iOS 14, tvOS 14, *)
extension EmbraceTraceSurfaceView {
    
    @MainActor
    internal class SurfaceState: ObservableObject {
        
        @Published
        var isVisible: Bool = false
        
        let id: UUID = UUID()
        var frame: CGRect = .zero
        var window: UIWindow? = nil
        
        private var frameUpdateWorkItem: DispatchWorkItem? = nil
        
        deinit {
            frameUpdateWorkItem?.cancel()
        }
        
        func debounceFrameUpdate(_ action: @escaping () -> Void) {
            dispatchPrecondition(condition: .onQueue(.main))
            frameUpdateWorkItem?.cancel()
            frameUpdateWorkItem = DispatchWorkItem(block: action)
            guard let workItem = frameUpdateWorkItem else {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
        }
        
        var visibleBasedOnAppearance: Bool = false {
            didSet { updateVisibility() }
        }
        
        var percentCoverage: Double = 0 {
            didSet { updateVisibility() }
        }
        
        func updateVisibility() {
            let newIsVisible = (percentCoverage > 0 && visibleBasedOnAppearance)
            if isVisible != newIsVisible {
                isVisible = newIsVisible
            }
        }
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
