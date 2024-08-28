#!/bin/sh

##############################################################
# Information
##############################################################

# Written by Ari Lev. https://github.com/ari-lev/macAdmin

##############################################################
# LOGIC
##############################################################

now=$(date | awk '{print $2, $3}')
file=".AppleSetupDone"
path="/private/var/db"
enrollDate=$( ls -l /private/var/db | grep ".AppleSetupDone" | awk '{print $6,$7}' 2>/dev/null)

echo "Enrollment Date: $enrollDate"
if [[ "$now" == "$enrollDate" ]]; then
    echo "New device, running the rest of screen recording notification process."
else
    echo "Existing device, exiting without continuing."
    exit 0
fi

# Set variables
daemonName="io.kandji.installAfterLiftoffScreenSharing"
scriptPath="/tmp/installAfterLiftoffScreenSharing.sh"

# Content for Script
script=$(
/bin/cat <<"EOT"
#!/bin/sh

# Wait for TeamViewer to be installed and running and then close the notification window
while [[ -z $pid ]]; do
  pid=$(ps -Ac -o pid,comm | awk '/^ *[0-9]+ TeamViewer\Host$/ {print $1}')
  sleep 1
done
sleep 1
echo "Quitting TeamViewer"
osascript -e 'quit app "TeamViewerHost"'

# Wait for Slack.app and zoom.us.app to be installed
while [[ ! -d "/Applications/Slack.app" ]] || [[ ! -d "/Applications/zoom.us.app" ]]; do
  sleep 1
done

# Wait for Liftoff to close
until ! pgrep "Liftoff" >/dev/null
  do
    sleep 1
  done

# Execute Library Item
/usr/local/bin/kandji library --item "Screen Sharing Notification" -F

# Clean Up After Yourself
rm "/tmp/screenSharing_icons/teamviewerClose.workflow"
rm "/tmp/io.kandji.installAfterLiftoffScreenSharing.plist"
rm "/tmp/installAfterLiftoffScreenSharing.sh"

# Unload LaunchDaemon
/bin/launchctl unload "/tmp/io.kandji.installAfterLiftoffScreenSharing.plist"
EOT
)

# Content for LaunchDaemon
launchDaemon=$(
/bin/cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$daemonName</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$scriptPath</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
)

# Create Script
/bin/echo "Creating Script at $scriptPath..."
/bin/echo "$script" >"$scriptPath"

# Create LaunchDaemon
/bin/echo "Creating LaunchDaemon at /tmp/$daemonName.plist..."
/bin/echo "$launchDaemon" >/tmp/$daemonName.plist

# Set Correct Permissions on LaunchDaemon
/bin/echo "Setting Permissions on LaunchDaemon..."
/usr/sbin/chown root:wheel /tmp/$daemonName.plist
/bin/chmod 644 /tmp/$daemonName.plist
/bin/chmod +x "$scriptPath"

# Load LaunchDaemon
/bin/echo "Loading LaunchDaemon..."
/bin/launchctl load "/tmp/$daemonName.plist"

exit 0