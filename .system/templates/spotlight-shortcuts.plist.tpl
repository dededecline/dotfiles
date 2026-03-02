<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.spotlight-shortcuts</string>

    <key>ProgramArguments</key>
    <array>
        <string>/Users/{{ op://Private/git-identity/name }}/.config/.system/setup/disable-spotlight-shortcuts.sh</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/Users/{{ op://Private/git-identity/name }}/.config/logs/spotlight-shortcuts.log</string>

    <key>StandardErrorPath</key>
    <string>/Users/{{ op://Private/git-identity/name }}/.config/logs/spotlight-shortcuts-error.log</string>
</dict>
</plist>
