//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI

private struct AppSettingsEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppSettings()
}

extension EnvironmentValues {
  var settings: AppSettings {
    get { self[AppSettingsEnvironmentKey.self] }
    set { self[AppSettingsEnvironmentKey.self] = newValue }
  }
}
