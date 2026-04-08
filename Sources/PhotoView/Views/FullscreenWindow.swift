import SwiftUI
import AVKit
import WebKit
import AppKit

@MainActor final class FullscreenActions {
    var goPrev: () -> Void = {}
    var goNext: () -> Void = {}
    var seekUp: () -> Void = {}
    var seekDown: () -> Void = {}
    var togglePlay: () -> Void = {}
    var exit: () -> Void = {}
    var close: () -> Void = {} // 用于关闭窗口
    var cleanup: () -> Void = {}
    var cleanupWebM: (() -> Void)? = nil
    var cleanupWebMForce: (() -> Void)? = nil
}

class FullscreenWindowDelegate: NSObject, NSWindowDelegate {
    let cleanup: () -> Void
    init(cleanup: @escaping () -> Void) { self.cleanup = cleanup }
    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            self.cleanup()
        }
    }
}

final class FullscreenWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    var keyHandler: ((NSEvent) -> NSEvent?)?
    var onClose: (() -> Void)?
    override func close() {
        onClose?()
        super.close()
    }
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown { if let h = keyHandler, h(event) == nil { return } }
        super.sendEvent(event)
    }
}

struct FullscreenViewer: View {
    let items: [MediaItem]; let actions: FullscreenActions
    @State private var currentItem: MediaItem
    @State private var avPlayer: AVPlayer?
    @State private var image: NSImage?
    @State private var isPlaying = false
    @State private var timeObserver: Any?
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var volume: Double = 1.0
    @State private var toolbarOffset: CGSize = .zero
    @AppStorage("showToolbarByDefault") private var showToolbarByDefault = false
    @State private var showToolbar = false
    @State private var playerKey = UUID()
    @State private var isCleanedUp = false
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var lastDragOffset: CGSize = .zero
    @State private var rotation: Double = 0
    @State private var webMSeekTime: Double?
    @State private var videoScale: CGFloat = 1.0
    @State private var lastVideoScale: CGFloat = 1.0
    @State private var videoOffset: CGSize = .zero
    @State private var lastVideoDragOffset: CGSize = .zero
    @State private var videoRotation: Double = 0
    @ObservedObject private var localization = LocalizationManager.shared
    
    var exitFullscreenTitle: String {
        localization.tr(LocalizedString.exitFullscreen, LocalizedString_en.exitFullscreen)
    }
    
    var idx: Int {
        if let index = items.firstIndex(where: { $0.id == currentItem.id }) { return index }
        return items.firstIndex(where: { $0.url == currentItem.url }) ?? 0
    }
    
    var isWebM: Bool { currentItem.url.pathExtension.lowercased() == "webm" }
    
