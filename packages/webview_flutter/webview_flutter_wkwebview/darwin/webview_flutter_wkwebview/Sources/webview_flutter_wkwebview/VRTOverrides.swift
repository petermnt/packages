import WebKit

extension WKWebView {
    func applyVrtOverrides() {
        allowsLinkPreview = false
        if #available(iOS 13.0, *) {
            let prefs = configuration.defaultWebpagePreferences
            prefs?.preferredContentMode = .mobile
            configuration.defaultWebpagePreferences = prefs
        }
    }
}
