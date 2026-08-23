# Barcodes — Connect IQ app for Garmin Instinct 3 Solar

Displays QR codes, Code 128 (text/number) barcodes, and EAN-13 / EAN-8 retail
barcodes full-screen on the watch. You manage a list of up to 8 named codes
from the **Garmin Connect mobile app's settings for this app** — no on-watch
typing required.

## What's implemented

- **QR encoder** — byte mode, versions 1–10, error-correction level L, fixed
  mask pattern 0, with automatic ECI/UTF-8 signaling for non-ASCII text.
- **Code 128 (subset B)** — ASCII 32–126 (letters, digits, punctuation).
- **EAN-13 / EAN-8** — standard retail barcode checksum + encoding.

All three encoders were built and validated outside this project first: I
wrote reference implementations in Python, checked their output bit-for-bit
(or via full render→scan round-trip with `zbar`) against established
libraries (`qrcode`, `python-barcode`) across dozens of test strings —
including edge cases like unicode text, every QR version 1–10, and random
alphanumeric strings — before porting the validated logic into Monkey C.
I can't compile/run the actual `.mc` files in this environment (no Connect
IQ SDK access here), so **please do a real build + sideload test with a
couple of your own codes before relying on this**, especially the QR path
since it's the most complex port.

## Project layout

```
BarcodeWatch/
├── manifest.xml                  — app id, target devices, permissions
├── monkey.jungle                 — build file
├── resources/
│   ├── strings/strings.xml       — UI text
│   ├── settings/
│   │   ├── properties.xml        — default property values (8 code slots)
│   │   └── settings.xml          — Garmin Connect Mobile settings UI schema
│   └── drawables/                — placeholder launcher icon (replace freely)
└── source/
    ├── BarcodesApp.mc            — app entry point
    ├── CodeListView.mc           — builds the Menu2 list of your codes
    ├── CodeListDelegate.mc       — handles selecting a code from the list
    ├── BarcodeView.mc            — renders the selected code full-screen
    ├── BarcodeDelegate.mc        — handles the Back button
    ├── QrEncoder.mc              — QR encoder
    ├── Code128Encoder.mc         — Code 128 encoder
    └── EanEncoder.mc             — EAN-13/EAN-8 encoder
```

## Before you build: confirm the device ID

`manifest.xml` currently lists:
```xml
<iq:product id="instinct3solar45mm"/>
<iq:product id="instinct3solar51mm"/>
```
These are my best guess at the SDK's internal device identifiers for the
Instinct 3 Solar. Open the project in VS Code with the **Monkey C** extension
and use its manifest editor (the checkbox list of devices) to confirm/fix
these — the extension knows the exact current ID strings, so trust that over
my guess.

## Build & sideload

1. Install the **Connect IQ SDK** (via the SDK Manager, linked from
   `developer.garmin.com/connect-iq/sdk/`) and the **Monkey C** extension for
   VS Code.
2. Open this folder (`BarcodeWatch/`) in VS Code.
3. Generate a developer key once (VS Code: `Monkey C: Generate a Developer
   Key`), if you don't already have one.
4. Build: `Monkey C: Build Current Project` (or from the terminal, with the
   SDK's `bin/` on your `PATH`):
   ```
   monkeyc -f monkey.jungle -d instinct3solar45mm -o bin/Barcodes.prg -y developer_key.der
   ```
5. Sideload:
   - **USB**: connect the watch, copy `bin/Barcodes.prg` to the `GARMIN/APPS/`
     folder on the watch's mass-storage volume, eject, restart the watch.
   - **Simulator** (to test without the watch first): `Monkey C: Run Current
     Project in Simulator`.

## Configuring your codes

1. Install the app on the watch once (step 5 above).
2. Open the **Garmin Connect** mobile app → **Devices** → your Instinct 3 →
   **Connect IQ Store / My Apps** (or **Settings** for the app, depending on
   Garmin Connect app version) → find "Codes" → open its settings.
3. For each slot you want to use, fill in:
   - **Name** — shown in the on-watch list (e.g. "Gym", "Library card").
   - **Type** — QR code / Code 128 / EAN-13 / EAN-8.
   - **Value** — the text or number to encode.
4. Sync. Open the app on the watch — your named codes appear in a list;
   select one to display it full-screen. Back button returns to the list.

## Practical limits on a 176×176 screen

- **QR**: quiet zone is intentionally shrunk to 2 modules (spec recommends 4)
  to fit more data on-screen. Keep text short — under ~40 characters keeps
  it at QR version 1–3, which scans reliably at arm's length. Longer text
  still encodes correctly (up to ~270 bytes) but produces a very dense code
  that may need to be held close to the scanner.
- **Code 128**: keep codes under ~15 characters. Longer strings still encode
  correctly but the module width shrinks and scanning gets less reliable on
  a screen this size.
- **EAN-13/EAN-8**: fixed length (12/13 or 7/8 digits), so no tuning needed —
  these are usually well within scanning range on this display.

## Known limitations / things you may want to extend

- Code 128 only implements subset B (no automatic switching to subset A/C),
  so it won't encode control characters, and numeric-only strings won't get
  the denser subset-C packing — fine for typical membership/loyalty codes,
  less ideal for very long numeric IDs.
- No on-watch editing — by design, given how tedious text entry is on a
  5-button watch. All configuration happens on the phone.
- No horizontal panning for barcodes wider than the screen — very long
  Code 128 values just get compressed instead. Let me know if you actually
  hit this in practice and I can add panning.
