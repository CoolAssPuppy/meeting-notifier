import SwiftUI

struct MeetingRowView: View {
    let event: CalendarEvent
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(event.formattedTime)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)

                        Text(event.timeUntilStart)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(event.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let location = event.location, !location.isEmpty {
                        Text(location)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    if event.hasVideoLink {
                        Image(systemName: "video.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                    }

                    Circle()
                        .fill(Color(hex: event.calendarColorHex))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.0))
        )
        .onHover { isHovered in
            if isHovered && event.hasVideoLink {
                NSCursor.pointingHand.push()
            } else if !isHovered {
                NSCursor.pop()
            }
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
