# TG WS Proxy - iOS

[Русский](./README-ru.md) | English

[Flowseal TG WS Proxy](https://github.com/Flowseal/tg-ws-proxy) port to iOS

The iOS app (iOS 14+, SwiftUI) deploys a localhost MTProto proxy that forwards messenger traffic via WebSocket to Telegram servers.

## How it works

The app doesn't use a VPN with Packet Tunnel Provider to operate the MTProto proxy — it runs within the app's context

To prevent iOS from shutting down/closing the app when minimizing it, implemented infinite silent audio playback while the proxy is running. You can still listen to regular tracks, since the audio session is initialized with the *mixWithOthers* parameter

**P.S.** The background geo-refresh method was discarded due to increased battery consumption. Other features from the Background Modes capability weren't well suited to the task

The proxy itself operates on the same principle as in the original repository

**Note**: This solution will prevent the app from passing the release review in the App Store, but it may well pass public testing in TestFlight

### Automation

Since background mode is required for the app to run in the background, power consumption will still be higher. Therefore, to minimize power consumption, shortcuts have been added to the app:

- Launch Telegram WS Proxy from the foreground (With app launch)
- Launch Telegram WS Proxy from the background (Without app launch)
- Stop Telegram WS Proxy

Using these shortcuts, you can set up automations to launch the proxy when Telegram opens and stop it when the app is minimized or closed.

**Example of the automation algorithm for opening the Telegram app in Quick Commands**

```
1. Launch Telegram WS Proxy in the background
2. Get the operation status (true/false)
- If the proxy has started (true), terminate the shortcut execution
- If the proxy has not started (false - this sometimes happens for AudioPlaybackIntents, as iOS requires the application to be running), continue executing the shortcut
3. Launch Telegram WS Proxy in the foreground. If successful, the TgWsProxy application will be opened
4. Get the operation status (true/false)
- If the proxy has started (true), switch back to Telegram app
```

**The automation algorithm for minimizing/closing the Telegram application in quick settings** is primitive: it is enough to use the basic command from the application *Stop Telegram WS Proxy*

## Usage

The default settings allow you to start the proxy even on first launch without setup. The server will listen on *127.0.0.1:1443*

The MTProto secret is randomly generated the first time

Yo may change proxy settings through the app preferences

**Note**: The secrets in the server settings and for the client connection are different (the additional first byte is dd). This is normal. The first byte is an optional setting for MTProto proxy operation:

- **No first byte** - operating in plain mode
- **dd** indicates operation with packet obfuscation (split)
- **ee** indicates operation in mode disguised as regular HTTPS. **This mode is not supported by the current implementation.**

## Build

There are several app build options:

1. Build via a free Apple Developer account - ideal for personal devices. Apple signs the app for 7 days, after which it must be rebuilt and re-signed.
2. Distribute via TestFlight - requires a Mac and an account with active developer subscription. This is the most optimal method, as anyone with a public testing link can install the app, and the uploaded build has a 90-day lifespan.
3. Build an unsigned app (Jailbreak or Sideload)
```
chmod +x xcodebuild_unsigned.sh
./xcodebuild_unsigned.sh
```
