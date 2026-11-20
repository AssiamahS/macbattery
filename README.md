# macbattery

iPhone, Apple Watch and MacBook battery on the iPhone Home Screen, styled like Apple's Batteries widget
(medium = four rings in a row; small and Lock Screen = Mac only).

| Slot | Where the number comes from |
|------|-----------------------------|
| iPhone | Read on the phone (`UIDevice`) each time the widget refreshes. Never leaves the device. |
| Watch | iOS has no API for the paired watch, so the watch app (`Watch/`) posts its own level to the Worker. |
| Mac | launchd reporter posts `pmset` output to the Worker every 2 minutes. |

```
Mac (launchd, every 2 min)  --POST /battery-->  Cloudflare Worker + KV  <--GET /battery--  iPhone widget (every ~15 min)
```

## Pieces

| Path | What |
|------|------|
| `reporter/macbattery-report.sh` | Parses `pmset -g batt`, POSTs JSON with the `x-battery-secret` header. `--dry-run` prints the payload. |
| `reporter/com.sly.macbattery.plist` + `install.sh` | launchd agent, `StartInterval` 120 s, logs to `~/Library/Logs/macbattery.log`. |
| `worker/` | Worker `macbattery` (KV binding `BATTERY`). `GET /batteries` returns every device, `GET /battery[/mac\|watch\|iphone]` one. Public reads, `POST` needs the secret. |
| `App/`, `Widget/`, `Shared/`, `project.yml` | SwiftUI host app + WidgetKit extension (systemMedium, systemSmall, accessoryCircular). XcodeGen is the source of truth. |
| `Watch/` | watchOS companion that reports the watch's level (on open and on background refresh, roughly every 15+ min as watchOS allows). |

Endpoint: `https://macbattery.sylvesterassiamahpm.workers.dev/battery`

Live page (no app needed): `https://macbattery.sylvesterassiamahpm.workers.dev/` draws the same ring and
re-polls every 30 s. In Safari: Share, Add to Home Screen. It is an icon that opens the ring, not a real widget.

## Mac setup

```sh
mkdir -p ~/.config/macbattery && chmod 700 ~/.config/macbattery
openssl rand -hex 32 > ~/.config/macbattery/secret && chmod 600 ~/.config/macbattery/secret
(cd worker && wrangler secret put REPORT_SECRET < ~/.config/macbattery/secret && wrangler deploy)
reporter/install.sh
curl -s https://macbattery.sylvesterassiamahpm.workers.dev/battery
```

Uninstall: `launchctl bootout gui/$(id -u)/com.sly.macbattery && rm ~/Library/LaunchAgents/com.sly.macbattery.plist`

Notes: reports stop while the Mac sleeps (launchd does not wake it). The widget greys the ring once the last
report is older than 10 minutes. 720 KV writes/day stays under the free tier's 1,000/day.

## iPhone

CI (`.github/workflows/ci.yml`, `macos-26`) only does unsigned device + simulator compiles. To install:

1. Sideload path (same as the other apps): add an ad hoc export job cribbed from `AssiamahS/carplay`'s
   `adhoc` job (unsigned archive, then `xcodebuild -exportArchive` with the ASC key for cloud signing),
   publish the IPA + `manifest.plist` to GitHub Pages and open the `itms-services://` link on the iPhone.
   Requires both bundle ids (`com.sylvester.macbattery`, `com.sylvester.macbattery.widget`) to exist under
   team QGMAWHX827 and the iPhone UDID to be in the ad hoc profile.
2. Or, on any Mac with Xcode 26: `xcodegen generate`, open `MacBattery.xcodeproj`, pick the iPhone, Run.

Then long-press the Home Screen, Edit, Add Widget, search "Mac Battery", pick the wide one.

### Watch slot

The ad hoc build leaves the watch app out until the Watch's UDID is registered under the team, because an
ad hoc profile without it fails the whole export. Once it is registered:
`gh variable set WATCH_REGISTERED --body 1`, re-run CI, reinstall, then open Mac Battery on the watch once.
The watch app's write key comes from the `REPORT_SECRET` repo secret at build time (same value as
`~/.config/macbattery/secret`).