    init(item: MediaItem, items: [MediaItem], actions: FullscreenActions) {
        self.items = items; self.actions = actions
        _currentItem = State(initialValue: item)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if !isCleanedUp {
                if currentItem.type == .image, let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .rotationEffect(.degrees(rotation))
                        .offset(imageOffset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 1)
                        .gesture(magnificationGesture)
                        .gesture(dragGesture)
                        .onTapGesture(count: 2) {
                            withAnimation { 
                                scale = scale > 1 ? 1 : 2
                                if scale == 1 { imageOffset = .zero }
                            }
                        }
                } else if isWebM {
                    WebMVideoPlayerView(url: currentItem.url, isPlaying: $isPlaying, currentTime: $currentTime, duration: $duration, volume: $volume, onEnded: { goNext() }, key: playerKey, seekTime: $webMSeekTime)
                        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.vertical, 1)
                        .scaleEffect(videoScale)
                        .rotationEffect(.degrees(videoRotation))
                        .offset(videoOffset)
                        .gesture(videoMagnificationGesture)
                        .gesture(videoDragGesture)
                } else if let avPlayer {
                    AVPlayerLayerView(player: avPlayer)
                        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.vertical, 1)
                        .id(currentItem.id)
                        .scaleEffect(videoScale)
                        .rotationEffect(.degrees(videoRotation))
                        .offset(videoOffset)
                        .gesture(videoMagnificationGesture)
                        .gesture(videoDragGesture)
                }
                
                VStack {
                    HStack {
                        Button(action: { actions.exit() }) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.title).foregroundColor(.white)
                        }.buttonStyle(.plain).padding().help(exitFullscreenTitle)
                        
                        Button(action: { showToolbar.toggle() }) {
                            Image(systemName: showToolbar ? "gearshape.fill" : "gearshape")
                                .font(.title).foregroundColor(.white)
                        }.buttonStyle(.plain).padding()
                        
                        Spacer()
                        
                        let imageNeedsReset = scale != 1.0 || imageOffset != .zero || (rotation.truncatingRemainder(dividingBy: 360) != 0)
                        let videoNeedsReset = videoScale != 1.0 || videoOffset != .zero || (videoRotation.truncatingRemainder(dividingBy: 360) != 0)
                        
                        if imageNeedsReset || videoNeedsReset {
                            Button(action: {
                                resetScale()
                                resetVideoView()
                            }) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.title2).foregroundColor(.white)
                            }.buttonStyle(.plain).padding().help(localization.tr(LocalizedString.resetView, LocalizedString_en.resetView))
                        }
                        
                        if currentItem.type == .image {
                            Button(action: { withAnimation { rotation -= 90 } }) {
                                Image(systemName: "rotate.left")
                                    .font(.title2).foregroundColor(.white)
                            }.buttonStyle(.plain).padding().help(localization.tr(LocalizedString.rotateLeft, LocalizedString_en.rotateLeft))
                            
                            Button(action: { withAnimation { rotation += 90 } }) {
                                Image(systemName: "rotate.right")
                                    .font(.title2).foregroundColor(.white)
                            }.buttonStyle(.plain).padding().help(localization.tr(LocalizedString.rotateRight, LocalizedString_en.rotateRight))
                        } else if currentItem.type == .video {
                            Button(action: { withAnimation { videoRotation -= 90 } }) {
                                Image(systemName: "rotate.left")
                                    .font(.title2).foregroundColor(.white)
                            }.buttonStyle(.plain).padding().help(localization.tr(LocalizedString.rotateLeft, LocalizedString_en.rotateLeft))
                            
                            Button(action: { withAnimation { videoRotation += 90 } }) {
                                Image(systemName: "rotate.right")
                                    .font(.title2).foregroundColor(.white)
                            }.buttonStyle(.plain).padding().help(localization.tr(LocalizedString.rotateRight, LocalizedString_en.rotateRight))
                        }
                    }
                    Spacer()
                    if showToolbar {
                        DraggableToolbar(isPlaying: $isPlaying, currentTime: $currentTime, duration: $duration, volume: $volume,
                            player: avPlayer, onPrev: goPrev, onNext: goNext, offset: $toolbarOffset, isWebM: isWebM, isImage: currentItem.type == .image, scale: $scale,
                            onSeekWebM: { time in
                                if isWebM {
                                    webMSeekTime = time
                                }
                            }, onVolumeChanged: { newVolume in
                                avPlayer?.volume = Float(newVolume)
                            }, webMSyncTime: $currentTime, onResetVideo: {
                                resetVideoView()
                            })
                            .padding(.bottom, 40)
                    }
                }
            }
        }
        .onAppear {
            scale = 1.0
            lastScale = 1.0
            imageOffset = .zero
            lastDragOffset = .zero
            rotation = 0
            videoScale = 1.0
            lastVideoScale = 1.0
            videoOffset = .zero
            lastVideoDragOffset = .zero
            videoRotation = 0
            showToolbar = showToolbarByDefault
            actions.cleanup = { cleanupPlayer() }
            actions.cleanupWebM = {
                self.isPlaying = false
            }
            actions.cleanupWebMForce = {
                WebMPlayerViewImpl.clearAllWebViews()
            }
            setupMedia()
            actions.goPrev = { goPrev() }; actions.goNext = { goNext() }
            actions.seekUp = { seek(by: -0.05) }; actions.seekDown = { seek(by: 0.05) }
            actions.togglePlay = { togglePlay() }
            actions.exit = { exitFullscreen() }
        }
        .onDisappear { cleanupPlayer() }
    }
    
    private func cleanupPlayer(forceStop: Bool = false) {
        guard !isCleanedUp else { return }
        isCleanedUp = true
        isPlaying = false
        actions.cleanupWebM?()
        
        if forceStop {
            WebMPlayerViewImpl.clearAllWebViews()
            WebMPlayerViewImpl.forceStopAll()
        }
        
        if let player = avPlayer {
            player.volume = 0
            player.pause()
            player.rate = 0
            player.currentItem?.cancelPendingSeeks()
            player.currentItem?.asset.cancelLoading()
            if let o = timeObserver {
                player.removeTimeObserver(o)
                timeObserver = nil
            }
            player.replaceCurrentItem(with: nil)
        }
        avPlayer = nil
    }
    
    // 核心修复：退出全屏时清理资源并关闭窗口
    private func exitFullscreen() {
        cleanupPlayer()
        actions.close() // 触发关闭窗口
    }
    
    private func setupMedia() {
        cleanupPlayer()
        isCleanedUp = false 
        
        if currentItem.type == .image {
            loadImg()
        } else if !isWebM {
            avPlayer = AVPlayer(url: currentItem.url)
            avPlayer?.actionAtItemEnd = .pause
            avPlayer?.volume = Float(volume)
            avPlayer?.play()
            isPlaying = true
            setupObserver()
        } else {
            isPlaying = true
        }
    }
    
    private func setupObserver() {
        guard let p = avPlayer, let item = p.currentItem else { return }
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { _ in
            Task { @MainActor in self.goNext() }
        }
        
        timeObserver = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: .main) { [weak p] time in
            guard let strongP = p else { return }
            MainActor.assumeIsolated {
                self.currentTime = time.seconds
                self.duration = strongP.currentItem?.duration.seconds ?? 0
                self.isPlaying = strongP.timeControlStatus == .playing
            }
        }
    }
    
    private func togglePlay() {
        if isWebM { isPlaying.toggle() }
        else if currentItem.type == .video { isPlaying ? avPlayer?.pause() : avPlayer?.play() }
    }
    
    private func seek(by pct: Double) {
        if !isWebM, let p = avPlayer, let dur = p.currentItem?.duration.seconds {
            p.seek(to: CMTime(seconds: max(0, min(p.currentTime().seconds + dur * pct, dur)), preferredTimescale: 600))
        }
    }
    
    private func goNext() { guard idx + 1 < items.count else { return }; loadItem(items[idx + 1]) }
    private func goPrev() { guard idx - 1 >= 0 else { return }; loadItem(items[idx - 1]) }
    
    private func loadItem(_ n: MediaItem) {
        cleanupPlayer()
        currentItem = n
        playerKey = UUID()
        isCleanedUp = false
        scale = 1.0
        lastScale = 1.0
        imageOffset = .zero
        lastDragOffset = .zero
        rotation = 0
        videoScale = 1.0
        lastVideoScale = 1.0
        videoOffset = .zero
        lastVideoDragOffset = .zero
        videoRotation = 0
        
        if n.type == .image {
            avPlayer = nil; image = nil; loadImg(url: n.url)
        } else if n.url.pathExtension.lowercased() == "webm" {
            image = nil; avPlayer = nil; isPlaying = true
        } else {
            image = nil
            avPlayer = AVPlayer(url: n.url)
            avPlayer?.actionAtItemEnd = .pause
            avPlayer?.volume = Float(volume)
            avPlayer?.play()
            isPlaying = true
            setupObserver()
        }
    }
    
    private func loadImg() { loadImg(url: currentItem.url) }
    private func loadImg(url: URL) {
        guard let s = CGImageSourceCreateWithURL(url as CFURL, nil), let cg = CGImageSourceCreateImageAtIndex(s, 0, nil) else { return }
        image = NSImage(cgImage: cg, size: .zero)
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                scale = max(0.5, min(5.0, scale * delta))
                lastScale = value
            }
            .onEnded { _ in
                lastScale = 1.0
                if scale < 0.5 { scale = 0.5 }
                if scale > 5.0 { scale = 5.0 }
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1.0 {
                    imageOffset = CGSize(
                        width: lastDragOffset.width + value.translation.width,
                        height: lastDragOffset.height + value.translation.height
                    )
                }
            }
            .onEnded { value in
                lastDragOffset = imageOffset
            }
    }
    
    private var videoDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if videoScale > 1.0 {
                    videoOffset = CGSize(
                        width: lastVideoDragOffset.width + value.translation.width,
                        height: lastVideoDragOffset.height + value.translation.height
                    )
                }
            }
            .onEnded { value in
                lastVideoDragOffset = videoOffset
            }
    }
    
    private func resetVideoView() {
        videoScale = 1.0
        videoOffset = .zero
        lastVideoDragOffset = .zero
        videoRotation = 0
    }
    
    private var videoMagnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastVideoScale
                videoScale = max(0.5, min(5.0, videoScale * delta))
                lastVideoScale = value
            }
            .onEnded { _ in
                lastVideoScale = 1.0
                if videoScale < 0.5 { videoScale = 0.5 }
                if videoScale > 5.0 { videoScale = 5.0 }
            }
    }
    
    private func resetScale() {
        scale = 1.0
        imageOffset = .zero
        lastDragOffset = .zero
        rotation = 0
    }
}

