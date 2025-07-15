<p align="center">
  <img src="demo.gif" width="800" alt="Clipboard Demo"/>
</p>

<h1 align="center">📋 Clipboard</h1>

<p align="center">
  A simple and effective macOS command-line tool for accessing and manipulating clipboard content using Swift.
</p>

---

## 🚀 Features

- ✅ Get current clipboard contents
- 📌 Bookmark clipboard entries for quick reuse
- ⚡ Swift and lightweight
- 🔄 Start at system login (via Login Items or Launch Agent)

---

## 📦 Installation

### Option 1: Use Pre-built Binary
```bash
# Clone the repository
git clone "https://github.com/elishaJ/Clipboard.git"
cd ClipboardTool

# Run the pre-built binary
./Clipboard
```

### Option 2: Build from Source
```bash
# Clone the repository
git clone "https://github.com/elishaJ/Clipboard.git"
cd ClipboardTool

# Compile and run
swift ClipboardTool.swift
```

### Option 3: Build Binary
```bash
# Build optimized binary
swiftc -O ClipboardTool.swift -o Clipboard

# Run the binary
./Clipboard
```

## 🛠 Usage

### Running the Tool
- **Pre-built binary**: `./Clipboard`
- **From source**: `swift ClipboardTool.swift`

### Controls
- **Menu bar icon**: Click 📋 to open clipboard history
- **Hotkey**: Press `Cmd+Shift+V` to toggle popup
- **Copy**: Click any entry to copy to clipboard
- **Bookmark**: Click ☆ to bookmark (★ to unbookmark)
- **Delete**: Click 🗑 to remove entry
- **Quit**: Right-click on menu bar icon and select "Quit Clipboard"

### Auto-start at Login
To start Clipboard automatically:
1. Go to **System Preferences** → **Users & Groups** → **Login Items**
2. Click **+** and add the Clipboard binary or app bundle
3. Or use the compiled binary path in a launch agent