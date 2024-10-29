//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@objc public protocol InternalLogger: AnyObject {
    @discardableResult @objc func trace(_ message: String, attributes: [String: String]) -> Bool
    @discardableResult @objc func trace(_ message: String) -> Bool

    @discardableResult @objc func debug(_ message: String, attributes: [String: String]) -> Bool
    @discardableResult @objc func debug(_ message: String) -> Bool

    @discardableResult @objc func info(_ message: String, attributes: [String: String]) -> Bool
    @discardableResult @objc func info(_ message: String) -> Bool

    @discardableResult @objc func warning(_ message: String, attributes: [String: String]) -> Bool
    @discardableResult @objc func warning(_ message: String) -> Bool

    @discardableResult @objc func error(_ message: String, attributes: [String: String]) -> Bool
    @discardableResult @objc func error(_ message: String) -> Bool
}
