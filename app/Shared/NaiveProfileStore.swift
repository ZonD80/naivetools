import Foundation
import os

struct NaiveProfileLibrary: Codable, Equatable {
    var profiles: [NaiveServerProfile]
    var selectedProfileID: UUID

    init(profiles: [NaiveServerProfile], selectedProfileID: UUID? = nil) {
        let normalizedProfiles = profiles.isEmpty ? [NaiveServerProfile(name: L10n.configName(1))] : profiles
        self.profiles = normalizedProfiles
        self.selectedProfileID = selectedProfileID.flatMap { id in
            normalizedProfiles.contains(where: { $0.id == id }) ? id : nil
        } ?? normalizedProfiles[0].id
    }

    var selectedProfile: NaiveServerProfile {
        profiles.first(where: { $0.id == selectedProfileID }) ?? profiles[0]
    }
}

enum NaiveProfileStore {
    private static let logger = Logger(category: "NaiveProfileStore")
    private static let libraryKey = "naive.server.profile.library"
    private static let legacyKey = "naive.server.profile"

    static func loadLibrary() -> NaiveProfileLibrary {
        if let data = UserDefaults.standard.data(forKey: libraryKey) {
            do {
                return normalize(try JSONDecoder().decode(NaiveProfileLibrary.self, from: data))
            } catch {
                logger.error("Failed to decode saved profile library: \(error.localizedDescription, privacy: .public)")
            }
        }

        if let data = UserDefaults.standard.data(forKey: legacyKey) {
            do {
                var profile = try JSONDecoder().decode(NaiveServerProfile.self, from: data)
                if profile.trimmedName.isEmpty {
                    profile.name = L10n.configName(1)
                }

                let library = NaiveProfileLibrary(profiles: [profile], selectedProfileID: profile.id)
                saveLibrary(library)
                UserDefaults.standard.removeObject(forKey: legacyKey)
                return library
            } catch {
                logger.error("Failed to migrate legacy profile: \(error.localizedDescription, privacy: .public)")
            }
        }

        return NaiveProfileLibrary(profiles: [NaiveServerProfile(name: L10n.configName(1))])
    }

    static func saveLibrary(_ library: NaiveProfileLibrary) {
        do {
            let normalizedLibrary = normalize(library)
            let data = try JSONEncoder().encode(normalizedLibrary)
            UserDefaults.standard.set(data, forKey: libraryKey)
        } catch {
            logger.error("Failed to save profile library: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func normalize(_ library: NaiveProfileLibrary) -> NaiveProfileLibrary {
        var profiles = library.profiles
        if profiles.isEmpty {
            profiles = [NaiveServerProfile(name: L10n.configName(1))]
        }

        for index in profiles.indices {
            if profiles[index].trimmedName.isEmpty && profiles[index].trimmedHost.isEmpty {
                profiles[index].name = L10n.configName(index + 1)
            }
        }

        return NaiveProfileLibrary(profiles: profiles, selectedProfileID: library.selectedProfileID)
    }
}
