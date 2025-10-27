import SwiftUI
import AppKit

struct MeetingRowView: View {
    let event: CalendarEvent
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Calendar color indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: event.calendarColorHex))
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 6) {
                    // Time and countdown
                    HStack(spacing: 6) {
                        Text(event.formattedTime)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)

                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Text(event.timeUntilStart)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    // Meeting title
                    Text(event.title)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Location (if available)
                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(location)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 8)

                // Video platform icon
                if let platform = event.videoPlatform {
                    videoPlatformIcon(platform)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color(nsColor: .controlAccentColor).opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
            if hovering && event.hasVideoLink {
                NSCursor.pointingHand.push()
            } else if !hovering {
                NSCursor.pop()
            }
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
            .sRGB,
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
