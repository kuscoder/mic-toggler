<div align="center">

<img src="assets/mic_on.png" width="64" alt="">

# Mic Toggle

**A hotkey to mute and unmute your microphone on Windows.**
A tray icon shows whether the mic is on. Nothing else.

[![Release](https://img.shields.io/github/v/release/kuscoder/mic-toggler)](https://github.com/kuscoder/mic-toggler/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Windows 10/11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6)

**English** · [Русский](README.ru.md)

</div>

## Why

Plenty of microphones have no physical mute button: webcams, speakers with a built-in mic, budget USB mics. Windows has no global mute shortcut, and digging through sound settings every time gets old fast. Existing solutions either come bundled in large suites like PowerToys or only work inside one app (Discord, Zoom).

Mic Toggle does this one thing:

- one shortcut mutes and unmutes the microphone for every app at once;
- a tray icon shows the current state;
- a single ~1 MB exe: no installer, no services, no background processes besides itself.

## Installation

1. Download `MicToggle.exe` from the [latest release](https://github.com/kuscoder/mic-toggler/releases/latest). On 32-bit Windows, use `MicToggle-x86.exe`.
2. Run it. A microphone icon appears in the system tray.

If you don't see the icon, it's hidden under the "Show hidden icons" arrow. Drag it onto the taskbar to keep it visible.

> [!NOTE]
> Windows SmartScreen or your antivirus may warn about an unknown app. This happens with any unsigned exe compiled from AutoHotkey. The source code is open, and you can [build it yourself](#building-from-source).

## Usage

| Action                                          | Result                       |
| ----------------------------------------------- | ---------------------------- |
| <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>M</kbd> | Mute / unmute the microphone |
| Left-click the tray icon                        | Same                         |
| Right-click the tray icon                       | Settings menu                |

|                                  Icon                                  | State                         |
| :--------------------------------------------------------------------: | ----------------------------- |
|       <img src="assets/mic_on.png" width="20" alt="Microphone">        | Microphone on                 |
| <img src="assets/mic_off.png" width="20" alt="Crossed-out microphone"> | Microphone muted or not found |

A short beep plays on every toggle: high pitch for on, low pitch for off.

## Settings

All settings live in the tray icon's right-click menu and are saved automatically.

- **Microphone.** Which device to mute. Defaults to the Windows default microphone, together with the default communications microphone if Windows has a different one set. The list refreshes every time you open the menu.
- **Hotkey.** Any combination with <kbd>Ctrl</kbd>, <kbd>Alt</kbd>, <kbd>Shift</kbd> or <kbd>Win</kbd>, or a single <kbd>F1</kbd>–<kbd>F24</kbd> key. Works with any keyboard layout.
- **Sound feedback.** Turn the toggle beep on or off.
- **Start with Windows.** Adds a shortcut to the Startup folder.
- **Language.** English or Russian. Picked automatically from the system language on first launch.

Settings are stored in `%AppData%\MicToggle\settings.ini`.

## How it works

Mic Toggle sets the **mute** flag on the recording device itself. It's the same checkbox you find in _Control Panel → Sound → Recording → Microphone Properties → Levels_, set through the standard Windows Core Audio API (`IAudioEndpointVolume::SetMute`).

What that means in practice:

- **Every app is muted at once.** Discord, Zoom, Telegram and your browser all receive silence, with no per-app settings to touch.
- **The device stays connected.** Apps don't lose the microphone or switch to another one, as happens when you disable the device in Windows settings. Unmute, and audio flows again immediately.
- **The state is always accurate.** If the mic is muted elsewhere (say, in Windows settings), the tray icon updates within a second.
- **Nothing is recorded or sent.** The app never opens an audio stream and never touches the network.

## Limitations

- **One microphone at a time.** Mic Toggle mutes only the selected microphone. If you have several, make sure the right one is selected in the menu: the others stay on. We're thinking about extending this, and [contributions](CONTRIBUTING.md) are welcome.
- **ASIO and exclusive mode.** Apps that access the audio interface directly through ASIO drivers or WASAPI exclusive mode (mostly DAWs and other pro audio software) bypass the Windows audio mixer, so muting doesn't affect them.

## Building from source

You'll need [AutoHotkey v2](https://www.autohotkey.com/). The Ahk2Exe compiler can be installed alongside it.

1. Clone the repository:
   ```
   git clone https://github.com/kuscoder/mic-toggler.git
   ```
2. Open **AutoHotkey Dash → Compile** and select `MicToggle.ahk`.
3. Click **Convert**. `MicToggle.exe` appears next to the script, with the icons embedded.

From the command line:

```
"C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" /in MicToggle.ahk /base "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
```

With AutoHotkey v2 installed, you can also just double-click `MicToggle.ahk` to run it without compiling.

## Uninstalling

1. Uncheck **Start with Windows** if it's enabled.
2. Choose **Exit** from the menu.
3. Delete `MicToggle.exe` and the `%AppData%\MicToggle` cache folder.

## License

[MIT](LICENSE). Icons from [Lucide](https://lucide.dev) ([ISC License](https://lucide.dev/license)).
