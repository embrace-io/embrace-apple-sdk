//
//  TestScreenDataModel.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

protocol TestScreenDataModel {
    associatedtype UIComponent: View
    var title: String { get }
    var identifier: String { get }
    @ViewBuilder var uiComponent: UIComponent { get }
    var payloadTestObject: PayloadTest { get }
}
