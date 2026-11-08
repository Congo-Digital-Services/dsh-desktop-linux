# dsh-desktop-linux

Community Linux build of the **DSH Desktop** app, built on [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness).

> **Not affiliated with DeepSeek.** DeepSeek publishes DSH Desktop for macOS and Windows only. This project builds the same
> open-source Electron app on Linux from the official sources. "DeepSeek" and "DeepSeek Harness" are trademarks of DeepSeek.
> This repository ships no DeepSeek binaries or brand assets. The build script downloads the official sources, and the
> app icon comes from that checkout.

## What you get

- **The desktop app on Linux**, built from an upstream release tag with a few small patches:
  - `0001-allow-linux-x64-target.patch` lets the launcher accept the `linux-x64` target. Upstream already has a Linux
    runtime for this target, but its launcher refuses it.
  - `0002-linux-frameless-caption-bar.patch` replaces the system title bar with a slim caption row and gives the window
    a flat layout:
    - the sidebar toggle on the left, and minimize, maximize and close controls on the right;
    - you drag the window from the caption row;
    - a flat caption row, a sidebar slightly lighter than the content, and one divider from top to bottom;
    - no brand row at the top of the sidebar;
    - no native menu bar (press <kbd>Alt</kbd> to show it);
    - a window icon.
  - `0004-linux-notification-opens-session.patch` lets a notification open its session. The app listens on a private
    socket, `$XDG_RUNTIME_DIR/dsh-desktop-linux/open-session.sock`, readable only by you.
- **A menu entry** called **DSH Desktop**, with its own icon.
- **Desktop notifications** (optional) through `notify-send`:
  - when a task finishes, fails or gets blocked;
  - when the agent waits for your approval.

  In DSH Desktop, clicking a notification (or its **Open** button) brings the window forward on that session.

  Subagent tasks don't trigger notifications. The plugin also works with the `dsh` web UI and the CLI. Messages are in
  English, or in French when your locale is French.
- **Shared data with the `dsh` CLI** (`~/.dsh`): sessions, settings and skills.

## Download

Get the latest `dsh-desktop-…-linux-x86_64.AppImage` from the
[Releases page](https://github.com/Congo-Digital-Services/dsh-desktop-linux/releases), then:

```bash
chmod +x dsh-desktop-*-linux-x86_64.AppImage
./dsh-desktop-*-linux-x86_64.AppImage
```

On Ubuntu 22.04 and later, AppImages need `libfuse2` (`sudo apt install libfuse2`; on 24.04 the package is
`libfuse2t64`). The AppImage is self-contained: it doesn't need Node.js, the build tools below or `install.sh`.
It doesn't include the notification plugin either, so install that from a source build if you want it.

To build it yourself instead, read on.

## Requirements

- Linux x86_64. Tested on Debian 12 under GNOME (Wayland).
- Node.js **22.19+**; [nvm](https://github.com/nvm-sh/nvm) works.
- `git` and a C compiler (`build-essential`). The native addon is plain C, so you don't need Rust.
- About 3 GB of free disk space for the sources and the build.
- Optional: `notify-send` (`libnotify-bin` on Debian/Ubuntu), for notifications.

## Install

```bash
git clone https://github.com/Congo-Digital-Services/dsh-desktop-linux.git
cd dsh-desktop-linux
./build.sh      # clones the upstream tag, applies patches, installs deps, builds (10–20 min the first time)
./install.sh    # launcher, menu entry, icon, notification plugin
```

Then open **DSH Desktop** from your application menu, or run `dsh-desktop` in a terminal. The first start takes a little
longer while the app prepares its bundled runtime.

| Path | Content |
|---|---|
| `~/.local/share/dsh-desktop-linux/src` | upstream sources and build (`DSH_DESKTOP_SRC` overrides it) |
| `~/.local/bin/dsh-desktop` | launcher |
| `~/.local/state/dsh-desktop-linux/desktop.log` | app log |

## Model access

Sign in or enter an API key in the app, as on the official desktop app. You can also set environment variables in
`~/.config/dsh-desktop-linux/env`:

```bash
DEEPSEEK_API_KEY=sk-...
# Optional: route requests through your own Anthropic-compatible relay
# DEEPSEEK_BASE_URL=https://relay.example.com/anthropic
```

Keep this file private: `chmod 600 ~/.config/dsh-desktop-linux/env`.

## Update

```bash
git pull                                # newer patches / pinned tag (see UPSTREAM_TAG)
./build.sh && ./install.sh
DSH_TAG=dsh-v0.2.2-rc.1 ./build.sh      # or try another upstream tag (patches may need an update)
```

## Uninstall

```bash
./install.sh --uninstall                # launcher, menu entry, icon, notification plugin
rm -rf ~/.local/share/dsh-desktop-linux # sources and build
```

Your sessions and settings in `~/.dsh` are kept.

## Known limitations

- **It is a development-mode build.** The app shows "DSH Local Build" and has no auto-update.
- **Debug ports are open on localhost**: 9229, 9222 and 9230. Upstream development mode opens them, and they are bound
  to `127.0.0.1` only.
- **There is no `.deb` package yet**, only the AppImage. It has no auto-update: download new releases by hand.
- **Only x86_64 has been tested.**

## License

[MIT](LICENSE). DeepSeek Harness itself is MIT-licensed by DeepSeek; see its own `LICENSE` and `THIRD_PARTY_NOTICES.md`
in the downloaded sources.
