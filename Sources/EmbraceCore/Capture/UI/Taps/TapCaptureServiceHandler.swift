//
//  File.swift
//  
//
//  Created by Fernando Draghi on 22/09/2023.
//
#if canImport(UIKit)
import UIKit
import EmbraceCommon

protocol TapCaptureServiceHandlerType {
    func handleCapturedEvent(_ event: UIEvent)
}

final class TapCaptureServiceHandler: TapCaptureServiceHandlerType {
    func handleCapturedEvent(_ event: UIEvent) {
        if event.type == .touches {
            let allTouches: Set<UITouch>? = event.allTouches
            if let touch = allTouches?.first, touch.phase == .began,
               let target = touch.view {
                let screenView = target.window
                var point = CGPoint()

                if shouldRecordCoordinates(from: target) {
                    point = touch.location(in: screenView)
                }

                let accessibilityIdentifier = target.accessibilityIdentifier
                let targetClass = type(of: target)

                let viewName = accessibilityIdentifier ?? NSStringFromClass(targetClass)

                ConsoleLog.trace("Captured tap at \(point) on: \(viewName)")
            }
        }
    }

    private func shouldRecordCoordinates(from target: AnyObject?) -> Bool {
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
