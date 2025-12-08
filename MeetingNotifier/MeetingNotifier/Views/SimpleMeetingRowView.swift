import SwiftUI
import AppKit

struct SimpleMeetingRowView: View {
    let event: CalendarEvent
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: {
            if event.hasVideoLink {
                onTap()
            }
        }) {
            HStack(spacing: 10) {
                // Calendar color dot
                Circle()
                    .fill(Color(hex: event.calendarColorHex))
                    .frame(width: 8, height: 8)

                // Time (using system time format)
                Text(event.systemFormattedTime)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .leading)

                // Meeting title
                Text(event.title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                // Travel time indicator (if physical location with travel time)
                if let travelInfo = travelTimeInfo {
                    HStack(spacing: 4) {
                        Image(systemName: travelInfo.icon)
                            .font(.system(size: 10, weight: .medium))
                        Text("(\(travelInfo.time))")
                            .font(.system(size: 11, weight: .regular))
                    }
                    .foregroundColor(.secondary.opacity(0.8))
                }

                // Video platform icon
                if let platform = event.videoPlatform {
                    videoPlatformIcon(platform)
                        .frame(width: 18, height: 18)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered && event.hasVideoLink ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if event.hasVideoLink {
                isHovered = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
    }

    private var travelTimeInfo: (icon: String, time: String)? {
        guard event.hasPhysicalLocation, let minutes = event.travelTimeMinutes else {
            return nil
        }

        let travelMode = AppSettings.shared.defaultTravelMode
        let icon: String
        switch travelMode {
        case .walking:
            icon = "figure.walk"
        case .driving:
            icon = "car.fill"
        case .transit:
            icon = "bus.fill"
        }

        let timeString: String
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes > 0 {
                timeString = "\(hours)h \(remainingMinutes)m"
            } else {
                timeString = "\(hours)h"
            }
        } else {
            timeString = "\(minutes)m"
        }

        return (icon, timeString)
    }

    @ViewBuilder
    private func videoPlatformIcon(_ platform: VideoPlatform) -> some View {
        switch platform {
        case .meet:
            if let image = NSImage(contentsOfFile: Bundle.main.path(forResource: "meet", ofType: "png") ?? "") {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "video.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            }
        case .zoom:
            if let image = NSImage(contentsOfFile: Bundle.main.path(forResource: "zoom", ofType: "png") ?? "") {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "video.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
            }
        case .teams:
            if let image = NSImage(contentsOfFile: Bundle.main.path(forResource: "teams", ofType: "png") ?? "") {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "video.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.purple)
            }
        case .webex:
            Image(systemName: "video.fill")
                .font(.system(size: 12))
                .foregroundColor(.orange)
        }
    }
}

struct SimpleMeetingRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            SimpleMeetingRowView(event: .preview, onTap: {})
            Divider()
            SimpleMeetingRowView(event: .previewNoVideo, onTap: {})
        }
        .frame(width: 350)
        .padding()
    }
}
