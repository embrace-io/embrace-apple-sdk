//
//  Copyright © 2025 Embrace Mobile, Inc. All rights reserved.
//

import Foundation

@objc public enum CrashSignal: Int {
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

/// Mach exception types, matching the `EXC_*` constants from <mach/exception_types.h>
@objc public enum MachException: Int64, CaseIterable {
    /// Could not access memory.
    /// - code: `kern_return_t` describing the error.
    /// - subcode: Bad memory address.
    case `EXC_BAD_ACCESS` = 1

    /// Instruction failed.
    /// Illegal or undefined instruction or operand.
    case `EXC_BAD_INSTRUCTION` = 2

    /// Arithmetic exception.
    /// Exact nature of exception is in `code` field.
    case `EXC_ARITHMETIC` = 3

    /// Emulation instruction encountered.
    /// Details in `code` and `subcode` fields.
    case `EXC_EMULATION` = 4

    /// Software-generated exception.
    /// - code: Exact exception.
    /// - Codes 0–0xFFFF reserved to hardware.
    /// - Codes 0x10000–0x1FFFF reserved for OS emulation (Unix).
    case `EXC_SOFTWARE` = 5

    /// Trace, breakpoint, etc.
    /// Details in `code` field.
    case `EXC_BREAKPOINT` = 6

    /// System calls.
    case `EXC_SYSCALL` = 7

    /// Mach system calls.
    case `EXC_MACH_SYSCALL` = 8

    /// RPC alert.
    case `EXC_RPC_ALERT` = 9

    /// Abnormal process exit.
    case `EXC_CRASH` = 10

    /// Hit resource consumption limit.
    /// Exact resource is in `code` field.
    case `EXC_RESOURCE` = 11

    /// Violated guarded resource protections.
    case `EXC_GUARD` = 12

    /// Abnormal process exited to corpse state.
    case `EXC_CORPSE_NOTIFY` = 13
}

extension MachException {
    public var name: String {
        switch self {
        case .EXC_BAD_ACCESS: return "EXC_BAD_ACCESS"
        case .EXC_BAD_INSTRUCTION: return "EXC_BAD_INSTRUCTION"
        case .EXC_ARITHMETIC: return "EXC_ARITHMETIC"
        case .EXC_EMULATION: return "EXC_EMULATION"
        case .EXC_SOFTWARE: return "EXC_SOFTWARE"
        case .EXC_BREAKPOINT: return "EXC_BREAKPOINT"
        case .EXC_SYSCALL: return "EXC_SYSCALL"
        case .EXC_MACH_SYSCALL: return "EXC_MACH_SYSCALL"
        case .EXC_RPC_ALERT: return "EXC_RPC_ALERT"
        case .EXC_CRASH: return "EXC_CRASH"
        case .EXC_RESOURCE: return "EXC_RESOURCE"
        case .EXC_GUARD: return "EXC_GUARD"
        case .EXC_CORPSE_NOTIFY: return "EXC_CORPSE_NOTIFY"
        }
    }
}
