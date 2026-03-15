![Boxer](http://boxerapp.com/static/images/gloves_96.png)

# Boxer — Apple Silicon Fork

This is a fork of [Boxer](https://github.com/alunbestor/Boxer) (via the [maddsV2](https://github.com/alunbestor/Boxer/tree/maddsV2) branch), updated to run natively on Apple Silicon (ARM64) with a modern Metal rendering pipeline, crash fixes, and several quality-of-life improvements.

The original Boxer was created by Alun Bestor and is a polished DOSBox front-end for macOS. This fork picks up where the community left off and makes it run on modern Macs.

---

## What's Different From the Original

### Apple Silicon (ARM64) Native Support

The biggest change. Boxer now builds and runs natively on Apple Silicon Macs. This required:

- Switching the rendering pipeline from OpenGL to **Metal** (`BXMetalRenderingView`, backed by `MTKView`)
- Adding the required **JIT entitlements** (`com.apple.security.cs.allow-jit`, `unsigned-executable-memory`, `disable-library-validation`) so DOSBox's dynamic recompiler works on ARM
- Fixing a Metal device initialization crash (`MTLCreateSystemDefaultDevice()` fallback in `BXMetalRenderingView`)

### DOSBox-Staging Engine with Critical Crash Fixes

This fork uses DOSBox-Staging as its emulation core and resolves several crashes and hangs that prevented it from working:

- **Black screen (root cause)**: Restored missing `ReelMagic_RENDER_DrawLine()` calls in `vga_draw.cpp`. DOSBox-Staging uses ReelMagic indirection for VGA output, but those calls had been stripped out, leaving the framebuffer empty.
- **Shell input freeze**: `DOS_Shell::ReadCommand()` in `shell_misc.cpp` was missing the `DOS_ReadFile()` call entirely (the original code was `#if 0`'d out and never replaced). Without it, the input loop spun on a zero byte, flooding the VGA console and locking up the shell.
- **OPUS decoder crash**: Removed OPUS from the SDL_sound decoder list since `opus.cpp` is not compiled in this build.
- **Heap corruption on exit**: Removed `capture = {};` reset in `capture.cpp` that was triggering a double-free during `atexit` cleanup.
- **Null function pointer crash**: Added null-checks for init function pointers in `setup.cpp`.

### Programs / Launch Panel Fixes

The Programs (hamburger) menu, which lets users launch executables from the gamebox, had several interacting bugs that prevented it from working:

- **Launch panel items permanently disabled**: Completion callbacks (`boxer_shellDidExecuteFileAtDOSPath`, `boxer_shellDidEndBatchFile`) were never called by DOSBox-Staging's shell code, so `canOpenURLs` was never set back to YES after the first program ran. Added the missing callbacks in `shell_misc.cpp` and `shell.cpp`.
- **Mouse click tracking in launch panel**: The tracking loop in `BXLauncherRegularItemView` only matched `LeftMouseUp` events, missing `LeftMouseDragged`, so clicks were silently swallowed.
- **`.bat` files not recognized**: macOS reports `.bat` files as `com.microsoft.bat` but Boxer only checked `com.microsoft.batch-file`. Added the modern UTI to `BXFileTypes`.
- **Commands queued but never executed**: The Boxer command-injection hooks in `ReadCommand()` were entirely `#if 0`'d out. Re-enabled `boxer_shellWillReadCommandInputFromHandle` / `boxer_shellDidReadCommandInputFromHandle` around the input loop and added `boxer_executeNextPendingCommandForShell` in the main shell loop so queued commands actually run.
- **`.bat` file selection in inspector**: The gamebox inspector's program picker also failed to recognize `.bat` files due to the same UTI mismatch.

### Window and Session Stability

- **Ghost window on close**: `BXDOSWindowController` was not properly cleaning up its rendering views during `windowWillClose:`, leaving a detached window on screen.
- **Crash on document close**: Session teardown order fixed to prevent accessing deallocated emulator state.
- **`BLASTER` environment variable**: The `BLASTER` env var autoexec line was being generated with incorrect syntax for DOSBox-Staging, causing Sound Blaster detection failures in some games.

### Shader-Based Rendering Styles (via OpenEmu Shaders)

The View menu now exposes **all 19 rendering styles** from the [OpenEmu shader library](https://github.com/OpenEmu/OpenEmu-SDK), including CRT scanline filters, pixel-perfect upscaling, and smoothing shaders. The previously hardcoded three styles (Normal, CRT, Smooth) are now backed by real `.slangp` Slang shaders processed by an `OEFilterChain` pipeline.

### Audio Effects Controls

A new **Audio Effects** submenu has been added to the Sound menu, exposing the DOSBox-Staging audio effect parameters directly from the menu bar without needing to edit config files.

### Rendering Stability Fixes

Several rendering edge cases were fixed that caused grey or black windows:

- `CAMetalLayer` background color set to black (was transparent, causing grey bleed-through)
- Rendering state correctly reset when switching between the emulator and settings panels
- Intermittent black screen on document open (race condition in Metal layer setup)
- `BXDOSWindowBackgroundView` now handles nil `currentContext` gracefully to avoid crashes when the window is being torn down

---

## Building

#### Requirements

- macOS 12 or higher
- Xcode 14 or higher
- An Apple Developer account (for signing/notarization)

After cloning, initialize submodules:

```bash
git submodule update --init --recursive
```

#### Quick build (no signing)

```bash
xcodebuild -workspace Boxer.xcworkspace -scheme "Boxer CI" \
  -configuration Release ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  -derivedDataPath build
```

Output: `build/Build/Products/Release/Boxer.app`

#### Build Targets

- **Boxer**: the main emulator. This is what you want.
- **Boxer Standalone**: a stripped-down version that wraps a single gamebox into a self-contained app.
- **Boxer Bundler**: a GUI tool for packaging gameboxes into Standalone apps.

#### Useful Defaults

Disable multithreaded emulation (can help with some compatibility issues):

```bash
defaults write net.washboardabs.boxer useMultithreadedEmulation -bool NO
```

---

## License

Licensed under [GPLv2](./LICENSE). Originally developed by Alun Bestor and contributors.
