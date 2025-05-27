import Foundation

public struct Speedscope: Codable {
    
    struct Frame: Codable, Identifiable, Hashable {
        let name: String
        var file: String? = nil
        var line: Int? = nil
        var col: Int? = nil
        
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
        flatMap { $0 }
    }
}

extension Speedscope {
    
    public static func with(_ profile: EmbraceProfile, filter: (_ frame: EmbraceBacktraceFrame) -> Bool ) -> Speedscope? {
        
        // build the frames
        var frameset = Set<Frame>()
        profile.backtraces.forEach { backtrace in
            backtrace.threads.forEach { thread in
                thread.frames.forEach { frame in
                    if filter(frame) {
                        frameset.insert(
                            Frame(name: frame.symbolName, file: frame.imageName)
                        )
                    }
                }
            }
        }
        
        let frames = Array(frameset)
        
        var samples: [[Int]] = []
        var weight: [UInt64] = []
        
        profile.backtraces.forEach { backtrace in
            if let thread = backtrace.threads.first {
                var stack: [Int] = []
                thread.frames.forEach { frame in
                    if let index = frames.firstIndex(of: Frame(name: frame.symbolName, file: frame.imageName)) {
                        stack.append(index)
                    }
                }
                samples.append(stack)
                weight.append(profile.interval / NSEC_PER_MSEC)
            }
        }
        
        return Speedscope(
            shared: Shared(frames: frames),
            profiles: [
                Profile(
                    type: .sampled,
                    name: profile.name,
                    unit: .milliseconds,
                    startValue: profile.startTime / NSEC_PER_MSEC,
                    endValue: profile.endTime / NSEC_PER_MSEC,
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
