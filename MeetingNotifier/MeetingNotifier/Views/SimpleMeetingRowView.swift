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
            HStack(spacing: 0) {
                // Calendar color dot
                Circle()
                    .fill(Color(hex: event.calendarColorHex))
                    .frame(width: 8, height: 8)
                    .padding(.leading, 12)
                    .padding(.trailing, 10)

                // Time (using system time format) - wide enough for "10:00 AM"
                Text(event.systemFormattedTime)
                    .font(.system(size: 13))
                    .foregroundColor(isHovered ? .white.opacity(0.7) : .secondary)
                    .frame(width: 72, alignment: .leading)
                    .lineLimit(1)

                // Meeting title
                Text(event.title)
                    .font(.system(size: 13))
                    .foregroundColor(isHovered ? .white : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                // Video platform icon
                if let platform = event.videoPlatform {
                    videoPlatformIcon(platform)
                        .frame(width: 16, height: 16)
                        .padding(.trailing, 12)
                }
            }
            .padding(.vertical, 4)
            .padding(.trailing, event.videoPlatform == nil ? 12 : 0)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.accentColor : Color.clear)
                    .padding(.horizontal, 6)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if event.hasVideoLink {
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
    }

    @ViewBuilder
    private func videoPlatformIcon(_ platform: VideoPlatform) -> some View {
        let imageName = platform.iconName

        if let path = Bundle.main.path(forResource: imageName, ofType: "png"),
           let image = NSImage(contentsOfFile: path) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(isHovered ? 0.9 : 0.7)
        } else {
            Image(systemName: "video.fill")
                .font(.system(size: 11))
                .foregroundColor(isHovered ? .white.opacity(0.7) : .secondary)
        }
    }
}

struct SimpleMeetingRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            SimpleMeetingRowView(event: .preview, onTap: {})
            SimpleMeetingRowView(event: .previewNoVideo, onTap: {})
        }
        .frame(width: 320)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
