import Foundation
import MapKit
import CoreLocation
import os

@MainActor
class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    @Published var travelTimeCache: [String: TravelTimeInfo] = [:]
    @Published var isCalculating = false

    private let geocoder = CLGeocoder()
    private var locationManager = CLLocationManager()
    private var currentLocation: CLLocation?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        requestLocationPermission()
    }

    func requestLocationPermission() {
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            #if os(iOS)
            locationManager.requestWhenInUseAuthorization()
            #else
            locationManager.requestAlwaysAuthorization()
            #endif
        case .authorized, .authorizedAlways:
            locationManager.requestLocation()
        default:
            break
        }
    }

    func calculateTravelTime(for event: CalendarEvent) async -> TravelTimeInfo? {
        guard event.hasPhysicalLocation,
              let location = event.location else {
            return nil
        }

        // Check cache first
        if let cached = travelTimeCache[event.id] {
            let cacheAge = Date().timeIntervalSince(cached.calculatedAt)
            if cacheAge < 300 { // 5 minutes
                return cached
            }
        }

        isCalculating = true
        defer { isCalculating = false }

        do {
            // Geocode the destination
            let placemarks = try await geocoder.geocodeAddressString(location)
            guard let placemark = placemarks.first,
                  let destinationLocation = placemark.location else {
                return nil
            }

            // Get current location or use default (user's approximate location)
            let sourceLocation = currentLocation ?? CLLocation(latitude: 37.7749, longitude: -122.4194)

            // Calculate travel time
            let travelInfo = try await calculateRoute(
                from: sourceLocation,
                to: destinationLocation,
                mode: AppSettings.shared.defaultTravelMode
            )

            // Cache the result
            let info = TravelTimeInfo(
                eventId: event.id,
                travelTimeMinutes: travelInfo.travelTimeMinutes,
                distance: travelInfo.distance,
                formattedAddress: placemark.formattedAddress,
                coordinate: destinationLocation.coordinate,
                calculatedAt: Date(),
                leaveByTime: event.startDate.addingTimeInterval(-Double(travelInfo.travelTimeMinutes * 60))
            )

            travelTimeCache[event.id] = info
            return info

        } catch {
            Logger.location.error("Error calculating travel time: \(error.localizedDescription)")
            return nil
        }
    }

    private func calculateRoute(
        from source: CLLocation,
        to destination: CLLocation,
        mode: TravelMode
    ) async throws -> (travelTimeMinutes: Int, distance: Double) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate))

        switch mode {
        case .driving:
            request.transportType = .automobile
        case .walking:
            request.transportType = .walking
        case .transit:
            request.transportType = .transit
        }

        let directions = MKDirections(request: request)

        return try await withCheckedThrowingContinuation { continuation in
            directions.calculate { response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let route = response?.routes.first else {
                    continuation.resume(throwing: LocationError.noRouteFound)
                    return
                }

                let travelTimeMinutes = Int(ceil(route.expectedTravelTime / 60))
                let distanceKm = route.distance / 1000

                continuation.resume(returning: (travelTimeMinutes, distanceKm))
            }
        }
    }

    func formatTravelTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours) hr"
            } else {
                return "\(hours) hr \(mins) min"
            }
        }
    }

    func formatDistance(_ km: Double) -> String {
        if km < 1 {
            return String(format: "%.0f m", km * 1000)
        } else {
            return String(format: "%.1f km", km)
        }
    }

    func shouldShowLeaveByAlert(for event: CalendarEvent) -> Bool {
        guard let travelInfo = travelTimeCache[event.id],
              AppSettings.shared.showTravelTimeAlerts else {
            return false
        }

        let now = Date()
        let leaveBy = travelInfo.leaveByTime

        // Show alert if we're within 5 minutes of leave time
        let timeDifference = leaveBy.timeIntervalSince(now)
        return timeDifference > 0 && timeDifference <= 300 // 5 minutes
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.currentLocation = locations.last
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Logger.location.error("Location error: \(error.localizedDescription)")
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if status == .authorized || status == .authorizedAlways {
                self.locationManager.requestLocation()
            }
        }
    }
}

// MARK: - Supporting Types

struct TravelTimeInfo: Codable {
    let eventId: String
    let travelTimeMinutes: Int
    let distance: Double
    let formattedAddress: String
    private let coordinateData: CodableCoordinate
    let calculatedAt: Date
    let leaveByTime: Date

    var coordinate: CLLocationCoordinate2D {
        coordinateData.clCoordinate
    }

    var shouldLeaveNow: Bool {
        Date() >= leaveByTime
    }

    var timeUntilLeave: String {
        let interval = leaveByTime.timeIntervalSince(Date())
        if interval <= 0 {
            return "Leave now!"
        }

        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "Leave in \(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "Leave in \(hours)h \(mins)m"
        }
    }

    init(eventId: String, travelTimeMinutes: Int, distance: Double, formattedAddress: String, coordinate: CLLocationCoordinate2D, calculatedAt: Date, leaveByTime: Date) {
        self.eventId = eventId
        self.travelTimeMinutes = travelTimeMinutes
        self.distance = distance
        self.formattedAddress = formattedAddress
        self.coordinateData = CodableCoordinate(coordinate)
        self.calculatedAt = calculatedAt
        self.leaveByTime = leaveByTime
    }
}

// Wrapper to make CLLocationCoordinate2D Codable without extending imported type
struct CodableCoordinate: Codable {
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}

extension CLPlacemark {
    var formattedAddress: String {
        var components: [String] = []

        if let subThoroughfare = subThoroughfare {
            components.append(subThoroughfare)
        }
        if let thoroughfare = thoroughfare {
            components.append(thoroughfare)
        }
        if let locality = locality {
            components.append(locality)
        }
        if let administrativeArea = administrativeArea {
            components.append(administrativeArea)
        }

        return components.joined(separator: ", ")
    }
}

enum LocationError: Error {
    case noRouteFound
    case geocodingFailed
    case permissionDenied
}
