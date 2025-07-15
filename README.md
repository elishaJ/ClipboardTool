<p align="center">
  <img src="demo.gif" width="800" alt="ClipboardTool Demo"/>
</p>

<h1 align="center">📋 ClipboardTool</h1>

<p align="center">
  A simple and effective macOS command-line tool for accessing and manipulating clipboard content using Swift.
</p>

---

## 🚀 Features

- ✅ Get current clipboard contents
- 📌 Bookmark clipboard entries for quick reuse
- 🔒 **Automatic encryption** for sensitive content (passwords, tokens, credit cards)
- ⚡ Swift and lightweight
- 🔄 Start at system login (via Login Items or Launch Agent)

---

## 📦 Installation

### Option 1: Use Pre-built Binary
```bash
# Clone the repository
git clone "https://github.com/elishaJ/ClipboardTool.git"
cd ClipboardTool

# Run the pre-built binary
./ClipboardTool
```

### Option 2: Build from Source
```bash
# Clone the repository
git clone "https://github.com/elishaJ/ClipboardTool.git"
cd ClipboardTool

# Compile and run
swift ClipboardTool.swift
```

### Option 3: Build Binary
```bash
# Build optimized binary
swiftc -O ClipboardTool.swift -o ClipboardTool

# Run the binary
./ClipboardTool
```

## 🛠 Usage

### Running the Tool
- **Pre-built binary**: `./ClipboardTool`
- **From source**: `swift ClipboardTool.swift`

### Controls
- **Menu bar icon**: Click 📋 to open clipboard history
- **Hotkey**: Press `Cmd+Shift+V` to toggle popup
- **Copy**: Click any entry to copy to clipboard (auto-decrypts if needed)
- **Bookmark**: Click ☆ to bookmark (★ to unbookmark)
- **Delete**: Click 🗑 to remove entry
- **Encrypted entries**: Show 🔒 [Encrypted Content] for sensitive data

### Auto-start at Login
To start ClipboardTool automatically:
1. Go to **System Preferences** → **Users & Groups** → **Login Items**
2. Click **+** and add the ClipboardTool binary
3. Or use the compiled binary path in a launch agent

## 🔒 Security Features

### How It Works
- **AES-256-GCM encryption** for sensitive data
- **Device keychain** stores encryption key securely
- **Transparent operation** - encrypted entries show 🔒 icon
- **Zero configuration** - works automatically

### Privacy
- Encryption key unique to each device
- Sensitive data unreadable without the key
- Regular clipboard text remains unencrypted for performance