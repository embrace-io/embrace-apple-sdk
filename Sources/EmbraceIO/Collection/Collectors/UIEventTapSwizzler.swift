struct UIEventTapSwizzlerProvider: CollectorProvider {

    let minimumTapCount: UInt = 1

    var collector: Collector {
        return UIEventTapSwizzler()
    }
}

class UIEventTapSwizzler {

}
