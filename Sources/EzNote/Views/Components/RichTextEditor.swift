import SwiftUI
import AppKit

/// 富文本编辑器：支持粘贴 / 拖入图片作为内嵌附件。
///
/// 图片交互：
/// - 鼠标悬停在图片**右边缘 / 下边缘 / 右下角**时显示拉伸光标，按住拖动即可等比调整大小。
/// - 单击图片本体时弹出大图预览窗口。
///
/// - `richData`: `NSKeyedArchiver` 序列化的 `NSAttributedString`（含图片附件）。
/// - `plainText`: 对应纯文本（图片占位符替换为 `[图片]`），用于列表预览 / 搜索。
struct RichTextEditor: NSViewRepresentable {
    @Binding var richData: Data?
    @Binding var plainText: String

    var font: NSFont = .systemFont(ofSize: NSFont.systemFontSize)
    var insets: NSSize = NSSize(width: 8, height: 8)
    var onTextChange: (() -> Void)? = nil

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true

        let textView = ImagePastingTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.importsGraphics = true
        textView.allowsImageEditing = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.usesFontPanel = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = font
        textView.textContainerInset = insets
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.applyExternal(richData: richData, plainText: plainText, font: font)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = nsView.documentView as? ImagePastingTextView else { return }
        context.coordinator.applyExternal(richData: richData, plainText: plainText, font: font, textView: textView)
        if textView.font != font {
            textView.font = font
        }
        if textView.textContainerInset != insets {
            textView.textContainerInset = insets
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        weak var textView: ImagePastingTextView?

        private var isApplyingExternalChange = false
        private var lastAppliedRichData: Data?
        private var lastAppliedPlainText: String?

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        func applyExternal(
            richData: Data?,
            plainText: String,
            font: NSFont,
            textView: ImagePastingTextView? = nil
        ) {
            let target = textView ?? self.textView
            guard let tv = target, let storage = tv.textStorage else { return }

            let richUnchanged = richData == lastAppliedRichData
            let plainUnchanged = plainText == lastAppliedPlainText
            if richUnchanged && plainUnchanged && lastAppliedPlainText != nil {
                return
            }

            isApplyingExternalChange = true
            defer { isApplyingExternalChange = false }

            let attributed: NSAttributedString
            if let data = richData, let decoded = Self.decodeAttributedString(from: data) {
                let upgraded = Self.upgradingAttachments(decoded)
                attributed = Self.applyingDefaultAppearance(upgraded, font: font)
            } else {
                attributed = NSAttributedString(
                    string: plainText,
                    attributes: Self.defaultAttributes(font: font)
                )
            }
            storage.setAttributedString(attributed)
            tv.font = font
            tv.typingAttributes = Self.defaultAttributes(font: font)

            lastAppliedRichData = richData
            lastAppliedPlainText = plainText
        }

        func textDidChange(_ notification: Notification) {
            commitChanges()
        }

        /// 由 TextView 主动调用（例如调整图片大小完成后），用来立即回写 binding。
        ///
        /// 同步写入以避免快速输入时的竞态：若异步派发，SwiftUI 可能在两次 `commitChanges` 之间
        /// 用旧 data 触发 `updateNSView`，导致 `applyExternal` 把编辑器回滚到历史状态。
        func commitChanges() {
            guard !isApplyingExternalChange,
                  let tv = textView,
                  let storage = tv.textStorage else { return }

            let encoded = Self.encodeAttributedString(storage)
            let plain = Self.extractPlainText(from: storage)

            lastAppliedRichData = encoded
            lastAppliedPlainText = plain

            parent.richData = encoded
            parent.plainText = plain
            parent.onTextChange?()
        }

        // MARK: - Helpers

        private static func defaultAttributes(font: NSFont) -> [NSAttributedString.Key: Any] {
            [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]
        }

        private static func applyingDefaultAppearance(
            _ source: NSAttributedString,
            font: NSFont
        ) -> NSAttributedString {
            let mutable = NSMutableAttributedString(attributedString: source)
            let full = NSRange(location: 0, length: mutable.length)
            mutable.enumerateAttributes(in: full, options: []) { attrs, range, _ in
                var newAttrs = attrs
                if newAttrs[.font] == nil {
                    newAttrs[.font] = font
                }
                if newAttrs[.foregroundColor] == nil {
                    newAttrs[.foregroundColor] = NSColor.labelColor
                }
                mutable.setAttributes(newAttrs, range: range)
            }
            return mutable
        }

        /// 把历史存档里的原生 NSTextAttachment 升级为 `ResizableImageAttachment`，
        /// 这样调整过的图片尺寸才会通过 `displaySize` 可靠地被序列化。
        static func upgradingAttachments(_ source: NSAttributedString) -> NSAttributedString {
            let mutable = NSMutableAttributedString(attributedString: source)
            let full = NSRange(location: 0, length: mutable.length)
            mutable.enumerateAttribute(.attachment, in: full, options: []) { value, range, _ in
                guard let attachment = value as? NSTextAttachment else { return }
                if attachment is ResizableImageAttachment { return }

                let upgraded = ResizableImageAttachment()
                upgraded.image = attachment.image
                upgraded.fileWrapper = attachment.fileWrapper

                var size = attachment.bounds.size
                if size.width <= 1 || size.height <= 1 {
                    size = attachment.image?.size ?? .zero
                }
                upgraded.displaySize = size

                mutable.removeAttribute(.attachment, range: range)
                mutable.addAttribute(.attachment, value: upgraded, range: range)
            }
            return mutable
        }

        static func encodeAttributedString(_ attributed: NSAttributedString) -> Data? {
            try? NSKeyedArchiver.archivedData(
                withRootObject: attributed,
                requiringSecureCoding: true
            )
        }

        static func decodeAttributedString(from data: Data) -> NSAttributedString? {
            let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver?.requiresSecureCoding = false
            return unarchiver?.decodeObject(of: NSAttributedString.self, forKey: NSKeyedArchiveRootObjectKey)
        }

        /// 把 U+FFFC（附件占位符）替换为文本标签，便于搜索 / 预览识别。
        static func extractPlainText(from attributed: NSAttributedString) -> String {
            let raw = attributed.string
            guard raw.contains("\u{FFFC}") else { return raw }
            return raw.replacingOccurrences(of: "\u{FFFC}", with: "[图片]")
        }
    }
}

