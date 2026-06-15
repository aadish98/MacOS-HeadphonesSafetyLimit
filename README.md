# Headphone Safety Limit for macOS

Headphone Safety Limit is a small macOS menu-bar app that approximates iOS's **Headphone Safety -> Reduce Loud Audio** feature for Mac.

macOS does not expose the same content-aware loudness limiter that iOS uses, so this app takes a practical proxy approach: when the active output route is detected as headphones or earphones, it caps the system output volume to a user-defined ceiling and re-applies that cap whenever the volume or active output route changes.

## What It Does

- Detects the currently active macOS output device.
- Classifies wired, USB, and Bluetooth headphone routes.
- Applies a single global volume ceiling to whichever headphone route is active.
- Watches for output-device changes, device add/remove events, and volume changes.
- Rebinds listeners when the active output route changes, so it can follow several connected headphones without clamping inactive devices.
- Persists the protection toggle, ceiling, and wired/Bluetooth scope settings.

## What It Does Not Do

This is not a true SPL or loudness limiter. It does not analyze audio content and cannot know how loud a given track is in dB at your ear. It caps the macOS output volume slider as a rough hearing-safety proxy.

Some Bluetooth or external devices may expose read-only volume controls to CoreAudio. In those cases, the app reports that the output is read-only instead of silently pretending to clamp it.

## Build

Requires macOS with the Swift toolchain installed.

```sh
swift build
```

To build a launchable menu-bar `.app` bundle:

```sh
./build_app.sh
```

Then run:

```sh
open HeadphoneSafety.app
```

## Usage

Open the menu-bar item, enable **Reduce Loud Audio**, and choose a volume ceiling. The app only clamps when the active output is detected as headphones/earphones and the matching scope toggle is enabled.

For best validation, test with:

- Built-in speakers: should not clamp.
- Wired headphones/earphones: should clamp.
- Bluetooth headphones/earphones: should clamp.
- Several connected outputs: switching the active route should move protection to the newly active route.
