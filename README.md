# DesmosPopUp

DesmosPopUp is a lightweight macOS menu bar app that provides quick access to Desmos calculators (Scientific, Graphing, and Matrix) in a floating window. Instantly toggle the window with a global hotkey, and switch between calculator types with a single click.

## Features

- **Menu Bar Icon**: Quickly show/hide the Desmos window from your menu bar.
- **Global Hotkey**: Instantly toggle the Desmos window from anywhere (default: Option + D).
- **Floating Window**: The Desmos window stays on top of other windows for easy access.
- **Switch Calculators**: Use title bar buttons to switch between Scientific, Graphing, and Matrix calculators.
- **Hide/Show Menu Bar Icon**: Toggle the menu bar icon from the window's title bar.
- **Quit Button**: Easily quit the app from the window's title bar.

## Installation

### Option 1: Download DMG

- Download the latest `.dmg` release from the [Releases](https://github.com/yourusername/DesmosPopUp/releases) page.
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
  - Use the leftmost button (X) to quit the app.
  - Use the eye icon to hide/show the menu bar icon.
  - Use the right-side buttons to switch between Matrix, Graphing, and Scientific calculators.

## Customization

- **Hotkey**: The default hotkey is Option + D. (Changing the hotkey via UI is not yet implemented.)
- **Window**: The window floats above other apps and can be resized, but not below a minimum size.

## Requirements

- macOS 12.0 or later
- Xcode 14 or later

## License

MIT License.

---

This project is not affiliated with or endorsed by Desmos. All trademarks and copyrights are property of their respective owners.
