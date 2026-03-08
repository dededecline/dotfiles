<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.display-monitor</string>

    <key>ProgramArguments</key>
    <array>
        <string>$HOME/.config/.system/setup/monitor-watcher.sh</string>
    </array>

    <key>StartInterval</key>
    <integer>3</integer>

    <key>RunAtLoad</key>
    <true/>

    <key>StandardOutPath</key>
    <string>$HOME/.config/logs/display-monitor.log</string>

    <key>StandardErrorPath</key>
    <string>$HOME/.config/logs/display-monitor-error.log</string>
</dict>
</plist>
