#!/bin/bash

# Generate a random number between 100000 and 999999
random_number=$(( 100000 + $RANDOM % 900000 ))

# Generate a random number between 100 and 999
daemon_extension=$(( 100 + $RANDOM % 900 ))

# Output the number in Ninja
echo "Generated number: $random_number"

# Create Script
scriptPath="/tmp/employee_verification.sh"

# Content for Script
script=$(
/bin/cat <<EOT
#!/bin/sh

sleep 15

/usr/local/bin/kandji display-alert --title "Reset Code" --message "$random_number"

# Delete script file
rm -f "/tmp/employee_verification.sh"

# Unload and delete LaunchDaemon
rm -f "/tmp/com.humaninterest.employee_verification$daemon_extension.plist"
EOT
)

# Create Script
/bin/echo "$script" >"$scriptPath"

# Set Correct Permissions on script
/bin/chmod +x "$scriptPath"

# Create Launch Daemon
daemonName="com.humaninterest.employee_verification$daemon_extension"

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

# Create LaunchDaemon
/bin/echo "$launchDaemon" >/tmp/$daemonName.plist

# Set Correct Permissions on LaunchDaemon
#/usr/sbin/chown root:wheel /tmp/$daemonName.plist
#/bin/chmod 644 /tmp/$daemonName.plist

# Load LaunchDaemon
sudo launchctl bootstrap system "/tmp/$daemonName.plist"