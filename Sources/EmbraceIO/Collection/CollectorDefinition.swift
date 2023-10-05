public enum CollectorDefinition: CaseIterable {
    case network
    case uiTap
    case pushNotifications
}

public extension Collection where Element == CollectorDefinition {

    static var none: [CollectorDefinition] { [] }

    static var `default`: [CollectorDefinition] {
        return [
            .network,
            .uiTap,
            .pushNotifications
        ]
    }

}
