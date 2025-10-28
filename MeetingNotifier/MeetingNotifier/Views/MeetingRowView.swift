import SwiftUI
import AppKit
import MapKit

struct MeetingRowView: View {
    let event: CalendarEvent
    let onTap: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var showLocationDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            mainMeetingCard

            // Location card if available
            if event.hasPhysicalLocation {
                LocationCardView(event: event)
                    .padding(.horizontal, 8)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var mainMeetingCard: some View {
        Button(action: {
            if event.hasVideoLink {
                onTap()
            }
        }) {
            HStack(alignment: .top, spacing: 0) {
                // Vibrant calendar color stripe - solid like Google Calendar
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: event.calendarColorHex))
                    .frame(width: 4)

                Spacer()
                    .frame(width: 12)

                // Content area
                VStack(alignment: .leading, spacing: 8) {
                    // Time badge and status
                    HStack(spacing: 8) {
                        // Time badge with glass effect
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Text(event.formattedTime)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(.regularMaterial)
                                .shadow(color: Color.blue.opacity(0.1), radius: 4, x: 0, y: 2)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.3), Color.cyan.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )

                        // Countdown badge
                        countdownBadge
                    }

                    // Meeting title with elegant typography
                    Text(event.title)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    // Metadata row
                    HStack(spacing: 10) {
                        // Calendar name
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: event.calendarColorHex))
                                .frame(width: 6, height: 6)
                            Text(event.calendarName)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        // Attendee count if available
                        if event.attendeeCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                Text("\(event.attendeeCount)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Spacer(minLength: 12)

                // Video platform icon with glassmorphic button
                if let platform = event.videoPlatform {
                    videoPlatformButton(platform)
                }
            }
            .padding(14)
            .background(
                ZStack {
                    // Base glass layer
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)

                    // Hover effect layer
                    if isHovered && event.hasVideoLink {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.08),
                                        Color.accentColor.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .transition(.opacity)
                    }

                    // Pressed effect
                    if isPressed {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.primary.opacity(0.05))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.primary.opacity(isHovered ? 0.15 : 0.08),
                                Color.primary.opacity(isHovered ? 0.08 : 0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(isHovered ? 0.08 : 0.04),
                radius: isHovered ? 12 : 6,
                x: 0,
                y: isHovered ? 6 : 3
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
            if hovering && event.hasVideoLink {
                NSCursor.pointingHand.push()
            } else if !hovering {
                NSCursor.pop()
            }
        }
    }

    private var countdownBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(timeUntilStartColor)
                .frame(width: 6, height: 6)

            Text(event.timeUntilStart)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.regularMaterial)
        )
    }

    private var timeUntilStartColor: Color {
        let interval = event.startDate.timeIntervalSince(Date())
        let minutes = Int(interval / 60)

        if minutes <= 5 {
            return .red
        } else if minutes <= 15 {
            return .orange
        } else {
            return .green
        }
    }

    private func videoPlatformButton(_ platform: VideoPlatform) -> some View {
        ZStack {
            // Glassmorphic background
            Circle()
                .fill(.regularMaterial)
                .frame(width: 42, height: 42)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

            // Platform-specific gradient overlay
            Circle()
                .fill(platformGradient(for: platform).opacity(0.15))
                .frame(width: 42, height: 42)

            // Icon
            videoPlatformIcon(platform)
                .frame(width: 22, height: 22)
        }
        .overlay(
            Circle()
                .strokeBorder(platformGradient(for: platform).opacity(0.3), lineWidth: 1.5)
        )
    }

    private func platformGradient(for platform: VideoPlatform) -> LinearGradient {
        switch platform {
        case .meet:
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .zoom:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .teams:
            return LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .webex:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    @ViewBuilder
    private func videoPlatformIcon(_ platform: VideoPlatform) -> some View {
        switch platform {
        case .meet:
            if let image = NSImage(contentsOfFile: Bundle.main.path(forResource: "meet", ofType: "png") ?? "") {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        case .zoom:
            if let image = NSImage(contentsOfFile: Bundle.main.path(forResource: "zoom", ofType: "png") ?? "") {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        case .teams:
            if let image = NSImage(contentsOfFile: Bundle.main.path(forResource: "teams", ofType: "png") ?? "") {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        case .webex:
            Image(systemName: "video.fill")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .displayP3,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct MeetingRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            MeetingRowView(event: .preview, onTap: {})
            MeetingRowView(event: .previewNoVideo, onTap: {})
        }
        .frame(width: 350)
    }
}
