public enum CollectorDefinition {
    case network
    case uiTap
    case pushNotifications

    case custom(_ provider: CollectionProvider)
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
