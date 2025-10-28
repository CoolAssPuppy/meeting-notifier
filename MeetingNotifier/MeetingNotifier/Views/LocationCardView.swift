import SwiftUI
import MapKit

struct LocationCardView: View {
    let event: CalendarEvent
    @StateObject private var locationManager = LocationManager.shared
    @State private var travelInfo: TravelTimeInfo?
    @State private var isExpanded = false
    @State private var mapRegion: MKCoordinateRegion?

    var body: some View {
        if event.hasPhysicalLocation {
            VStack(alignment: .leading, spacing: 0) {
                locationHeader

                if isExpanded {
                    expandedContent
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                            removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
                        ))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .task {
                await loadTravelTime()
            }
        }
    }

    private var locationHeader: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }) {
            HStack(spacing: 12) {
                // Location icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.2), Color.cyan.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.location ?? "Location")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let travelInfo = travelInfo {
                        HStack(spacing: 6) {
                            Image(systemName: AppSettings.shared.defaultTravelMode.icon)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)

                            Text(locationManager.formatTravelTime(travelInfo.travelTimeMinutes))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Text("•")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)

                            Text(locationManager.formatDistance(travelInfo.distance))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    } else if locationManager.isCalculating {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.mini)
                                .scaleEffect(0.7)
                            Text("Calculating...")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary.opacity(0.6))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(12)
        }
        .buttonStyle(.plain)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.horizontal, 12)

            if let travelInfo = travelInfo {
                // Leave by time warning
                leaveBySection(travelInfo: travelInfo)

                // Mini map view
                if let region = mapRegion {
                    mapSection(region: region, coordinate: travelInfo.coordinate)
                }

                // Action buttons
                actionButtons(travelInfo: travelInfo)
            }
        }
        .padding(.bottom, 12)
    }

    private func leaveBySection(travelInfo: TravelTimeInfo) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        travelInfo.shouldLeaveNow ?
                        LinearGradient(
                            colors: [Color.red.opacity(0.2), Color.orange.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.green.opacity(0.2), Color.mint.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: travelInfo.shouldLeaveNow ? "exclamationmark.triangle.fill" : "clock.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(
                        travelInfo.shouldLeaveNow ?
                        LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(travelInfo.shouldLeaveNow ? "Time to leave!" : "Leave by")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Text(travelInfo.shouldLeaveNow ? "Start your journey now" : formatLeaveByTime(travelInfo.leaveByTime))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(travelInfo.shouldLeaveNow ? .red : .primary)
            }

            Spacer()

            if !travelInfo.shouldLeaveNow {
                Text(travelInfo.timeUntilLeave)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.regularMaterial)
                    )
            }
        }
        .padding(.horizontal, 12)
    }

    private func mapSection(region: MKCoordinateRegion, coordinate: CLLocationCoordinate2D) -> some View {
        Map(coordinateRegion: .constant(region),
            annotationItems: [MapAnnotation(coordinate: coordinate)]) { item in
            MapMarker(coordinate: item.coordinate, tint: .blue)
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .allowsHitTesting(false)
    }

    private func actionButtons(travelInfo: TravelTimeInfo) -> some View {
        HStack(spacing: 10) {
            // Open in Maps
            Button(action: {
                openInMaps(coordinate: travelInfo.coordinate)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 12))
                    Text("Open in Maps")
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Recalculate
            Button(action: {
                Task {
                    await loadTravelTime()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                    Text("Update")
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
    }

    private func loadTravelTime() async {
        travelInfo = await locationManager.calculateTravelTime(for: event)

        if let info = travelInfo {
            mapRegion = MKCoordinateRegion(
                center: info.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }

    private func openInMaps(coordinate: CLLocationCoordinate2D) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = event.location
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: travelModeForMaps()
        ])
    }

    private func travelModeForMaps() -> String {
        switch AppSettings.shared.defaultTravelMode {
        case .driving:
            return MKLaunchOptionsDirectionsModeDriving
        case .walking:
            return MKLaunchOptionsDirectionsModeWalking
        case .transit:
            return MKLaunchOptionsDirectionsModeTransit
        }
    }

    private func formatLeaveByTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

struct MapAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Preview

struct LocationCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            LocationCardView(event: CalendarEvent(
                id: "test",
                title: "Client Meeting",
                startDate: Date().addingTimeInterval(3600),
                endDate: Date().addingTimeInterval(5400),
                location: "123 Market Street, San Francisco, CA",
                description: nil,
                conferenceLink: nil,
                calendarId: "primary",
                calendarName: "Work",
                calendarColorHex: "#4285F4",
                provider: .google
            ))
            .padding()
        }
        .frame(width: 350)
    }
}
