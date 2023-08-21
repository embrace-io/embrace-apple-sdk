public protocol Collector { }

protocol InstalledCollector: Collector {

    func install()

    func start()

    func pause()

    func shutdown()

}

protocol OneTimeCollector: Collector {

    func fire()

}