// MARK: - 自定义 NSTextView：粘贴图片 + 边缘光标 + 拖拽改大小 + 点击预览

/// 图片的可交互边缘类型。
private enum ImageEdgeZone {
    case right
    case bottom
    case corner

    var cursor: NSCursor {
        switch self {
        case .right: return .resizeLeftRight
        case .bottom: return .resizeUpDown
        case .corner: return .crosshair
        }
    }
}

final class ImagePastingTextView: NSTextView {

    /// 判定为「图片边缘」的敏感区域厚度（pt）。
    private let edgeHitThickness: CGFloat = 8

    private var trackingAreaRef: NSTrackingArea?

    // MARK: - Tracking / Cursor

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingAreaRef {
            removeTrackingArea(existing)
            trackingAreaRef = nil
        }
        let options: NSTrackingArea.Options = [
            .activeInKeyWindow,
            .mouseMoved,
            .mouseEnteredAndExited,
            .inVisibleRect
        ]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if !applyCursor(at: point) {
            super.mouseMoved(with: event)
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.iBeam.set()
        super.mouseExited(with: event)
    }

    /// 返回 true 表示已主动设置光标，调用方不需要再走父类默认逻辑。
    @discardableResult
    private func applyCursor(at point: NSPoint) -> Bool {
        if let hit = hitImageEdge(at: point) {
            hit.zone.cursor.set()
            return true
        }
        if hitImageInterior(at: point) != nil {
            NSCursor.pointingHand.set()
            return true
        }
        // 不在图片范围：交还给 NSTextView 自身的 I-beam。
        NSCursor.iBeam.set()
        return false
    }

    // MARK: - 粘贴 / 拖入图片

