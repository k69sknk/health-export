import Foundation

struct GeoPoint: Codable, Hashable {
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var accuracy: Double?
    var speedMps: Double?
    var course: Double?
    var timestamp: Date
}

struct LiveMetrics: Codable, Hashable {
    var heartRate: Double?
    var speedMps: Double?
    var paceSecPerKm: Double?
    var distanceMeters: Double?
    var cadenceSpm: Double?
    var elevationMeters: Double?
    var altitude: Double?
    var verticalOscillationCm: Double?
    var groundContactTimeMs: Double?
    var strideLengthMeters: Double?
    var runningPowerWatts: Double?
    var location: GeoPoint?
}

struct LiveMetricsEnvelope: Codable {
    var event: String
    var workoutId: String
    var timestamp: Date
    var userId: String
    var data: LiveMetrics
}

struct WorkoutSummary: Codable {
    var totalDistanceM: Double
    var durationSeconds: Double
    var avgHeartRate: Double?
    var maxHeartRate: Double?
    var activeCalories: Double?
    var elevationAscendedM: Double?
}

struct WorkoutCompletedEnvelope: Codable {
    var event: String
    var workoutId: String
    var type: String
    var startDate: Date
    var endDate: Date
    var summary: WorkoutSummary
    var timeSeries: [LiveMetricsEnvelope]
    var gpxRoute: String?
}

enum ConnectivityPacket: String {
    case liveMetrics = "live_metrics"
    case workoutCompleted = "workout_completed"
    case settingsSync = "settings_sync"
}
