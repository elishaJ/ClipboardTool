import Cocoa
import Carbon
import CryptoKit
import Security

class ClipboardManager: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var clipboardHistory: [ClipboardEntry] = []
    private var bookmarkedEntries: [ClipboardEntry] = []
    private var lastClipboardContent: String = ""
    private var clipboardTimer: Timer?
    private var hotKeyRef: EventHotKeyRef?
    private var encryptionKey: SymmetricKey
    
    override init() {
        self.encryptionKey = ClipboardManager.getOrCreateEncryptionKey()
        super.init()
        setupStatusItem()
        setupPopover()
        setupHotKey()
        startClipboardMonitoring()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "📋"
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover.contentViewController = ClipboardViewController()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 400)
        
        // Set reference to clipboard manager
        if let viewController = popover.contentViewController as? ClipboardViewController {
            viewController.clipboardManager = self
        }
    }
    
    private func setupHotKey() {
        // Register Cmd+Shift+V hotkey
        let hotKeySignature = OSType(0x436C6970) // 'Clip'
        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: 1)
        
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            if let manager = Unmanaged<ClipboardManager>.fromOpaque(userData!).takeUnretainedValue() as ClipboardManager? {
                manager.togglePopover()
            }
            return noErr
        }, 1, &eventSpec, Unmanaged.passUnretained(self).toOpaque(), nil)
        
        RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(cmdKey | shiftKey), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
    
    private func startClipboardMonitoring() {
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.checkClipboard()
        }
    }
    
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        guard let currentContent = pasteboard.string(forType: .string),
              !currentContent.isEmpty,
              currentContent != lastClipboardContent else { return }
        
        lastClipboardContent = currentContent
        addToHistory(content: currentContent)
    }
    
    private func addToHistory(content: String) {
        let isSensitive = isSensitiveContent(content)
        let processedContent = isSensitive ? encrypt(content) : content
        let entry = ClipboardEntry(content: processedContent, timestamp: Date(), isEncrypted: isSensitive)
        
        // Remove if already exists (compare original content)
        let originalContent = isSensitive ? content : processedContent
        clipboardHistory.removeAll { 
            let entryContent = $0.isEncrypted ? decrypt($0.content) : $0.content
            return entryContent == originalContent
        }
        
        clipboardHistory.insert(entry, at: 0)
        
        if clipboardHistory.count > 10 {
            clipboardHistory.removeLast()
        }
        
        updateUI()
    }
    
    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
    
    func bookmarkEntry(_ entry: ClipboardEntry) {
        // Remove from bookmarks if already bookmarked
        bookmarkedEntries.removeAll { $0.content == entry.content }
        
        // Add to bookmarks
        bookmarkedEntries.insert(entry, at: 0)
        
        // Keep max 5 bookmarks
        if bookmarkedEntries.count > 5 {
            bookmarkedEntries.removeLast()
        }
        
        updateUI()
    }
    
    func unbookmarkEntry(_ entry: ClipboardEntry) {
        bookmarkedEntries.removeAll { $0.content == entry.content }
        updateUI()
    }
    
    func deleteEntry(_ entry: ClipboardEntry) {
        clipboardHistory.removeAll { $0.content == entry.content }
        bookmarkedEntries.removeAll { $0.content == entry.content }
        updateUI()
    }
    
    func copyToClipboard(_ entry: ClipboardEntry) {
        let content = entry.isEncrypted ? decrypt(entry.content) : entry.content
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        lastClipboardContent = content
        popover.performClose(nil)
    }
    
    private func updateUI() {
        DispatchQueue.main.async {
            if let viewController = self.popover.contentViewController as? ClipboardViewController {
                viewController.updateData(history: self.clipboardHistory, bookmarks: self.bookmarkedEntries)
            }
        }
    }
    
    func isBookmarked(_ entry: ClipboardEntry) -> Bool {
        let entryContent = entry.isEncrypted ? decrypt(entry.content) : entry.content
        return bookmarkedEntries.contains { 
            let bookmarkContent = $0.isEncrypted ? decrypt($0.content) : $0.content
            return bookmarkContent == entryContent
        }
    }
    
    private func isSensitiveContent(_ content: String) -> Bool {
        let patterns = [
            "(?i)password",
            "(?i)token",
            "(?i)api[_-]?key",
            "(?i)secret",
            "\\b\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}\\b", // Credit card
            "\\b\\d{3}-\\d{2}-\\d{4}\\b" // SSN
        ]
        
        return patterns.contains { content.range(of: $0, options: .regularExpression) != nil }
    }
    
    private func encrypt(_ text: String) -> String {
        guard let data = text.data(using: .utf8) else { return text }
        do {
            let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
            return sealedBox.combined?.base64EncodedString() ?? text
        } catch {
            return text
        }
    }
    
    private func decrypt(_ encryptedText: String) -> String {
        guard let data = Data(base64Encoded: encryptedText) else { return encryptedText }
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
            return String(data: decryptedData, encoding: .utf8) ?? encryptedText
        } catch {
            return encryptedText
        }
    }
    
    private static func getOrCreateEncryptionKey() -> SymmetricKey {
        let keyTag = "com.clipboardtool.encryptionkey"
        
        // Try to load existing key
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let keyData = result as? Data {
            return SymmetricKey(data: keyData)
        }
        
        // Create new key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag,
            kSecValueData as String: keyData
        ]
        
        SecItemAdd(addQuery as CFDictionary, nil)
        return newKey
    }
}

