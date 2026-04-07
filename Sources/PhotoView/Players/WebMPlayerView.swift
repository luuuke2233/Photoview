import SwiftUI
import WebKit

/// WebM 视频播放器 - 使用 WKWebView 作为 AVPlayer 的降级方案
struct WebMPlayerView: NSViewRepresentable {
    let url: URL
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var volume: Double
    @Binding var seekTime: Double?
    let onEnded: () -> Void
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsMagnification = false
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        
        webView.configuration.userContentController.add(context.coordinator, name: "duration")
        webView.configuration.userContentController.add(context.coordinator, name: "time")
        webView.configuration.userContentController.add(context.coordinator, name: "ended")
        
        let parentDir = url.deletingLastPathComponent()
        let htmlFileName = ".photoview_webm_\(url.lastPathComponent.hashValue).html"
        let htmlURL = parentDir.appendingPathComponent(htmlFileName)
        
        let encodedName = url.lastPathComponent.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? url.lastPathComponent
        
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body, html { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: #000; }
                video { width: 100%; height: 100%; object-fit: contain; display: block; }
            </style>
        </head>
        <body>
            <video id="player" autoplay playsinline preload="auto">
                <source src="\(encodedName)" type="video/webm">
            </video>
            <script>
                const video = document.getElementById('player');
                video.addEventListener('loadedmetadata', () => window.webkit.messageHandlers.duration.postMessage(video.duration));
                video.addEventListener('timeupdate', () => window.webkit.messageHandlers.time.postMessage(video.currentTime));
                video.addEventListener('ended', () => window.webkit.messageHandlers.ended.postMessage(true));
                setInterval(() => {
                    if (!video.paused) window.webkit.messageHandlers.time.postMessage(video.currentTime);
                }, 100);
                window.addEventListener('message', (event) => {
                    const data = event.data;
                    if (data.action === 'play') video.play();
                    if (data.action === 'pause') video.pause();
                    if (data.action === 'seek') { video.currentTime = data.time; window.webkit.messageHandlers.time.postMessage(video.currentTime); }
                    if (data.action === 'volume') video.volume = data.volume;
                });
            </script>
        </body>
        </html>
        """
        
        try? htmlContent.write(to: htmlURL, atomically: true, encoding: .utf8)
        webView.loadFileURL(htmlURL, allowingReadAccessTo: parentDir)
        
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 5) {
            try? FileManager.default.removeItem(at: htmlURL)
        }
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.frame = nsView.bounds
        if isPlaying {
            nsView.evaluateJavaScript("document.getElementById('player')?.play()")
        } else {
            nsView.evaluateJavaScript("document.getElementById('player')?.pause()")
        }
        nsView.evaluateJavaScript("if(document.getElementById('player')) document.getElementById('player').volume = \(volume)")
        
        if let time = seekTime {
            nsView.evaluateJavaScript("if(document.getElementById('player')) { document.getElementById('player').currentTime = \(time); window.webkit.messageHandlers.time.postMessage(\(time)); }")
            DispatchQueue.main.async {
                self.seekTime = nil
            }
        }
    }
    
    func seek(to time: Double, in nsView: WKWebView) {
        nsView.evaluateJavaScript("if(document.getElementById('player')) document.getElementById('player').currentTime = \(time)")
    }
    
    // 核心修复：暴力清理 Web 进程，防止音频残留
    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.stopLoading()
        nsView.evaluateJavaScript("const v = document.getElementById('player'); if(v) { v.pause(); v.src = ''; v.load(); }")
        nsView.loadHTMLString("<html><body></body></html>", baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: WebMPlayerView
        init(parent: WebMPlayerView) { self.parent = parent }
        
        func userContentController(_ uc: WKUserContentController, didReceive m: WKScriptMessage) {
            switch m.name {
            case "duration": if let d = m.body as? Double { DispatchQueue.main.async { self.parent.duration = d } }
            case "time": if let t = m.body as? Double { DispatchQueue.main.async { self.parent.currentTime = t } }
            case "ended": DispatchQueue.main.async { self.parent.onEnded() }
            default: break
            }
        }
        
        func webView(_ wv: WKWebView, didFinish n: WKNavigation!) {
            // Handlers are already added in makeNSView to prevent crash
        }
        
        func webView(_ wv: WKWebView, didFail n: WKNavigation!, withError e: Error) {
            print("❌ WebM Load Failed: \(e.localizedDescription)")
        }
    }
}