struct WebMVideoPlayerView: View {
    let url: URL
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var volume: Double
    let onEnded: () -> Void
    let key: UUID
    @Binding var seekTime: Double?
    
    var body: some View {
        WebMPlayerView(url: url, isPlaying: $isPlaying, currentTime: $currentTime, duration: $duration, volume: $volume, seekTime: $seekTime, onEnded: onEnded, key: key)
            .id(key)
    }
}

struct DraggableToolbar: View {
    @Binding var isPlaying: Bool; @Binding var currentTime: Double; @Binding var duration: Double; @Binding var volume: Double
    let player: AVPlayer?; let onPrev: () -> Void; let onNext: () -> Void; @Binding var offset: CGSize
    let isWebM: Bool
    let isImage: Bool
    @Binding var scale: CGFloat
    var onSeekWebM: ((Double) -> Void)?
    var onVolumeChanged: ((Double) -> Void)?
    var webMSyncTime: Binding<Double>?
    var onResetVideo: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onPrev) { Image(systemName: "backward.fill").font(.title2) }.buttonStyle(.plain)
            
            if !isImage {
                Button(action: { isPlaying ? pauseAction() : playAction() }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill").font(.title)
                }.buttonStyle(.plain)
                Button(action: onNext) { Image(systemName: "forward.fill").font(.title2) }.buttonStyle(.plain)
                
                Text(formatTime(currentTime)).foregroundColor(.white).font(.caption).frame(width: 40, alignment: .trailing)
                
                Slider(value: Binding(get: { currentTime }, set: { newTime in
                    if isWebM {
                        webMSyncTime?.wrappedValue = newTime
                        onSeekWebM?(newTime)
                    } else {
                        currentTime = newTime
                        player?.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
                    }
                }), in: 0...max(duration, 1)).frame(width: 200).accentColor(.white)
                
                Text(formatTime(duration)).foregroundColor(.white).font(.caption).frame(width: 40, alignment: .leading)
                
                Image(systemName: "speaker.wave.3.fill").foregroundColor(.white)
                Slider(value: Binding(get: { volume }, set: { newValue in
                    volume = newValue
                    if isWebM {
                    } else {
                        onVolumeChanged?(newValue)
                    }
                }), in: 0...1)
                    .frame(width: 80).accentColor(.white)
            } else {
                Button(action: onNext) { Image(systemName: "forward.fill").font(.title2) }.buttonStyle(.plain)
            }
            
            if scale != 1.0 || onResetVideo != nil {
                Button(action: { 
                    if let reset = onResetVideo {
                        reset()
                    } else {
                        withAnimation { scale = 1.0 }
                    }
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                }.buttonStyle(.plain)
            }
        }
        .padding(12).background(.ultraThinMaterial.opacity(0.8)).cornerRadius(12).offset(offset)
        .gesture(DragGesture().onChanged { offset = $0.translation }.onEnded { _ in withAnimation { offset = .zero } })
    }
    
    private func playAction() { isPlaying = true }
    private func pauseAction() { isPlaying = false }
    
    private func formatTime(_ t: Double) -> String { let m = Int(t) / 60; let s = Int(t) % 60; return String(format: "%d:%02d", m, s) }
}

