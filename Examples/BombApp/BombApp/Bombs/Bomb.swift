//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

enum Bomb: String, CaseIterable {
    case callAbort
    case stackGuard
    case NULL
    case asyncSafeThread
    case CXXException
    case corruptObjC
    case ROPage
    case NXPage
    case garbage
    case undefInst
    case objCException
    case smashStackTop
    case privInst
    case corruptMalloc
    case ObjCMsgSend
    case smashStackBottom
    case overwriteLinkRegister
    case releasedObject
    case trap
    case NSLog
    case swift
    case internalConsistency
    case swiftFatal
    case embraceTest
    case embraceTestIndexOutOfBounds
    case embraceForceOutOfMemory
    case embraceHangMainThread

    var `case`: CRLCrash {
        switch self {
        case .callAbort: return CRLCrashAbort()
        case .stackGuard: return CRLCrashStackGuard()
        case .NULL: return CRLCrashNULL()
        case .asyncSafeThread: return CRLCrashAsyncSafeThread()
        case .CXXException: return CRLCrashCXXException()
        case .corruptObjC: return CRLCrashCorruptObjC()
        case .ROPage: return CRLCrashROPage()
        case .NXPage: return CRLCrashNXPage()
        case .garbage: return CRLCrashGarbage()
        case .undefInst: return CRLCrashUndefInst()
        case .objCException: return CRLCrashObjCException()
        case .smashStackTop: return CRLCrashSmashStackTop()
        case .privInst: return CRLCrashPrivInst()
        case .corruptMalloc: return CRLCrashCorruptMalloc()
        case .ObjCMsgSend: return CRLCrashObjCMsgSend()
        case .smashStackBottom: return CRLCrashSmashStackBottom()
        case .overwriteLinkRegister: return CRLCrashOverwriteLinkRegister()
        case .releasedObject: return CRLCrashReleasedObject()
        case .trap: return CRLCrashTrap()
        case .NSLog: return CRLCrashNSLog()
        case .swift: return CRLCrashSwift()
        case .internalConsistency: return InternalConsistency()
        case .swiftFatal: return SwiftFatal()
        case .embraceTest: return EmbraceTestCrash()
        case .embraceTestIndexOutOfBounds: return EmbraceTestIndexOutOfBounds()
        case .embraceForceOutOfMemory: return EmbraceForceOutMemory()
        case .embraceHangMainThread: return EmbraceHangMainThread()
        }
    }

    var generatesImmediateCrash: Bool {
        switch self {
        case .embraceForceOutOfMemory, .embraceHangMainThread:
            return false
        default:
            return true
        }
    }
}
