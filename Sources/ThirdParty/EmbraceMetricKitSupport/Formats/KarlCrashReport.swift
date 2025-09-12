//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

struct KarlCrashReport: Codable {

    struct BinaryImage: Codable, Hashable {
        let imageAddr: UInt64
        let imageSize: UInt64
        let name: String
        let uuid: String
    }
    let binaryImages: [BinaryImage]

    struct Crash: Codable {
        let diagnosis: String?

        struct Error: Codable {

            struct Mach: Codable {
                let code: Int64?
                let codeName: String?
                let exception: Int64?
                let exceptionName: String?
                let subcode: UInt64?
            }
            let mach: Mach

            struct Signal: Codable {
                let code: Int?
                let codeName: String?
                let signal: Int?
                let name: String?
            }
            let signal: Signal

            struct NSException: Codable {
                let name: String?
                let userInfo: String?
            }
            let nsexception: NSException

            struct CPPException: Codable {
                let name: String?
            }
            let cppException: CPPException

            let type: String
            let reason: String?
        }
        let error: Error

        struct Thread: Codable {
            let id: Int64
            let name: String?

            struct Backtrace: Codable {
                struct Frame: Codable {
                    let instructionAddr: UInt64
                    let objectAddr: UInt64
                    let objectName: String
                    let symbolAddr: UInt64
                    let symbolName: String?
                }
                let contents: [Frame]
            }
            let backtrace: Backtrace
            let crashed: Bool

        }
        let threads: [Thread]
    }
    let crash: Crash

    struct Report: Codable {
        let id: String
        let timestamp: Date  // microseconds since unix epoch
        let type: String
    }
    let report: Report

    struct System: Codable {
        let CFBundleIdentifier: String?
        let CFBundleShortVersionString: String?
        let CFBundleVersion: String?
        let appUuid: String?

        struct ApplicationStats: Codable {
            let applicationActive: Bool
            let ApplicationInForeground: Bool
        }
        let applicationStats: ApplicationStats
        let osVersion: String?
        let systemVersion: String?
    }
    let system: System

    struct User: Codable {
        let sid: String?
        let sdk: String?

        enum CodingKeys: String, CodingKey {
            case sid = "emb-sid"
            case sdk = "emb-sdk"
        }
    }
    let user: User
}

extension KarlCrashReport {
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let microseconds = Int64(date.timeIntervalSince1970 * 1_000_000)
            try container.encode(microseconds)
        }
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}
