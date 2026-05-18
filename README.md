# IDECord

Discord Rich Presence for your IDE — a single macOS menu bar app that works across multiple IDEs.

![macOS](https://img.shields.io/badge/macOS-14.0+-000000?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange?logo=swift)
![License](https://img.shields.io/github/license/Hud2004/IDECord)

---

## Overview

Most IDEs require installing a separate plugin to show Discord Rich Presence. IDECord replaces all of them — one app, all your IDEs.

Enable only the IDEs you use. IDECord detects which one you're actively working in and updates your Discord status automatically.

## Features

- Supports 12 IDEs out of the box
- Shows current file and project name in your Discord status
- Automatically switches when you change IDEs
- Keeps the last used IDE shown when you switch to another app
- Runs quietly in the menu bar

## Supported IDEs

| IDE | Discord App Name |
|-----|-----------------|
| Xcode | Xcode |
| Visual Studio Code | Visual Studio Code |
| Cursor | Cursor |
| IntelliJ IDEA | IntelliJ IDEA |
| WebStorm | WebStorm |
| PyCharm | PyCharm |
| Android Studio | Android Studio |
| CLion | CLion |
| GoLand | GoLand |
| Rider | Rider |
| Nova | Nova |
| Antigravity | Antigravity |

## Requirements

- macOS 14.0 or later
- Discord desktop app running

## Installation

1. Clone the repository
2. Open `IDECord.xcodeproj` in Xcode
3. Build and run (⌘R)

> **First launch:** macOS will ask for **Accessibility permission** — this is required to read the active file and project name from your IDE's window title.  
> System Settings → Privacy & Security → Accessibility → enable IDECord

> **Gatekeeper warning:** If you see "IDECord cannot be opened because the developer cannot be verified", go to System Settings → Privacy & Security → scroll down → click **Open Anyway**.

## Usage

1. Launch IDECord — it appears in the menu bar
2. Click the menu bar icon → toggle the IDEs you want to track
3. Click **Start**
4. Open any enabled IDE and start coding — your Discord status updates automatically

## Discord Setup

IDECord uses pre-configured Discord application IDs, so no setup is required for basic use.

Each IDE shows as its own Discord app name (e.g., "Playing Xcode", "Playing Visual Studio Code").

To show IDE icons in your Discord status, upload each IDE's icon to the corresponding Discord application's **Rich Presence → Art Assets** with the following key names:

| Key | IDE |
|-----|-----|
| `xcode` | Xcode |
| `vscode` | Visual Studio Code |
| `cursor` | Cursor |
| `intellij` | IntelliJ IDEA |
| `webstorm` | WebStorm |
| `pycharm` | PyCharm |
| `androidstudio` | Android Studio |
| `clion` | CLion |
| `goland` | GoLand |
| `rider` | Rider |
| `nova` | Nova |
| `antigravity` | Antigravity |

## License

MIT
