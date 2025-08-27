import Foundation

public struct Speedscope: Codable {

    struct Frame: Codable, Identifiable, Hashable {
        let name: String
        var file: String?
        var line: Int?
        var col: Int?

        var id: String { "\(name)-\(file ?? "")" }
    }

    struct Shared: Codable {
        let frames: [Frame]
    }

    enum ProfileType: String, Codable {
        case evented
        case sampled
    }

    enum UnitType: String, Codable {
        case nanoseconds
        case milliseconds
    }

    typealias SampledStack = [Int]

    struct Profile: Codable {
        let type: ProfileType
        let name: String
        let unit: UnitType
        let startValue: UInt64
        let endValue: UInt64
        let samples: [SampledStack]
        let weights: [UInt64]
    }

    let shared: Shared
    let profiles: [Profile]
    let name: String
    let activeProfileIndex: Int
    let exporter: String
    let schema: String = "https://www.speedscope.app/file-format-schema.json"

    enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case exporter
        case activeProfileIndex
        case name
        case profiles
        case shared
    }
}

extension Speedscope {
    var totalWeight: UInt64 {
        profiles.first?.weights.reduce(0, { $0 + $1 }) ?? 0
    }
}

extension Array {
    func flatten() -> [Element] {
        compactMap { $0 }
    }
}

extension EmbraceBacktraceFrame {
    func asSpeedscopeFrame() -> Speedscope.Frame? {
        if let symbolName = symbol?.name {
            return Speedscope.Frame(name: symbolName, file: image?.name)
        }
        return nil
    }
}

extension Speedscope {

    public static func with(_ profile: EmbraceProfile, filter: (_ frame: EmbraceBacktraceFrame) -> Bool) -> Speedscope? {

        // build the frames
        var frameset = Set<Frame>()
        profile.backtraces.forEach { backtrace in
            backtrace.threads.forEach { thread in
                thread.frames(symbolicated: true).forEach { frame in
                    if let speedFrame = frame.asSpeedscopeFrame(), filter(frame) {
                        frameset.insert(speedFrame)
                    }
                }
            }
        }

        let frames = Array(frameset)

        var samples: [[Int]] = []
        var weight: [UInt64] = []
        var lastTime = profile.startTime

        profile.backtraces.forEach { backtrace in
            if let thread = backtrace.threads.first {
                var stack: [Int] = []
                thread.frames(symbolicated: true).forEach { frame in
                    if let speedFrame = frame.asSpeedscopeFrame(), let index = frames.firstIndex(of: speedFrame) {
                        // stack.append(index)
                        stack.insert(index, at: 0)
                    }
                }
                samples.append(stack)
                weight.append(backtrace.timestamp - lastTime)
                lastTime = backtrace.timestamp
            }
        }

        return Speedscope(
            shared: Shared(frames: frames),
            profiles: [
                Profile(
                    type: .sampled,
                    name: profile.name,
                    unit: .nanoseconds,
                    startValue: profile.startTime,
                    endValue: lastTime,
                    samples: samples,
                    weights: weight
                )
            ],
            name: profile.name,
            activeProfileIndex: 0,
            exporter: "Embrace"
        )
    }

}
