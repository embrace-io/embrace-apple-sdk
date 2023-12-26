//
//  File.swift
//
//
//  Created by Fernando Draghi on 22/09/2023.
//
#if canImport(UIKit)
import UIKit
import EmbraceCommon
import EmbraceOTel

protocol TapCaptureServiceHandler: CaptureServiceHandler {
    func handleCapturedEvent(_ event: UIEvent)
}

final class DefaultTapCaptureServiceHandler: TapCaptureServiceHandler {
    @ThreadSafe
    private(set) var state: CaptureServiceHandlerState
    private let client: Embrace?

    init(initialState: CaptureServiceHandlerState = .initialized,
         client: Embrace?) {
        self.state = initialState
        // TODO: - It'd be better to abstract the possibility to add events to the session span
        // into something that's not the actual Embrace public API.
        self.client = client
    }

    func changedState(to captureServiceState: CaptureServiceState) {
        state = captureServiceState == .listening ? .listening : .paused
    }

    func handleCapturedEvent(_ event: UIEvent) {
        guard event.type == .touches,
              let allTouches = event.allTouches,
              let touch = allTouches.first,
              touch.phase == .began,
              let target = touch.view else {
            return
        }
        let screenView = target.window
        var point = CGPoint()

        if shouldRecordCoordinates(from: target) {
            point = touch.location(in: screenView)
        }

        let accessibilityIdentifier = target.accessibilityIdentifier
        let targetClass = type(of: target)

        let viewName = accessibilityIdentifier ?? NSStringFromClass(targetClass)
        // TODO: Review Attributes & Span Event Name
        let event = RecordingSpanEvent(name: "action.tap",
                                       timestamp: Date(),
                                       attributes: [
                                        "view_name": .string(viewName),
                                        "point": .string(point.toString())
                                       ])

        client?.add(event: event)
        ConsoleLog.trace("Captured tap at \(point) on: \(viewName)")
    }
}

extension DefaultTapCaptureServiceHandler {
    static func create() -> DefaultTapCaptureServiceHandler {
        .init(client: Embrace.client)
    }
}

private extension DefaultTapCaptureServiceHandler {
    func shouldRecordCoordinates(from target: AnyObject?) -> Bool {
        guard let keyboardViewClass = NSClassFromString("UIKeyboardLayout"),
              let keyboardWindowClass = NSClassFromString("UIRemoteKeyboardWindow"),
              let target = target
        else {
            return false
        }

        return !(target.isKind(of: keyboardViewClass) || target.isKind(of: keyboardWindowClass))
    }
}

#endif

