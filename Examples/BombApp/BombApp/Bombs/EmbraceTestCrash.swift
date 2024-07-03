//
//  EmbraceTestCrash.swift
//  BombApp
//
//  Created by Ariel Demarco on 02/07/2024.
//

import EmbraceIO

class EmbraceTestCrash: CRLCrash {
    override var category: String { return "Embrace" }
    override var title: String { return "Embrace Test Crash" }
    override var desc: String { return "Trigger an Embrace test crash" }

    override func crash() {
        Embrace.client?.crash()
    }
}
