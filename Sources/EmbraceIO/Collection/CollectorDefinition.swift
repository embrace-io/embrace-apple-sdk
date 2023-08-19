public enum CollectorDefinition {
    case network
    case uiTap
    case pushNotifications

    case custom(_ provider: CollectorProvider)
}

public extension Collection where Element is CollectorDefinition {

    static var none : Self { [] }

    static var `default`: Self {
        return [
            .network,
            .uiTap,
            .pushNotifications
        ]
    }

}
