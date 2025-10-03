//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

public protocol InternalLogger: AnyObject {
    @discardableResult func trace(_ message: String, attributes: [String: String]) -> Bool
    @discardableResult func trace(_ message: String) -> Bool

    @discardableResult func debug(_ message: String, attributes: [String: String]) -> Bool
    @discardableResult func debug(_ message: String) -> Bool

    @discardableResult func info(_ message: String, attributes: [String: String]) -> Bool
    @discardableResult func info(_ message: String) -> Bool

    @discardableResult func warning(_ message: String, attributes: [String: String]) -> Bool
    @discardableResult func warning(_ message: String) -> Bool

    @discardableResult func error(_ message: String, attributes: [String: String]) -> Bool
    @discardableResult func error(_ message: String) -> Bool

    @discardableResult func startup(_ message: String, attributes: [String: String]) -> Bool
    @discardableResult func startup(_ message: String) -> Bool

    @discardableResult func critical(_ message: String, attributes: [String: String]) -> Bool
    @discardableResult func critical(_ message: String) -> Bool
}