struct ClipboardEntry {
    let content: String
    let timestamp: Date
    let isEncrypted: Bool
    
    init(content: String, timestamp: Date, isEncrypted: Bool = false) {
        self.content = content
        self.timestamp = timestamp
        self.isEncrypted = isEncrypted
    }
    
    var previewText: String {
        if isEncrypted {
            return "🔒 [Encrypted Content]"
        }
        
        let maxLength = 35
        let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        
        let singleSpaced = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        if singleSpaced.count > maxLength {
            return String(singleSpaced.prefix(maxLength)) + "..."
        }
        return singleSpaced.isEmpty ? "[Empty]" : singleSpaced
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

class ClipboardViewController: NSViewController {
    weak var clipboardManager: ClipboardManager?
    private var scrollView: NSScrollView!
    private var stackView: NSStackView!
    private var history: [ClipboardEntry] = []
    private var bookmarks: [ClipboardEntry] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 400))
    }
    
    private func setupUI() {
        // Create scroll view
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create stack view
        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 0
        stackView.alignment = .leading
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create a container view for the stack view
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)
        
        scrollView.documentView = containerView
        view.addSubview(scrollView)
        
        // Constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            
            // Stack view constraints within container
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -16),
            
            // Container view constraints
            containerView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])
        
        updateDisplay()
    }
    
    func updateData(history: [ClipboardEntry], bookmarks: [ClipboardEntry]) {
        self.history = history
        self.bookmarks = bookmarks
        updateDisplay()
    }
    
    private func updateDisplay() {
        guard let stackView = self.stackView else { return }
        
        // Clear existing views
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add bookmarks section only if there are bookmarks
        if !bookmarks.isEmpty {
            let bookmarkHeader = createSectionHeader("📌 Bookmarks")
            stackView.addArrangedSubview(bookmarkHeader)
            
            // Add separator after header
            stackView.addArrangedSubview(createSeparator())
            
            for (index, bookmark) in bookmarks.enumerated() {
                let entryView = createEntryView(bookmark, isBookmarked: true)
                stackView.addArrangedSubview(entryView)
                
                // Add separator between entries (but not after last one)
                if index < bookmarks.count - 1 {
                    stackView.addArrangedSubview(createSeparator())
                }
            }
            
            // Add thicker separator between sections
            stackView.addArrangedSubview(createThickSeparator())
        }
        
        // Always add history section
        let historyHeader = createSectionHeader("🕒 History")
        stackView.addArrangedSubview(historyHeader)
        
        // Add separator after header
        stackView.addArrangedSubview(createSeparator())
        
        // Filter out bookmarked entries from history
        let bookmarkedContents = Set(bookmarks.map { $0.content })
        let unbookmarkedHistory = history.filter { !bookmarkedContents.contains($0.content) }
        
        if unbookmarkedHistory.isEmpty {
            let emptyLabel = NSTextField(labelWithString: history.isEmpty ? "No clipboard history yet" : "All items are bookmarked")
            emptyLabel.textColor = .secondaryLabelColor
            emptyLabel.font = .systemFont(ofSize: 12)
            emptyLabel.alignment = .center
            stackView.addArrangedSubview(emptyLabel)
        } else {
            for (index, entry) in unbookmarkedHistory.enumerated() {
                let entryView = createEntryView(entry, isBookmarked: false)
                stackView.addArrangedSubview(entryView)
                
                // Add separator between entries (but not after last one)
                if index < unbookmarkedHistory.count - 1 {
                    stackView.addArrangedSubview(createSeparator())
                }
            }
        }
    }
    
    private func createSeparator() -> NSView {
        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return separator
    }
    
    private func createThickSeparator() -> NSView {
        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        separator.heightAnchor.constraint(equalToConstant: 8).isActive = true
        return separator
    }
    
    private func createSectionHeader(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .boldSystemFont(ofSize: 13)
        label.textColor = .labelColor
        label.alignment = .center
        
        let container = NSView()
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])
        
        return container
    }
    
    private func createEntryView(_ entry: ClipboardEntry, isBookmarked: Bool) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        container.layer?.cornerRadius = 4
        
        // Main content button (takes up most space)
        let contentButton = NSButton()
        contentButton.title = entry.previewText
        contentButton.bezelStyle = .regularSquare
        contentButton.isBordered = false
        contentButton.contentTintColor = .labelColor
        contentButton.alignment = .left
        contentButton.target = self
        contentButton.action = #selector(copyEntry(_:))
        contentButton.tag = hashValue(for: entry.content)
        contentButton.font = .systemFont(ofSize: 13)
        
        // Bookmark button
        let bookmarkButton = NSButton()
        bookmarkButton.title = isBookmarked ? "★" : "☆"
        bookmarkButton.bezelStyle = .regularSquare
        bookmarkButton.isBordered = false
        bookmarkButton.target = self
        bookmarkButton.action = #selector(toggleBookmark(_:))
        bookmarkButton.tag = hashValue(for: entry.content)
        bookmarkButton.font = .systemFont(ofSize: 14)
        bookmarkButton.contentTintColor = isBookmarked ? .systemYellow : .secondaryLabelColor
        
        // Delete button
        let deleteButton = NSButton()
        deleteButton.title = "🗑"
        deleteButton.bezelStyle = .regularSquare
        deleteButton.isBordered = false
        deleteButton.target = self
        deleteButton.action = #selector(deleteEntry(_:))
        deleteButton.tag = hashValue(for: entry.content)
        deleteButton.font = .systemFont(ofSize: 12)
        
        // Add subviews
        [contentButton, bookmarkButton, deleteButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview($0)
        }
        
        // Layout constraints - very compact layout
        NSLayoutConstraint.activate([
            // Delete button - FIXED to right edge
            deleteButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            deleteButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            deleteButton.widthAnchor.constraint(equalToConstant: 24),
            deleteButton.heightAnchor.constraint(equalToConstant: 24),
            
            // Bookmark button - FIXED next to delete button
            bookmarkButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            bookmarkButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -2),
            bookmarkButton.widthAnchor.constraint(equalToConstant: 24),
            bookmarkButton.heightAnchor.constraint(equalToConstant: 24),
            
            // Content button - takes remaining space, centered vertically
            contentButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            contentButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            contentButton.trailingAnchor.constraint(lessThanOrEqualTo: bookmarkButton.leadingAnchor, constant: -8),
            contentButton.heightAnchor.constraint(equalToConstant: 20),
            
            // Container height - very compact
            container.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        return container
    }
    
    @objc private func copyEntry(_ sender: NSButton) {
        if let entry = findEntry(by: sender.tag) {
            clipboardManager?.copyToClipboard(entry)
        }
    }
    
    @objc private func toggleBookmark(_ sender: NSButton) {
        if let entry = findEntry(by: sender.tag) {
            if clipboardManager?.isBookmarked(entry) ?? false {
                clipboardManager?.unbookmarkEntry(entry)
            } else {
                clipboardManager?.bookmarkEntry(entry)
            }
        }
    }
    
    @objc private func deleteEntry(_ sender: NSButton) {
        if let entry = findEntry(by: sender.tag) {
            clipboardManager?.deleteEntry(entry)
        }
    }
    
    private func findEntry(by tag: Int) -> ClipboardEntry? {
        let allEntries = bookmarks + history
        return allEntries.first { hashValue(for: $0.content) == tag }
    }
    
    private func hashValue(for string: String) -> Int {
        return string.hashValue
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var clipboardManager: ClipboardManager!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        clipboardManager = ClipboardManager()
        
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

// MARK: - Main
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()