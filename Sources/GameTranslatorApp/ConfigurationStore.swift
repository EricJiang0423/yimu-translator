import Foundation
import GameTranslatorCore

final class ConfigurationStore {
    private let defaults: UserDefaults
    private let key = "Yimu.configuration"
    private let legacyKeys = ["GameTranslator.configuration"]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var configuration: AppConfiguration {
        get {
            if let data = defaults.data(forKey: key),
               let decoded = try? JSONDecoder().decode(AppConfiguration.self, from: data) {
                return decoded
            }
            for legacyKey in legacyKeys {
                if let data = defaults.data(forKey: legacyKey),
                   let decoded = try? JSONDecoder().decode(AppConfiguration.self, from: data) {
                    return decoded
                }
            }
            return .defaults
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: key)
            }
        }
    }
}
