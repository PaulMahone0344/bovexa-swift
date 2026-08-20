import SwiftUI

/// Logo-lader met geheugen-cache en één stille retry. AsyncImage bewaart niets
/// en probeert nooit opnieuw: één netwerk-hikje bij het openen betekende een
/// leeg logo tot de view toevallig opnieuw werd opgebouwd — precies het
/// "collega ziet het logo niet"-symptoom.
struct RemoteLogoView: View {
    let url: URL
    /// Wat er staat zolang het logo laadt of niet komt. `Color.clear` liet een
    /// gat van 44x44 achter (4g); een koffertje leest als "hier hoort een logo".
    var placeholderSystemImage: String? = "briefcase.fill"

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else if let placeholderSystemImage {
                Image(systemName: placeholderSystemImage)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .foregroundStyle(BovexaTheme.Colors.muted)
            } else {
                Color.clear
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        if let cached = LogoImageCache.shared.object(forKey: url as NSURL) {
            image = cached
            return
        }
        for attempt in 0..<2 {
            if attempt > 0 { try? await Task.sleep(nanoseconds: 800_000_000) }
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            if let (data, _) = try? await URLSession.shared.data(for: request),
               let loaded = UIImage(data: data) {
                LogoImageCache.shared.setObject(loaded, forKey: url as NSURL)
                image = loaded
                return
            }
        }
    }
}

/// Eén proces-brede cache: het logo staat op Vandaag én Bedrijf, en hoort niet
/// per scherm opnieuw over het netwerk te komen.
enum LogoImageCache {
    static let shared = NSCache<NSURL, UIImage>()
}