    override func paste(_ sender: Any?) {
        if tryPasteImages() { return }
        super.paste(sender)
    }

    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        if NSImage.canInit(with: pboard) && insertImagesFromPasteboard(pboard) {
            return true
        }
        return super.readSelection(from: pboard, type: type)
    }

    @discardableResult
    private func tryPasteImages() -> Bool {
        insertImagesFromPasteboard(NSPasteboard.general)
    }

    @discardableResult
    private func insertImagesFromPasteboard(_ pasteboard: NSPasteboard) -> Bool {
        guard let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
              !images.isEmpty else {
            return false
        }

        let maxW = preferredImageMaxWidth()
        // 保留当前输入字体/颜色等，让图片前后的文字保持同一种字体。
        let carryingAttributes = currentTypingAttributes()
        let container = NSMutableAttributedString()
        for image in images {
            let attachment = ResizableImageAttachment()
            attachment.image = image
            let size = image.size
            if size.width > 0 && size.height > 0 {
                let ratio = size.height / size.width
                let w = min(maxW, size.width)
                let h = w * ratio
                attachment.displaySize = NSSize(width: w, height: h)
            } else {
                attachment.displaySize = image.size
            }
            let attrImg = NSMutableAttributedString(attachment: attachment)
            attrImg.addAttributes(carryingAttributes, range: NSRange(location: 0, length: attrImg.length))
            container.append(attrImg)
            container.append(NSAttributedString(string: "\n", attributes: carryingAttributes))
        }

        guard shouldChangeText(in: selectedRange(), replacementString: nil) else { return false }
        textStorage?.replaceCharacters(in: selectedRange(), with: container)
        // 显式把输入属性锁回当前字体/颜色，否则 macOS 可能把后续键入切回系统默认字体。
        typingAttributes = carryingAttributes
        didChangeText()
        return true
    }

    /// 返回图片插入时要附带的属性：优先用当前 typingAttributes，字体/颜色缺失时回退到默认值。
    private func currentTypingAttributes() -> [NSAttributedString.Key: Any] {
        var attrs = typingAttributes
        if attrs[.font] == nil {
            attrs[.font] = font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        }
        if attrs[.foregroundColor] == nil {
            attrs[.foregroundColor] = NSColor.labelColor
        }
        return attrs
    }

    private func preferredImageMaxWidth() -> CGFloat {
        let containerWidth = textContainer?.containerSize.width ?? bounds.width
        let padding = (textContainer?.lineFragmentPadding ?? 5) * 2
        let available = containerWidth - padding - 8
        if available.isFinite, available > 120 {
            return min(available * 0.92, 560)
        }
        return 420
    }

    // MARK: - 点击：边缘 -> 调大小；内部 -> 预览

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if let hit = hitImageEdge(at: point) {
            beginResize(
                attachment: hit.attachment,
                charIndex: hit.charIndex,
                attachmentRect: hit.rect,
                startPoint: point,
                zone: hit.zone
            )
            return
        }

        if let interior = hitImageInterior(at: point) {
            trackPossibleImageClick(
                startEvent: event,
                startPoint: point,
                attachment: interior.attachment,
                charIndex: interior.charIndex
            )
            return
        }

        super.mouseDown(with: event)
    }

    /// 用户在图片内部按下：
    /// - 如果**没有拖动**就视为单击：选中这张图，并弹出大图预览（选中后按 Backspace 也能删掉）。
    /// - 如果发生拖动就只保持选中、不弹预览（继续拖动不会选中文本，这是为了避免和调整大小手势冲突）。
    private func trackPossibleImageClick(
        startEvent: NSEvent,
        startPoint: NSPoint,
        attachment: NSTextAttachment,
        charIndex: Int
    ) {
        guard let window else {
            super.mouseDown(with: startEvent)
            return
        }

        // 先把光标/选中设置到这张图上，便于 Backspace 删除。
        setSelectedRange(NSRange(location: charIndex, length: 1))

        let slop: CGFloat = 4
        var isClick = true

        while true {
            guard let event = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else { break }
            if event.type == .leftMouseDragged {
                let current = convert(event.locationInWindow, from: nil)
                if abs(current.x - startPoint.x) > slop || abs(current.y - startPoint.y) > slop {
                    isClick = false
                    break
                }
            } else if event.type == .leftMouseUp {
                break
            }
        }

        if isClick, let image = attachment.image {
            ImagePreviewWindow.shared.present(image: image, from: self.window)
        }
    }

    // MARK: - 调整大小

    private func beginResize(
        attachment: NSTextAttachment,
        charIndex: Int,
        attachmentRect: NSRect,
        startPoint: NSPoint,
        zone: ImageEdgeZone
    ) {
        guard let window, let storage = textStorage else { return }

        // 如果还是老版本的 NSTextAttachment，就原地升级成可持久化尺寸的子类。
        let resizable: ResizableImageAttachment
        if let existing = attachment as? ResizableImageAttachment {
            resizable = existing
        } else {
            resizable = ResizableImageAttachment()
            resizable.image = attachment.image
            resizable.fileWrapper = attachment.fileWrapper
            resizable.displaySize = attachment.bounds.size.width > 0
                ? attachment.bounds.size
                : (attachment.image?.size ?? attachmentRect.size)
            let range = NSRange(location: charIndex, length: 1)
            storage.removeAttribute(.attachment, range: range)
            storage.addAttribute(.attachment, value: resizable, range: range)
        }

        let image = resizable.image
        let baseSize = attachmentRect.size
        let aspect: CGFloat
        if let imgSize = image?.size, imgSize.width > 0 {
            aspect = imgSize.height / imgSize.width
        } else if baseSize.width > 0 {
            aspect = baseSize.height / baseSize.width
        } else {
            aspect = 1
        }

        let startW = max(baseSize.width, 40)
        let startH = max(baseSize.height, 40)
        var tracking = true

        while tracking {
            guard let event = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else { break }
            let current = convert(event.locationInWindow, from: nil)
            let deltaX = current.x - startPoint.x
            let deltaY = current.y - startPoint.y

            let containerWidth = textContainer?.containerSize.width ?? bounds.width
            let maxWidth = max(80, containerWidth - (textContainer?.lineFragmentPadding ?? 5) * 2 - 4)

            var newW = startW
            var newH = startH

            switch zone {
            case .right, .corner:
                newW = min(max(60, startW + deltaX), maxWidth)
                newH = max(40, newW * aspect)
            case .bottom:
                newH = max(40, startH + deltaY)
                newW = min(max(60, newH / max(aspect, 0.01)), maxWidth)
            }

            resizable.displaySize = NSSize(width: newW, height: newH)

            let range = NSRange(location: charIndex, length: 1)
            layoutManager?.invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
            layoutManager?.invalidateDisplay(forCharacterRange: range)
            needsDisplay = true

            if event.type == .leftMouseUp {
                tracking = false
            }
        }

        // 标记文本被改动过，驱动 Coordinator 重新序列化 & 回写 binding。
        // 对于只改变附件尺寸的情况，NSTextView 并不会自动发 textDidChange，
        // 所以我们显式调 didChangeText() + Coordinator.commitChanges()。
        didChangeText()
        if let delegate = delegate as? RichTextEditor.Coordinator {
            delegate.commitChanges()
        }
    }

    // MARK: - 命中测试

    private func hitImageEdge(at point: NSPoint)
        -> (attachment: NSTextAttachment, charIndex: Int, rect: NSRect, zone: ImageEdgeZone)?
    {
        guard let storage = textStorage else { return nil }
        let fullRange = NSRange(location: 0, length: storage.length)
        var result: (NSTextAttachment, Int, NSRect, ImageEdgeZone)? = nil
        storage.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, stop in
            guard let attachment = value as? NSTextAttachment else { return }
            guard let rect = rectForAttachment(atCharIndex: range.location) else { return }

            let corner = NSRect(
                x: rect.maxX - edgeHitThickness,
                y: rect.maxY - edgeHitThickness,
                width: edgeHitThickness * 2,
                height: edgeHitThickness * 2
            )
            if corner.contains(point) {
                result = (attachment, range.location, rect, .corner)
                stop.pointee = true
                return
            }

            let right = NSRect(
                x: rect.maxX - edgeHitThickness,
                y: rect.minY,
                width: edgeHitThickness * 2,
                height: rect.height
            )
            if right.contains(point) {
                result = (attachment, range.location, rect, .right)
                stop.pointee = true
                return
            }

            let bottom = NSRect(
                x: rect.minX,
                y: rect.maxY - edgeHitThickness,
                width: rect.width,
                height: edgeHitThickness * 2
            )
            if bottom.contains(point) {
                result = (attachment, range.location, rect, .bottom)
                stop.pointee = true
                return
            }
        }
        return result
    }

    private func hitImageInterior(at point: NSPoint)
        -> (attachment: NSTextAttachment, charIndex: Int, rect: NSRect)?
    {
        guard let storage = textStorage else { return nil }
        let fullRange = NSRange(location: 0, length: storage.length)
        var result: (NSTextAttachment, Int, NSRect)? = nil
        storage.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, stop in
            guard let attachment = value as? NSTextAttachment else { return }
            guard let rect = rectForAttachment(atCharIndex: range.location) else { return }
            let inside = rect.insetBy(dx: edgeHitThickness, dy: edgeHitThickness)
            if inside.width > 0 && inside.height > 0 && inside.contains(point) {
                result = (attachment, range.location, rect)
                stop.pointee = true
            }
        }
        return result
    }

    private func rectForAttachment(atCharIndex charIndex: Int) -> NSRect? {
        guard let layoutManager, let textContainer else { return nil }
        let charRange = NSRange(location: charIndex, length: 1)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: charRange, actualCharacterRange: nil)
        guard glyphRange.length > 0 else { return nil }
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect.origin.x += textContainerOrigin.x
        rect.origin.y += textContainerOrigin.y
        return rect
    }
}

