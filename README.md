# macbattery

MacBook battery % on the iPhone Home Screen, styled like Apple's Batteries widget.

```
Mac (launchd, every 2 min)  --POST /battery-->  Cloudflare Worker + KV  <--GET /battery--  iPhone widget (every ~15 min)
```

## Pieces

| Path | What |
|------|------|
| `reporter/macbattery-report.sh` | Parses `pmset -g batt`, POSTs JSON with the `x-battery-secret` header. `--dry-run` prints the payload. |
| `reporter/com.sly.macbattery.plist` + `install.sh` | launchd agent, `StartInterval` 120 s, logs to `~/Library/Logs/macbattery.log`. |
| `worker/` | Worker `macbattery` (KV binding `BATTERY`). `GET /battery` is public and returns the latest report + `ageSeconds`. |
| `App/`, `Widget/`, `Shared/`, `project.yml` | SwiftUI host app + WidgetKit extension (systemSmall, accessoryCircular). XcodeGen is the source of truth. |

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

Then long-press the Home Screen, Edit, Add Widget, search "Mac Battery".
