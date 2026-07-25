import SwiftUI

/// Kleine ronde avatar: foto als er een is, anders de initiaal op een teal-vlak.
/// Herbruikbaar op Profiel en Profiel bewerken.
struct AvatarView: View {
    let initial: String
    let url: URL?
    var size: CGFloat = 58

    var body: some View {
        ZStack {
            Circle().fill(BovexaTheme.Colors.glassStrong)
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        initialText
                    }
                }
            } else {
                initialText
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(BovexaTheme.Colors.edge, lineWidth: 1))
    }

    private var initialText: some View {
        Text(initial)
            .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
            .foregroundStyle(BovexaTheme.Colors.accent)
    }
}

/// URL naar een geüploade avatar op agenda_users, of nil zonder foto.
enum AvatarURLBuilder {
    static func url(userId: String, avatar: String?) -> URL? {
        guard let avatar, !avatar.isEmpty else { return nil }
        return URL(string: "\(PBEndpoint.base.absoluteString)/api/files/agenda_users/\(userId)/\(avatar)")
    }
}

#Preview {
    ZStack {
        AppBackground()
        AvatarView(initial: "I", url: nil, size: 80)
    }
}