// MARK: - 可持久化尺寸的图片附件

/// 标准 `NSTextAttachment` 的 `bounds` 属性在归档时不可靠；
/// 自带一个 `displaySize` 字段，并显式参与 NSSecureCoding，保证调整后的大小能被存盘。
@objc(EZResizableImageAttachment)
final class ResizableImageAttachment: NSTextAttachment {
    private static let widthKey = "eznote.displayWidth"
    private static let heightKey = "eznote.displayHeight"

    /// 期望显示尺寸；若为 0 则回退到图片原始尺寸。
    var displaySize: NSSize = .zero {
        didSet {
            // 同时同步 bounds，方便不依赖 attachmentBounds 的旧代码读取。
            bounds = NSRect(origin: .zero, size: displaySize)
        }
    }

    override init(data contentData: Data?, ofType uti: String?) {
        super.init(data: contentData, ofType: uti)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        let w = CGFloat(coder.decodeDouble(forKey: Self.widthKey))
        let h = CGFloat(coder.decodeDouble(forKey: Self.heightKey))
        if w > 0 && h > 0 {
            displaySize = NSSize(width: w, height: h)
        }
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(Double(displaySize.width), forKey: Self.widthKey)
        coder.encode(Double(displaySize.height), forKey: Self.heightKey)
    }

