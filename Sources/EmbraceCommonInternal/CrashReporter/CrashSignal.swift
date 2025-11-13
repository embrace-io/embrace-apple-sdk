//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@objc public enum CrashSignal: Int, Sendable {
    case SIGHUP = 1
    case SIGINT = 2
    case SIGQUIT = 3
    case SIGILL = 4
    case SIGTRAP = 5
    case SIGABRT = 6
    case SIGEMT = 7
    case SIGFPE = 8
    case SIGKILL = 9
    case SIGBUS = 10
    case SIGSEGV = 11
    case SIGSYS = 12
    case SIGPIPE = 13
    case SIGALRM = 14
    case SIGTERM = 15
    case SIGURG = 16
    case SIGSTOP = 17
    case SIGTSTP = 18
    case SIGCONT = 19
    case SIGCHLD = 20
    case SIGTTIN = 21
    case SIGTTOU = 22
    case SIGIO = 23
    case SIGXCPU = 24
    case SIGXFSZ = 25
    case SIGVTALRM = 26
    case SIGPROF = 27
    case SIGWINCH = 28
    case SIGINFO = 29
    case SIGUSR1 = 30
    case SIGUSR2 = 31
    case SIGTHR = 32
}

extension CrashSignal {
    public static func from(string: String) -> CrashSignal? {
        switch string.uppercased() {
        case "SIGHUP": return SIGHUP
        case "SIGINT": return SIGINT
        case "SIGQUIT": return SIGQUIT
        case "SIGILL": return SIGILL
        case "SIGTRAP": return SIGTRAP
        case "SIGABRT": return SIGABRT
        case "SIGEMT": return SIGEMT
        case "SIGFPE": return SIGFPE
        case "SIGKILL": return SIGKILL
        case "SIGBUS": return SIGBUS
        case "SIGSEGV": return SIGSEGV
        case "SIGSYS": return SIGSYS
        case "SIGPIPE": return SIGPIPE
        case "SIGALRM": return SIGALRM
        case "SIGTERM": return SIGTERM
        case "SIGURG": return SIGURG
        case "SIGSTOP": return SIGSTOP
        case "SIGTSTP": return SIGTSTP
        case "SIGCONT": return SIGCONT
        case "SIGCHLD": return SIGCHLD
        case "SIGTTIN": return SIGTTIN
        case "SIGTTOU": return SIGTTOU
        case "SIGIO": return SIGIO
        case "SIGXCPU": return SIGXCPU
        case "SIGXFSZ": return SIGXFSZ
        case "SIGVTALRM": return SIGVTALRM
        case "SIGPROF": return SIGPROF
        case "SIGWINCH": return SIGWINCH
        case "SIGINFO": return SIGINFO
        case "SIGUSR1": return SIGUSR1
        case "SIGUSR2": return SIGUSR2
        case "SIGTHR": return SIGTHR
        default: return nil
        }
    }

    public var stringValue: String {
        switch self {
        case .SIGHUP: return "SIGHUP"
        case .SIGINT: return "SIGINT"
        case .SIGQUIT: return "SIGQUIT"
        case .SIGILL: return "SIGILL"
        case .SIGTRAP: return "SIGTRAP"
        case .SIGABRT: return "SIGABRT"
        case .SIGEMT: return "SIGEMT"
        case .SIGFPE: return "SIGFPE"
        case .SIGKILL: return "SIGKILL"
        case .SIGBUS: return "SIGBUS"
        case .SIGSEGV: return "SIGSEGV"
        case .SIGSYS: return "SIGSYS"
        case .SIGPIPE: return "SIGPIPE"
        case .SIGALRM: return "SIGALRM"
        case .SIGTERM: return "SIGTERM"
        case .SIGURG: return "SIGURG"
        case .SIGSTOP: return "SIGSTOP"
        case .SIGTSTP: return "SIGTSTP"
        case .SIGCONT: return "SIGCONT"
        case .SIGCHLD: return "SIGCHLD"
        case .SIGTTIN: return "SIGTTIN"
        case .SIGTTOU: return "SIGTTOU"
        case .SIGIO: return "SIGIO"
        case .SIGXCPU: return "SIGXCPU"
        case .SIGXFSZ: return "SIGXFSZ"
        case .SIGVTALRM: return "SIGVTALRM"
        case .SIGPROF: return "SIGPROF"
        case .SIGWINCH: return "SIGWINCH"
        case .SIGINFO: return "SIGINFO"
        case .SIGUSR1: return "SIGUSR1"
        case .SIGUSR2: return "SIGUSR2"
        case .SIGTHR: return "SIGTHR"
        }
    }
}
