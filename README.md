# Aether CRT 4K — Razor Edition (v6)

A single-pass Vulkan-compatible Slang CRT shader preset for retro games, tested by its creator in Snes9x GTK on an AMD RX 7800 XT and 4K LG B3 OLED under KDE Wayland.

## Features

- Razor scanline definition and edge antialiasing
- RGB phosphor mask, glow and bloom
- Adjustable brightness, vibrance, highlights, and sharpness
- Aspect modes: native, 4:3, 8:7, 16:9, custom and stretch
- SDR output with HDR-inspired highlights; **not HDR10**

## Installation

1. Download both `aether-crt-4k-v6.slang` and `aether-crt-4k-v6.slangp` and put them in the same directory.
2. In Snes9x GTK, select Vulkan as the display driver.
3. Load `aether-crt-4k-v6.slangp` as the shader preset.
4. Adjust the shader parameters to taste.

Example directory: `~/.config/snes9x/aether/`.

## Suggested defaults

The included preset uses `RAZOR = 0.72`, `AA = 0.22`, and `ASPECTMODE = 1.0` (4:3). These are starting points, not universal settings.

## Compatibility

Tested by the creator with Snes9x GTK's Vulkan renderer. Other Slang-compatible frontends may work but have not been verified. Keep a known-working preset as a fallback.

## Licensing

A public license has not yet been selected. Do not assume permission to redistribute or modify until the project owner adds a license.
