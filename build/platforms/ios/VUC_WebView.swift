import SwiftUI
import WebKit

struct VUCApp: App {
    var body: some Scene {
        WindowGroup {
            WebView(url: URL(string: "https://mejustmeb.github.io/VUCE")!)
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(URLRequest(url: url))
    }
}

@main
struct VUCAppMain {
    static func main() { VUCApp.main() }
}
