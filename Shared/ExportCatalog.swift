import Foundation

/// Catalogue de ce que l’Apple Watch / HealthKit peut fournir pour la course à pied.
struct ExportableField: Identifiable, Hashable {
    var id: String { key }
    let group: String
    let key: String
    let title: String
    let source: String
    let live: Bool
    let notes: String
}

enum ExportCatalog {
    static let fields: [ExportableField] = [
        .init(group: "Séance", key: "workout_id", title: "Identifiant de séance", source: "HealthKit", live: true, notes: "UUID de la HKWorkoutSession"),
        .init(group: "Séance", key: "activity_type", title: "Type d’activité", source: "HealthKit", live: true, notes: "running, trail, walking…"),
        .init(group: "Séance", key: "location_type", title: "Extérieur / intérieur", source: "HealthKit", live: true, notes: "HKWorkoutSessionLocationType"),
        .init(group: "Séance", key: "start_date", title: "Début", source: "HealthKit", live: true, notes: ""),
        .init(group: "Séance", key: "end_date", title: "Fin", source: "HealthKit", live: false, notes: ""),
        .init(group: "Séance", key: "duration", title: "Durée", source: "HealthKit", live: true, notes: "Hors pauses si événement pause"),
        .init(group: "Séance", key: "events", title: "Pauses, reprises, tours", source: "HealthKit", live: true, notes: "HKWorkoutEvent"),
        .init(group: "Séance", key: "splits", title: "Splits km / mi", source: "Calculé", live: false, notes: "Dérivés de la distance + horodatage"),

        .init(group: "Tracé", key: "latitude", title: "Latitude", source: "Core Location", live: true, notes: "Plan de course"),
        .init(group: "Tracé", key: "longitude", title: "Longitude", source: "Core Location", live: true, notes: ""),
        .init(group: "Tracé", key: "altitude", title: "Altitude GPS", source: "Core Location", live: true, notes: ""),
        .init(group: "Tracé", key: "horizontal_accuracy", title: "Précision horizontale", source: "Core Location", live: true, notes: ""),
        .init(group: "Tracé", key: "vertical_accuracy", title: "Précision verticale", source: "Core Location", live: true, notes: ""),
        .init(group: "Tracé", key: "course", title: "Cap", source: "Core Location", live: true, notes: "Direction du déplacement"),
        .init(group: "Tracé", key: "gps_speed", title: "Vitesse GPS", source: "Core Location", live: true, notes: ""),
        .init(group: "Tracé", key: "workout_route", title: "Route HealthKit", source: "HKWorkoutRoute", live: false, notes: "Série CLLocation enregistrée avec la séance"),
        .init(group: "Tracé", key: "gpx", title: "Fichier GPX", source: "Export", live: false, notes: "Tracé partageable"),

        .init(group: "Cardio", key: "heart_rate", title: "Fréquence cardiaque", source: "HealthKit", live: true, notes: "bpm"),
        .init(group: "Cardio", key: "avg_heart_rate", title: "FC moyenne", source: "HealthKit", live: false, notes: ""),
        .init(group: "Cardio", key: "max_heart_rate", title: "FC max", source: "HealthKit", live: false, notes: ""),
        .init(group: "Cardio", key: "hr_zones", title: "Zones cardiaques", source: "Calculé", live: true, notes: "À partir des seuils utilisateur"),
        .init(group: "Cardio", key: "heart_rate_recovery", title: "Récupération FC", source: "HealthKit", live: false, notes: "Après l’effort"),
        .init(group: "Cardio", key: "hrv_sdnn", title: "VFC (SDNN)", source: "HealthKit", live: false, notes: "Rare pendant la course"),

        .init(group: "Allure", key: "distance", title: "Distance", source: "HealthKit", live: true, notes: "HKQuantityType.distanceWalkingRunning"),
        .init(group: "Allure", key: "speed", title: "Vitesse", source: "HealthKit", live: true, notes: "runningSpeed ou GPS"),
        .init(group: "Allure", key: "pace", title: "Allure min/km", source: "Calculé", live: true, notes: ""),
        .init(group: "Allure", key: "cadence", title: "Cadence", source: "HealthKit / Motion", live: true, notes: "pas/min"),
        .init(group: "Allure", key: "step_count", title: "Pas", source: "HealthKit", live: true, notes: ""),

        .init(group: "Relief", key: "elevation_ascended", title: "Dénivelé positif", source: "HealthKit", live: true, notes: "Métadonnée workout + GPS"),
        .init(group: "Relief", key: "elevation_descended", title: "Dénivelé négatif", source: "Calculé", live: false, notes: ""),
        .init(group: "Relief", key: "flights_climbed", title: "Étages", source: "HealthKit", live: true, notes: "Moins pertinent outdoor"),

        .init(group: "Dynamique", key: "running_power", title: "Puissance de course", source: "HealthKit", live: true, notes: "watchOS / Series récentes"),
        .init(group: "Dynamique", key: "stride_length", title: "Longueur de foulée", source: "HealthKit", live: true, notes: "iOS 16+"),
        .init(group: "Dynamique", key: "vertical_oscillation", title: "Oscillation verticale", source: "HealthKit", live: true, notes: "iOS 16+"),
        .init(group: "Dynamique", key: "ground_contact_time", title: "Temps de contact au sol", source: "HealthKit", live: true, notes: "iOS 16+"),

        .init(group: "Énergie", key: "active_energy", title: "Calories actives", source: "HealthKit", live: true, notes: ""),
        .init(group: "Énergie", key: "basal_energy", title: "Calories basales", source: "HealthKit", live: false, notes: ""),
        .init(group: "Énergie", key: "mets", title: "METs", source: "HealthKit metadata", live: false, notes: ""),

        .init(group: "Contexte", key: "weather_temperature", title: "Température", source: "Metadata", live: false, notes: "Si fournie par Santé"),
        .init(group: "Contexte", key: "weather_humidity", title: "Humidité", source: "Metadata", live: false, notes: ""),
        .init(group: "Contexte", key: "time_zone", title: "Fuseau", source: "Foundation", live: true, notes: ""),
        .init(group: "Contexte", key: "source_device", title: "Appareil source", source: "HealthKit", live: false, notes: "Watch vs iPhone"),

        .init(group: "Hors séance", key: "vo2_max", title: "VO₂ max", source: "HealthKit", live: false, notes: "Estimé après plusieurs sorties"),
        .init(group: "Hors séance", key: "resting_heart_rate", title: "FC repos", source: "HealthKit", live: false, notes: ""),
        .init(group: "Hors séance", key: "walking_steadiness", title: "Stabilité de marche", source: "HealthKit", live: false, notes: ""),
        .init(group: "Hors séance", key: "sleep", title: "Sommeil", source: "HealthKit", live: false, notes: "Export historique, pas live course")
    ]

    static var grouped: [(String, [ExportableField])] {
        Dictionary(grouping: fields, by: \.group)
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }
}

enum GPXBuilder {
    static func make(name: String, points: [GeoPoint]) -> String {
        let iso = ISO8601DateFormatter()
        var body = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Health Export" xmlns="http://www.topografix.com/GPX/1/1">
          <trk>
            <name>\(xml(name))</name>
            <trkseg>
        """
        for point in points {
            body += "\n              <trkpt lat=\"\(point.latitude)\" lon=\"\(point.longitude)\">"
            if let altitude = point.altitude {
                body += "\n                <ele>\(altitude)</ele>"
            }
            body += "\n                <time>\(iso.string(from: point.timestamp))</time>"
            body += "\n              </trkpt>"
        }
        body += """

            </trkseg>
          </trk>
        </gpx>
        """
        return body
    }

    private static func xml(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
