import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let appGroupIdentifier = "group.com.reciperipperapp"
    private let sharedUrlKey = "SharedURL"

    // Supported video platforms
    private let supportedHosts = [
        "youtube.com", "youtu.be",
        "instagram.com",
        "tiktok.com"
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedContent()
    }

    /// Checks if a URL is from a supported platform
    private func isSupportedPlatform(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let host = url.host?.lowercased() else {
            return false
        }

        return supportedHosts.contains { host.contains($0) }
    }

    /// Shows an alert for unsupported platforms
    private func showUnsupportedPlatformAlert() {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(
                title: "Unsupported Platform",
                message: "Recipe Slurp only supports videos from YouTube, Instagram, and TikTok.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                self?.completeRequest()
            })
            self?.present(alert, animated: true)
        }
    }

    private func handleSharedContent() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeRequest()
            return
        }

        for extensionItem in extensionItems {
            guard let attachments = extensionItem.attachments else { continue }

            for attachment in attachments {
                // Handle URLs (from Safari, YouTube app, etc.)
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, error in
                        if let url = item as? URL {
                            self?.validateAndProcessUrl(url.absoluteString)
                        }
                    }
                    return
                }

                // Handle plain text (URLs shared as text)
                if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, error in
                        if let text = item as? String, let url = self?.extractUrl(from: text) {
                            self?.validateAndProcessUrl(url)
                        } else {
                            self?.completeRequest()
                        }
                    }
                    return
                }
            }
        }

        completeRequest()
    }

    private func extractUrl(from text: String) -> String? {
        // Try to find a URL in the text
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))

        if let match = matches?.first, let range = Range(match.range, in: text) {
            return String(text[range])
        }

        // Check if the entire text is a URL
        if let url = URL(string: text), url.scheme != nil {
            return text
        }

        return nil
    }

    /// Validates URL is from supported platform before processing
    private func validateAndProcessUrl(_ urlString: String) {
        if isSupportedPlatform(urlString) {
            processSharedUrl(urlString)
        } else {
            showUnsupportedPlatformAlert()
        }
    }

    private func processSharedUrl(_ urlString: String) {
        // Save URL to App Groups shared storage
        if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            userDefaults.set(urlString, forKey: sharedUrlKey)
            userDefaults.set(Date(), forKey: "SharedURLTimestamp")
            userDefaults.synchronize()
        }

        // Open the main app
        openMainApp()
    }

    private func openMainApp() {
        // Use the custom URL scheme to open the main app
        let urlScheme = "reciperipper://shared"

        guard let url = URL(string: urlScheme) else {
            completeRequest()
            return
        }

        // iOS Share Extensions can't directly open URLs, so we use a workaround
        // by responding to a selector that opens the URL
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:]) { [weak self] _ in
                    self?.completeRequest()
                }
                return
            }
            responder = responder?.next
        }

        // Fallback: just complete the request (app will check on next launch)
        completeRequest()
    }

    private func completeRequest() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}
