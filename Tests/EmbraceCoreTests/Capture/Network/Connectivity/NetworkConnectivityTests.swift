//
//  Copyright © 2026 Embrace Mobile, Inc. All rights reserved.
//

import XCTest

@testable import EmbraceCore

final class NetworkConnectivityTests: XCTestCase {

    private func map(satisfied: Bool, wifi: Bool = false, cellular: Bool = false) -> NetworkConnectivity {
        NetworkConnectivity(NetworkPathSnapshot(isSatisfied: satisfied, usesWiFi: wifi, usesCellular: cellular))
    }

    func testTheMappingTable() {
        XCTAssertEqual(map(satisfied: true, wifi: true), .wifi)
        XCTAssertEqual(map(satisfied: true, cellular: true), .wan)
        XCTAssertEqual(map(satisfied: true), .unknown)
        XCTAssertEqual(map(satisfied: false), .none)
    }

    func testAPathOnBothWiFiAndCellularIsWiFi() {
        XCTAssertEqual(map(satisfied: true, wifi: true, cellular: true), .wifi)
    }

    func testAnUnsatisfiedPathIsNoneWhateverItsInterfaces() {
        XCTAssertEqual(map(satisfied: false, wifi: true), .none)
        XCTAssertEqual(map(satisfied: false, cellular: true), .none)
        XCTAssertEqual(map(satisfied: false, wifi: true, cellular: true), .none)
    }

    func testTheWireStrings() {
        XCTAssertEqual(NetworkConnectivity.wifi.stateDescription, "wifi")
        XCTAssertEqual(NetworkConnectivity.wan.stateDescription, "wan")
        XCTAssertEqual(NetworkConnectivity.unknown.stateDescription, "unknown")
        XCTAssertEqual(NetworkConnectivity.none.stateDescription, "none")
    }

    func testNoValueIsASystemValue() {
        for value in [NetworkConnectivity.wifi, .wan, .unknown, .none] {
            XCTAssertFalse(value.isSystemValue)
        }
    }
}
