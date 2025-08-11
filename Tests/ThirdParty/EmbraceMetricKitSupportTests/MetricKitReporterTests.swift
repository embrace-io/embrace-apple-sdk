//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import EmbraceCommonInternal
import TestSupport
import XCTest

@testable import EmbraceMetricKitSupport

class MetricKitReporterTests: XCTestCase {

    func reportNamed(_ name: String) -> URL {
        Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "MetricKitReports")!
    }

    func test_load() {

        let data = (try? Data(contentsOf: reportNamed("crash_diagnostic_01"), options: []))!
        let report = MetricKitDiagnosticReport.with(data)
        XCTAssertNotNil(report)
        XCTAssertEqual(report?.version, "1.0.0")
        XCTAssertEqual(report?.metaData.platformArchitecture, "arm64e")
        XCTAssertEqual(report?.metaData.exceptionType, 10)
        XCTAssertEqual(report?.metaData.appBuildVersion, "51")
        XCTAssertEqual(report?.metaData.isTestFlightApp, false)
        XCTAssertEqual(report?.metaData.osVersion, "iPhone OS 26.0 (23A5297m)")
        XCTAssertEqual(report?.metaData.bundleIdentifier, "com.bedroomcode.Splash")
        XCTAssertEqual(report?.metaData.deviceType, "iPhone17,1")
        XCTAssertEqual(report?.metaData.exceptionCode, 0)
        XCTAssertEqual(report?.metaData.signal, 6)
        XCTAssertEqual(report?.metaData.regionFormat, "US")
        XCTAssertEqual(report?.metaData.appVersion, "1.0.0")
        XCTAssertEqual(report?.metaData.pid, 15713)
        XCTAssertEqual(report?.metaData.lowPowerModeEnabled, false)
    }

    func test_binaryImages() {

        let data = (try? Data(contentsOf: reportNamed("crash_diagnostic_01"), options: []))!
        let report = MetricKitDiagnosticReport.with(data)!
        XCTAssertNotNil(report)

        let binaryImages = report.callStackTree.binaryImages
        XCTAssertEqual(binaryImages.count, 22)
    }

    func test_threads() {

        let data = (try? Data(contentsOf: reportNamed("crash_diagnostic_01"), options: []))!
        let report = MetricKitDiagnosticReport.with(data)!
        XCTAssertNotNil(report)

        let threads = report.callStackTree.threads

        XCTAssertEqual(threads.count, report.callStackTree.callStacks.count)
        XCTAssertEqual(threads.count, 13)

        for x in (0..<threads.count) {
            XCTAssertEqual(threads[x].crashed, cd01ThreadSummaries[x].crashed)
            XCTAssertEqual(threads[x].backtrace.contents.count, cd01ThreadSummaries[x].expectedFrameCount)
        }
    }

    private func findBinary(_ offset: UInt64, _ bins: [KarlCrashReport.BinaryImage]) -> KarlCrashReport.BinaryImage? {
        return
            bins
            .sorted { $0.imageAddr < $1.imageAddr }
            .first {
                if offset < $0.imageAddr {
                    return false
                }
                if offset >= $0.imageAddr + $0.imageSize {
                    return false
                }
                return true
            }
    }

    func test_fakeSymbolicate() throws {

        let data = (try? Data(contentsOf: reportNamed("crash_diagnostic_01"), options: []))!
        let report = MetricKitDiagnosticReport.with(data)!
        XCTAssertNotNil(report)

        struct Line {
            let instructionAddress: UInt64
            let module: String
            let symbol: String?
            var uuid: String? = nil
            var modulePath: String? = nil
            var moduleOffset: UInt64? = nil
            var symbolOffset: UInt64? = nil
        }

        for v in report.callStackTree.threads {
            for l in v.backtrace.contents {

                let instructionAddress = l.instructionAddr
                var frame = Line(
                    instructionAddress: l.instructionAddr,
                    module: l.objectName,
                    symbol: l.symbolName
                )
                let bin = try XCTUnwrap(findBinary(instructionAddress, report.callStackTree.binaryImages))

                frame.uuid = bin.uuid
                frame.moduleOffset = instructionAddress - l.objectAddr
                frame.symbolOffset = instructionAddress - l.symbolAddr
            }
        }
    }

    func test_diagnose() throws {

        let data = (try? Data(contentsOf: reportNamed("crash_diagnostic_01"), options: []))!
        let report = MetricKitDiagnosticReport.with(data)!
        XCTAssertNotNil(report)

        let diagnosis = CrashDiagnosisFormatter().diagnosis(from: report)
        XCTAssertNotNil(diagnosis)
        XCTAssertEqual(diagnosis, "EXC_CRASH (SIGABRT)")
    }

    func test_diagnoseWithTermReason() throws {

        let data = (try? Data(contentsOf: reportNamed("crash_with_term_reason"), options: []))!
        let report = MetricKitDiagnosticReport.with(data)!
        XCTAssertNotNil(report)

        let diagnosis = CrashDiagnosisFormatter().diagnosis(from: report)
        XCTAssertNotNil(diagnosis)
        XCTAssertEqual(diagnosis, "EXC_CRASH (SIGKILL) 0x8BADF00D")
    }

    func test_signposts() throws {

        let data = (try? Data(contentsOf: reportNamed("crash_with_signposts"), options: []))!
        let report = MetricKitDiagnosticReport.with(data)!
        XCTAssertNotNil(report)
        XCTAssertNotNil(report.metaData.signpostData)
        XCTAssertEqual(report.metaData.signpostData?.count, 3)
    }
}

