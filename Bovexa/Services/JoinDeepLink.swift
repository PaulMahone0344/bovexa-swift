import Foundation

/// Parseert `bovexaflow://join?code=...` (uitnodigingslink, valkuil G). Puur en
/// zonder side-effects — het scheme is geregistreerd in project.yml.
enum JoinDeepLink {
    static func code(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "bovexaflow", url.host?.lowercased() == "join" else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value, !code.isEmpty else { return nil }
        return code
    }
}
