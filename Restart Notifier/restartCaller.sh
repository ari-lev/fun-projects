#!/bin/bash

############# Set these variables #############
# Name of the Kandji library item being called
libraryItem="Restart Notifier"
# Define the target notification time
targetTime="16:00"
########### End Set these variables ###########

# Get the current user
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
folder="FOLDER NAME"

# Define script name
scriptName="restartNotifier.sh"
# Set script path
scriptPath="/Users/$currentUser/Library/XXXX"
# Define launchdaemon name
daemonName="com.XXXX.restartCaller"
# Set launchdaemon path
daemonPath="/Library/LaunchDaemons"

# Calculate target hour for launchdaemon
daemonHour=${targetTime:0:2}
# Calculate target minutes for launchdaemon
daemonMinute=${targetTime:3:2}

# Script contents
script=$(
/bin/cat <<EOF
#!/bin/bash

# Library item call
/usr/local/bin/kandji library --item "$libraryItem" -F
EOF
)

# Check that user is logged in
if [[ "$currentUser" != "root" ]]; then
/bin/echo "$currentUser is logged in. Continuing..."

# Content for launchdaemon
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
      <string>$scriptPath/$scriptName</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
      <key>Hour</key>
      <integer>$daemonHour</integer>
      <key>Minute</key>
      <integer>$daemonMinute</integer>
    </dict>
  </dict>
</plist>
EOF
)

# Create folder if it does not exist
if [[ ! -d "/Users/$currentUser/Library/$folder" ]]; then
  mkdir "/Users/$currentUser/Library/$folder"
fi

# Create Script
touch "$scriptPath/$scriptName"
/bin/echo "$script" > "$scriptPath/$scriptName"
/bin/echo "Created $scriptName at $scriptPath/"

# Set correct permissions for script
/bin/chmod +x "$scriptPath/$scriptName"
/bin/echo "Set permissions for $scriptName."

# Create LaunchDaemon
/bin/echo "$launchDaemon" >$daemonPath/$daemonName.plist
/bin/echo "Created $daemonName at $daemonPath."

# Set Correct Permissions on LaunchDaemon
/usr/sbin/chown root:wheel $daemonPath/$daemonName.plist
/bin/chmod 644 $daemonPath/$daemonName.plist
/bin/echo "Set permissions for $daemonName at $daemonPath/"

# Check if Launchdaemon is loaded
if launchctl list | grep -q "$daemonName".plist; then
/bin/echo "$daemonName at $daemonPath already loaded."

else

# Load launchdaemon
/bin/launchctl load $daemonPath/$daemonName.plist
/bin/launchctl stop $daemonName.plist
/bin/launchctl start $daemonName.plist
/bin/echo "Loaded $daemonName at $daemonPath."
fi

else

/bin/echo "User is not logged in."
exit 1

fi