struct AVPlayerLayerView: NSViewRepresentable {
    let player: AVPlayer?
    func makeNSView(context: Context) -> NSView {
        let c = NSView(); c.wantsLayer = true
        let h = NSView(); h.wantsLayer = true; h.translatesAutoresizingMaskIntoConstraints = false; c.addSubview(h)
        let l = AVPlayerLayer(); l.videoGravity = .resizeAspect; l.player = player; h.layer = l
        NSLayoutConstraint.activate([h.leadingAnchor.constraint(equalTo: c.leadingAnchor), h.trailingAnchor.constraint(equalTo: c.trailingAnchor), h.topAnchor.constraint(equalTo: c.topAnchor), h.bottomAnchor.constraint(equalTo: c.bottomAnchor)])
        return c
    }
    func updateNSView(_ v: NSView, context: Context) { 
        if let layer = v.subviews.first?.layer as? AVPlayerLayer {
            layer.player = player
        }
    }
}

@MainActor final class FullscreenWindowController {
    static let shared = FullscreenWindowController()
    private var win: FullscreenWindow?
    private var actions: FullscreenActions?
    
    func show(item: MediaItem, in items: [MediaItem]) {
        let act = FullscreenActions()
        actions = act
        
        // 核心修复：绑定关闭窗口的动作
        act.close = { [weak self] in
            self?.close()
        }
        
        let viewer = FullscreenViewer(item: item, items: items, actions: act)
        let hosting = NSHostingController(rootView: viewer)
        let w = FullscreenWindow(contentViewController: hosting)
        w.styleMask = [.titled, .closable, .fullSizeContentView, .resizable]
        w.titleVisibility = .hidden
        w.level = .floating
        
        let delegate = FullscreenWindowDelegate {
            Task { @MainActor in self.actions?.cleanup() }
        }
        w.delegate = delegate
        
        w.keyHandler = { [weak self] event in
            switch event.keyCode {
            case 123: self?.actions?.goPrev(); return nil
            case 124: self?.actions?.goNext(); return nil
            case 126: self?.actions?.seekUp(); return nil
            case 125: self?.actions?.seekDown(); return nil
            case 49: self?.actions?.togglePlay(); return nil
            case 53: self?.actions?.exit(); return nil
            default: return event
            }
        }
        
        w.onClose = { [weak self] in
            self?.actions?.cleanup()
            self?.actions?.cleanupWebMForce?()
        }
        
        if let s = NSScreen.main { w.setFrame(s.visibleFrame.insetBy(dx: 100, dy: 100), display: true) }
        w.makeKeyAndOrderFront(nil); win = w
    }
    
    func close() { 
        if let act = actions {
            Task { @MainActor in
                act.cleanup()
            }
        }
        win?.close()
        win = nil 
    }
}