    override func attachmentBounds(
        for textContainer: NSTextContainer?,
        proposedLineFragment lineFrag: CGRect,
        glyphPosition position: CGPoint,
        characterIndex charIndex: Int
    ) -> CGRect {
        if displaySize.width > 0 && displaySize.height > 0 {
            return CGRect(origin: .zero, size: displaySize)
        }
        if let imgSize = image?.size, imgSize.width > 0 && imgSize.height > 0 {
            return CGRect(origin: .zero, size: imgSize)
        }
        return super.attachmentBounds(
            for: textContainer,
            proposedLineFragment: lineFrag,
            glyphPosition: position,
            characterIndex: charIndex
        )
    }

    override class var supportsSecureCoding: Bool { true }
}

// MARK: - 图片预览浮窗

final class ImagePreviewWindow {
    static let shared = ImagePreviewWindow()

    private var panel: NSPanel?

    private init() {}

    func present(image: NSImage, from owner: NSWindow? = nil) {
        panel?.close()

        let screen = owner?.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 900, height: 700)

        var w = image.size.width
        var h = image.size.height
        if w <= 1 || h <= 1 {
            w = 600; h = 400
        }
        let maxW = visible.width * 0.85
        let maxH = visible.height * 0.85
        if w > maxW {
            let ratio = h / w
            w = maxW
            h = w * ratio
        }
        if h > maxH {
            let ratio = w / h
            h = maxH
            w = h * ratio
        }
        w = max(320, w)
        h = max(240, h)

        let rect = NSRect(
            x: visible.midX - w / 2,
            y: visible.midY - h / 2,
            width: w,
            height: h
        )

        let newPanel = ImagePreviewPanel(
            contentRect: rect,
            styleMask: [
                .titled,
                .closable,
                .resizable,
                .fullSizeContentView,
                .nonactivatingPanel
            ],
            backing: .buffered,
            defer: false
        )
        newPanel.titlebarAppearsTransparent = true
        newPanel.title = ""
        newPanel.isFloatingPanel = true
        // 置于「状态栏 / 悬浮菜单」之上，能盖住全屏 App。
        newPanel.level = .statusBar
        // 所有桌面空间 + 全屏应用上都能出现。
        newPanel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]
        newPanel.isReleasedWhenClosed = false
        newPanel.hidesOnDeactivate = false
        newPanel.becomesKeyOnlyIfNeeded = true
        newPanel.backgroundColor = NSColor.black.withAlphaComponent(0.9)
        newPanel.onClose = { [weak self] in
            self?.panel = nil
        }

        let container = NSView(frame: NSRect(origin: .zero, size: rect.size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.92).cgColor
        container.autoresizingMask = [.width, .height]

        let imageView = NSImageView(frame: container.bounds)
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyDown
        imageView.imageAlignment = .alignCenter
        imageView.animates = true
        imageView.autoresizingMask = [.width, .height]
        container.addSubview(imageView)

        newPanel.contentView = container
        newPanel.orderFrontRegardless()
        newPanel.makeKey()

        self.panel = newPanel
    }
}

/// 支持 ESC 关闭、可作为 key window 的预览面板。
private final class ImagePreviewPanel: NSPanel {
    var onClose: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        close()
    }

    override func keyDown(with event: NSEvent) {
        // ESC 关闭
        if event.keyCode == 53 {
            close()
            return
        }
        super.keyDown(with: event)
    }

    override func close() {
        onClose?()
        super.close()
    }
}
