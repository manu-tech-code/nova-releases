# Nova

Nova is a voice-first assistant for the Mac: it hears you, decides on the Mac in milliseconds, uses your apps, your
browser and your services, and pairs with your coding agents. This repository holds its **releases** - the app and
the feed it updates from. Its source is kept elsewhere.

## Install

On an Apple silicon Mac with macOS 14 or later:

```bash
curl -fsSL https://raw.githubusercontent.com/manu-tech-code/nova-releases/HEAD/install.sh | bash
```

The script downloads the latest `.dmg` from these releases, checks that the app is signed by Nova's developer, puts
Nova.app in Applications and opens it. You can also download the `.dmg` from
[Releases](https://github.com/manu-tech-code/nova-releases/releases) yourself.

## Updates

Nova updates itself: once a day it reads `appcast.xml` from the latest release, and **Check for Updates…** in its menu
bar shows what's new with **Update Now**. Every download's EdDSA signature is checked before it's installed. Your
settings and data stay in `~/.nova`.

The app is signed with a development certificate, so it's meant for its developer's own Macs.
