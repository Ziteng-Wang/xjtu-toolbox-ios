import SwiftUI
import WebKit

private final class BrowserState: ObservableObject {
    @Published var title: String = "浏览器"
    @Published var currentURL: String = ""
    @Published var progress: Double = 0
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var canGoForward = false

    weak var webView: WKWebView?

    func load(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        webView?.load(URLRequest(url: url))
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func reload() {
        webView?.reload()
    }

    func refreshNavigationState() {
        canGoBack = webView?.canGoBack ?? false
        canGoForward = webView?.canGoForward ?? false
    }
}

private struct BrowserWebView: UIViewRepresentable {
    let initialURL: String
    @ObservedObject var state: BrowserState

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = AppConstants.userAgent

        context.coordinator.bind(webView: webView)
        state.webView = webView

        Task {
            await syncCookies(to: webView)
            if !initialURL.isEmpty {
                state.load(urlString: normalizeURL(initialURL))
            }
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    private func syncCookies(to webView: WKWebView) async {
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        for cookie in cookies {
            await cookieStore.setCookieAsync(cookie)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let state: BrowserState
        private var progressObserver: NSKeyValueObservation?
        private var titleObserver: NSKeyValueObservation?
        private var urlObserver: NSKeyValueObservation?

        init(state: BrowserState) {
            self.state = state
        }

        func bind(webView: WKWebView) {
            progressObserver = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.state.progress = webView.estimatedProgress
                    self.state.isLoading = webView.isLoading
                }
            }
            titleObserver = webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.state.title = webView.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                        ? (webView.title ?? "浏览器")
                        : "浏览器"
                }
            }
            urlObserver = webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.state.currentURL = webView.url?.absoluteString ?? ""
                    self.state.refreshNavigationState()
                }
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.state.isLoading = true
                self.state.refreshNavigationState()
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.state.isLoading = false
                self.state.currentURL = webView.url?.absoluteString ?? ""
                self.state.refreshNavigationState()
            }
        }
    }
}

private extension WKHTTPCookieStore {
    func setCookieAsync(_ cookie: HTTPCookie) async {
        await withCheckedContinuation { continuation in
            setCookie(cookie) {
                continuation.resume()
            }
        }
    }
}

struct BrowserScreen: View {
    @StateObject private var state = BrowserState()
    @State private var inputURL = ""
    @FocusState private var urlInputFocused: Bool

    let initialURL: String

    init(initialURL: String = "") {
        self.initialURL = initialURL
    }

    var body: some View {
        VStack(spacing: 0) {
            if state.isLoading {
                ProgressView(value: state.progress)
                    .progressViewStyle(.linear)
            }

            BrowserWebView(initialURL: initialURL, state: state)

            Divider()

            HStack(spacing: 8) {
                TextField("输入网址或关键词", text: $inputURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .focused($urlInputFocused)
                    .submitLabel(.go)
                    .onSubmit {
                        openInputURL()
                    }

                Button("打开") {
                    openInputURL()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .navigationTitle(state.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    state.goBack()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .disabled(!state.canGoBack)

                Button {
                    state.goForward()
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(!state.canGoForward)

                Button {
                    state.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onChange(of: state.currentURL) { _, newValue in
            if !urlInputFocused, !newValue.isEmpty {
                inputURL = newValue
            }
        }
        .onAppear {
            if !initialURL.isEmpty {
                inputURL = initialURL
            }
        }
    }

    private func openInputURL() {
        let url = normalizeURL(inputURL)
        state.load(urlString: url)
        urlInputFocused = false
    }
}

private func normalizeURL(_ input: String) -> String {
    let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty else {
        return "https://www.bing.com"
    }
    if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
        return raw
    }
    if raw.contains("."), !raw.contains(" ") {
        return "https://\(raw)"
    }
    let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw
    return "https://www.bing.com/search?q=\(encoded)"
}