struct ThreadSummary: Equatable {
    let thread: Int
    let expectedFrameCount: Int
    let crashed: Bool
    let frameAddresses: [UInt64]
}

let cd01ThreadSummaries: [ThreadSummary] = [
    ThreadSummary(
        thread: 0, expectedFrameCount: 64, crashed: true,
        frameAddresses: [
            0x1_DEE6_B0CC, 0x2_194F_67E8, 0x1_91AC_39E8, 0x1_0213_92E8, 0x2_1944_0118, 0x2_194F_67E8, 0x1_91AF_EF1C,
            0x2_1941_7808, 0x2_1940_6484, 0x1_8640_3F08, 0x1_0213_82D0, 0x2_1941_6BDC, 0x2_1941_A314, 0x2_1941_A2BC,
            0x1_8640_190C, 0x1_8927_9904, 0x1_025B_BAA0, 0x1_8EB6_B0F4, 0x1_8EA9_0ECC, 0x1_8F13_E23C, 0x1_8F11_3390,
            0x1_8E67_A35C, 0x1_8E2A_5CDC, 0x1_8EA3_2F18, 0x1_8EA3_8E34, 0x1_8E2A_5CDC, 0x1_8E7D_91E4, 0x2_5458_0648,
            0x2_5457_FB48, 0x2_545F_5D5C, 0x1_8EBE_5D08, 0x1_8EBE_CA60, 0x1_8C90_87C4, 0x1_8C93_55A4, 0x1_8C93_5870,
            0x1_8BF1_7BC8, 0x1_8BF1_7BC8, 0x1_8BF1_7BC8, 0x1_8BF1_7BC8, 0x1_8D23_2F38, 0x1_8D23_4398, 0x1_022F_C61C,
            0x1_022F_C690, 0x1_8D21_7530, 0x1_8BF1_A964, 0x1_8BF2_9B48, 0x1_8BF1_C87C, 0x1_8BF2_ACF8, 0x1_8BF2_A094,
            0x2_9CA9_B640, 0x1_8921_A310, 0x1_8921_A284, 0x1_891F_7D4C, 0x1_891C_D990, 0x1_891C_CD24, 0x1_DACA_4498,
            0x1_8BF5_4428, 0x1_8BEF_30B8, 0x1_8E24_B464, 0x1_8E24_7FC0, 0x1_8E24_7AAC, 0x1_0217_ABD4, 0x1_0217_D634,
            0x1_8645_5B18
        ]),
    ThreadSummary(
        thread: 1, expectedFrameCount: 39, crashed: false,
        frameAddresses: [
            0x1_DEE6_0C50, 0x1_91A4_38F0, 0x1_91A4_3EA0, 0x1_0213_66F8, 0x1_0264_A184, 0x1_0264_CDB0, 0x1_0264_CCE4,
            0x1_0264_A440, 0x1_0264_A044, 0x1_0264_A440, 0x1_0264_A440, 0x1_0264_A110, 0x1_0264_A044, 0x1_0264_CF48,
            0x1_0264_D014, 0x1_0264_D014, 0x1_0264_D0E0, 0x1_0264_CB4C, 0x1_0264_D014, 0x1_0264_A044, 0x1_0264_D1AC,
            0x1_0264_A1DC, 0x1_0264_CE7C, 0x1_0264_CDB0, 0x1_0264_A440, 0x1_0264_CE7C, 0x1_0264_CE7C, 0x1_0264_D014,
            0x1_0264_CC18, 0x1_0264_CCE4, 0x1_0264_CA80, 0x1_0264_D0E0, 0x1_0264_CE7C, 0x1_0264_A044, 0x1_0264_CA80,
            0x1_0264_D0E0, 0x1_0213_6B98, 0x2_194F_3424, 0x2_194E_F8CC
        ]),
    ThreadSummary(
        thread: 2, expectedFrameCount: 9, crashed: false,
        frameAddresses: [
            0x1_DEE6_0CD4, 0x1_DEE6_42F8, 0x1_DEE6_4214, 0x1_DEE6_405C, 0x1_0213_51E4, 0x1_0213_4C98, 0x1_0213_4B4C,
            0x2_194F_3424, 0x2_194E_F8CC
        ]),
    ThreadSummary(
        thread: 3, expectedFrameCount: 17, crashed: false,
        frameAddresses: [
            0x1_DEE6_0CD4, 0x1_DEE6_42F8, 0x1_DEE6_4214, 0x1_DEE6_405C, 0x1_91A5_CE64, 0x1_91A5_D204, 0x2_1954_ADE8,
            0x1_B59B_9954, 0x1_9778_20F4, 0x1_91A4_1ABC, 0x1_91A5_B7CC, 0x1_91A4_6644, 0x1_91A4_5CB8, 0x1_91A5_3F28,
            0x1_91A5_46DC, 0x2_194F_037C, 0x2_194E_F8C0
        ]),
    ThreadSummary(
        thread: 4, expectedFrameCount: 12, crashed: false,
        frameAddresses: [
            0x1_DEE6_0C50, 0x1_91A4_38F0, 0x1_91A4_3EA0, 0x1_0261_E9A4, 0x1_0261_EB7C, 0x1_91A4_1ABC, 0x1_91A5_B7CC,
            0x1_91A7_83F8, 0x1_91A5_409C, 0x1_91A5_46DC, 0x2_194F_037C, 0x2_194E_F8C0
        ]),
    ThreadSummary(thread: 5, expectedFrameCount: 0, crashed: false, frameAddresses: []),
    ThreadSummary(
        thread: 6, expectedFrameCount: 23, crashed: false,
        frameAddresses: [
            0x1_DEE6_0CD4, 0x1_DEE6_42F8, 0x1_91A6_0A80, 0x1_91A6_0280, 0x1_91A5_CADC, 0x1_91A5_D2FC, 0x2_1954_9C20,
            0x2_1954_AC7C, 0x1_8864_8FDC, 0x1_8864_8538, 0x1_87C1_8188, 0x1_C52A_1850, 0x1_C52C_66CC, 0x1_C52B_71E4,
            0x1_C52B_E584, 0x1_91A4_1ABC, 0x1_91A5_B7CC, 0x1_91A4_A448, 0x1_91A4_AF24, 0x1_91A5_53CC, 0x1_91A5_4CC4,
            0x2_194F_03B8, 0x2_194E_F8C0
        ]),
    ThreadSummary(
        thread: 7, expectedFrameCount: 13, crashed: false,
        frameAddresses: [
            0x1_DEE6_0CD4, 0x1_DEE6_42F8, 0x1_DEE6_4214, 0x1_DEE6_405C, 0x1_891F_7AE8, 0x1_891C_DB00, 0x1_891C_CD24,
            0x1_8857_AB44, 0x1_8857_AD1C, 0x1_8BF1_FBEC, 0x1_87C3_8DF8, 0x2_194F_3424, 0x2_194E_F8CC
        ]),
    ThreadSummary(
        thread: 8, expectedFrameCount: 23, crashed: false,
        frameAddresses: [
            0x1_AB27_6F88, 0x1_AB27_6DF8, 0x1_AB27_3BB4, 0x1_AB2B_2658, 0x1_AB27_6598, 0x1_AB29_4F34, 0x1_AB29_4E0C,
            0x1_AB28_6488, 0x1_C52B_AFF0, 0x1_8C15_31F8, 0x1_8C15_3AEC, 0x1_8C15_399C, 0x1_8CBE_1440, 0x1_8C0B_2840,
            0x1_8CBE_A304, 0x1_91A4_1ABC, 0x1_91A5_B7CC, 0x1_91A4_A448, 0x1_91A4_AF24, 0x1_91A5_53CC, 0x1_91A5_4CC4,
            0x2_194F_03B8, 0x2_194E_F8C0
        ]),
    ThreadSummary(
        thread: 9, expectedFrameCount: 6, crashed: false,
        frameAddresses: [0x1_DEE6_0C50, 0x2_1D03_E43C, 0x2_1D03_E488, 0x2_1D04_2BF4, 0x2_194F_3424, 0x2_194E_F8CC]),
    ThreadSummary(
        thread: 10, expectedFrameCount: 6, crashed: false,
        frameAddresses: [0x1_DEE6_0C50, 0x2_1D03_E43C, 0x2_1D03_E488, 0x2_1D04_2BF4, 0x2_194F_3424, 0x2_194E_F8CC]),
    ThreadSummary(
        thread: 11, expectedFrameCount: 19, crashed: false,
        frameAddresses: [
            0x1_891D_493C, 0x1_891B_25EC, 0x1_87BF_099C, 0x1_863D_5498, 0x1_863D_5324, 0x1_8864_98E4, 0x1_8864_9034,
            0x1_891F_6448, 0x1_891F_E480, 0x1_AB27_78B0, 0x1_AB27_77B0, 0x1_91A4_1ABC, 0x1_91A5_B7CC, 0x1_91A4_A448,
            0x1_91A4_AF58, 0x1_91A5_3F28, 0x1_91A5_3CE8, 0x2_194F_3424, 0x2_194E_F8CC
        ]),
    ThreadSummary(thread: 12, expectedFrameCount: 0, crashed: false, frameAddresses: [])
]
