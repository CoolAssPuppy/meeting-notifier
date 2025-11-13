import SwiftUI
import AppKit

struct PeekWindowView: View {
    let meeting: CalendarEvent?
    let settings: AppSettings
    let onTap: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            if let meeting = meeting {
                // Close button on the left
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .padding(.leading, 12)
                .padding(.trailing, 8)
                .help("Close")

                // Meeting info - matches menu bar display
                Button(action: onTap) {
                    HStack(spacing: 6) {
                        // Icon (if enabled)
                        if settings.menuBarShowIcon {
                            if let iconImage = getIconImage(for: meeting) {
                                Image(nsImage: iconImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                            } else {
                                Text(getIconEmoji(for: meeting))
                                    .font(.system(size: 14))
                            }
                        }

                        // Time (if enabled)
                        if settings.menuBarShowTime {
                            Text(meeting.formattedTime)
                                .font(.system(size: 13))
                        }

                        // Countdown (if enabled)
                        if settings.menuBarShowCountdown {
                            Text(meeting.timeUntilStart)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        // Title (if enabled)
                        if settings.menuBarShowTitle {
                            Text(truncateTitle(meeting.title, maxLength: 30))
                                .font(.system(size: 13))
                                .lineLimit(1)
                        }

                        // Show default if nothing is configured
                        if !settings.menuBarShowIcon && !settings.menuBarShowTitle &&
                           !settings.menuBarShowTime && !settings.menuBarShowCountdown {
                            Image(systemName: "calendar")
                                .font(.system(size: 14))
                        }
                    }
                    .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
                .contentShape(Rectangle())
            }
        }
        .padding(.vertical, 6)
        .frame(minWidth: 150)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    private func getIconImage(for event: CalendarEvent) -> NSImage? {
        guard let platform = event.videoPlatform else { return nil }

        switch platform {
        case .meet:
            if let imagePath = Bundle.main.path(forResource: "meet", ofType: "png"),
               let image = NSImage(contentsOfFile: imagePath) {
                image.size = NSSize(width: 16, height: 16)
                return image
            }
        case .zoom:
            if let imagePath = Bundle.main.path(forResource: "zoom", ofType: "png"),
               let image = NSImage(contentsOfFile: imagePath) {
                image.size = NSSize(width: 16, height: 16)
                return image
            }
        case .teams:
            if let imagePath = Bundle.main.path(forResource: "teams", ofType: "png"),
               let image = NSImage(contentsOfFile: imagePath) {
                image.size = NSSize(width: 16, height: 16)
                return image
            }
        case .webex:
            break
        }

        return nil
    }

    private func getIconEmoji(for event: CalendarEvent) -> String {
        if let platform = event.videoPlatform {
            switch platform {
            case .meet:
                return "📞"
            case .zoom:
                return "💻"
            case .teams:
                return "👥"
            case .webex:
                return "📹"
            }
        }
        return "📅"
    }

    private func truncateTitle(_ title: String, maxLength: Int) -> String {
        if title.count <= maxLength {
            return title
        }
        let index = title.index(title.startIndex, offsetBy: maxLength - 3)
        return String(title[..<index]) + "..."
    }
}

struct PeekWindowView_Previews: PreviewProvider {
    static var previews: some View {
        PeekWindowView(
            meeting: nil,
            settings: AppSettings.shared,
            onTap: {},
            onClose: {}
        )
    }
}
