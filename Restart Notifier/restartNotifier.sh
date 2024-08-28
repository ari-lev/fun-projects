#!/bin/bash

# Get the current user
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

# Specify the number of days for the enforced restart
forced_restart=14

# Set variables to calculate uptime and days remaining until restart
boottime=$(sysctl -n kern.boottime | awk '{print $4}' | sed 's/,//g')
unixtime=$(date +%s)
uptime_seconds=$((unixtime - boottime))
days=$(($uptime_seconds / 86400))
deadline=$(date -j -v+"$forced_restart"d -f "%s" "$boottime" "+%s")
readable_deadline=$(date -r "$deadline" "+%B %-d at %I:%M %p %Z")

  if [ $days -lt 1 ]; then
  days=0
  fi

remaining_days=$((forced_restart - days))

echo "Uptime: $days"

# Set variables to be displayed in message
title="Restart Warning"
help_url="PATH_TO_URL"
icon="/Users/$currentUser/Library/XXX/beacon.png"
newline=$'\n'
message_days="Your Mac will automatically restart on: $newline $readable_deadline $newline $newline Restart sooner to avoid interruption."

# Message determination logic and output
if [ "$remaining_days" -eq 4 ] || [ "$remaining_days" -eq 3 ] || [ "$remaining_days" -eq 2 ] || [ "$remaining_days" -eq 1 ]; then
  /usr/local/bin/kandji display-alert --title "${title}" --message "${message_days}" --help-url "${help_url}" --icon "${icon}"
  echo "$remaining_days day(s) remaining. Alert displayed."
else
  echo "$remaining_days days remaining. No need to display alert."
fi