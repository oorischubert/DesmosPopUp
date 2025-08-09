# DesmosPopUp

DesmosPopUp is a lightweight macOS menu bar app that provides quick access to Desmos calculators (Scientific, Graphing, and Matrix) in a floating window. Instantly toggle the window with a global hotkey, and switch between calculator types with a single click.

## Features

- **Menu Bar Icon**: Quickly show/hide the Desmos window from your menu bar.
- **Configurable Global Hotkey**: Instantly toggle the Desmos window from anywhere (default: Option + D), and change it via Settings.
- **Floating Window**: The Desmos window stays on top of other windows for easy access.
- **Switch Calculators**: Use title bar buttons to switch between Scientific, Graphing, and Matrix calculators.
- **Settings Menu**: A gear button in the title bar opens a menu with: Set Hotkey, Hide/Show Icon, and Quit.

## Installation

### Option 1: Download DMG

- Download the latest `.dmg` release from the [Releases](https://github.com/oorischubert/DesmosPopUp/releases/tag/DesmosPopUpv1) page.
- Open the DMG and drag `DesmosPopUp.app` to your Applications folder.
- Launch the app from Applications.

### Option 2: Build from Source

1. Clone or download this repository.
2. Open `DesmosPopUp.xcodeproj` in Xcode.
3. Build and run the app (Product > Run, or `Cmd+R`).

## Usage

- Click the menu bar icon (a "D" in a circle) to show or hide the Desmos window.
- Use the global hotkey (Option + D by default) to toggle the window from anywhere.
- In the Desmos window's title bar:
  - Use the right-side buttons to switch between Matrix, Graphing, and Scientific calculators.
  - Click the gear button to open Settings:
    - Set Hotkey…: Press a new shortcut (must include ⌘/⌥/⇧/⌃). Press Esc to cancel.
    - Hide/Show Icon: Toggle the menu bar icon.
    - Quit: Exit the app.

## Customization

- **Hotkey**: The default hotkey is Option + D. To change it, open Settings (gear in the title bar) → Set Hotkey, then press your desired combination (requires at least one modifier: ⌘, ⌥, ⇧, or ⌃). The selection is saved and persists across launches. Press Esc to cancel.
- **Window**: The window floats above other apps and can be resized, but not below a minimum size.

## Requirements

- macOS 12.0 or later
- Xcode 14 or later

## License

MIT License.

---

This project is not affiliated with or endorsed by Desmos. All trademarks and copyrights are property of their respective owners.
