<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.tailnet-switch</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$HOME/.config/.system/setup/tailnet-switch-worker.sh</string>
    </array>

    <key>EnvironmentVariables</key>
    <dict>
        <key>DOTFILES</key>
        <string>$HOME/.config</string>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>

    <key>RunAtLoad</key>
    <true/>

    <key>StandardOutPath</key>
    <string>$HOME/.config/logs/tailnet-switch.log</string>

    <key>StandardErrorPath</key>
    <string>$HOME/.config/logs/tailnet-switch-error.log</string>
</dict>
</plist>
