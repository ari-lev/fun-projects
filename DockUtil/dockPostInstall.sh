#!/bin/bash

currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

# Define the system files to check
system_files=(
  "/var/db/.AppleSetupDone"
  "/var/db/.AppleSetupDone.turbo"
)

# Get the current date in YYYY-MM-DD format
current_date=$(date "+%Y-%m-%d")

# Flag to track if setup was done today
setup_today=false

# Loop through the system files
for file in "${system_files[@]}"; do
  if [[ -f "$file" ]]; then
    # Get the creation date of the file
    file_date=$(stat -f "%Sm" -t "%Y-%m-%d" "$file")

    if [[ "$file_date" == "$current_date" ]]; then
      setup_today=true
      break
    fi
  fi
done

# Print the results
if $setup_today; then
  echo "Newly enrolled device, setting up Dock."
else
  echo "Pre-existing machine, skipping Dock set up."
  exit 0
fi

# Define LaunchDaemon variables
launchdaemon_identifier="com.COMPANY.dockSet"
launchdaemon_filepath="/Library/LaunchDaemons/${launchdaemon_identifier}.plist"
launchdaemon_program_filepath="/tmp/dockProvisioning.sh"
launchdaemon_watchpath="/Applications/zoom.us.app"

# Create LaunchDaemon that launches script after last Auto App is installed
cat <<EOF > "${launchdaemon_filepath}"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>Label</key>
        <string>${launchdaemon_identifier}</string>
        <key>Program</key>
        <string>${launchdaemon_program_filepath}</string>
        <key>RunAtLoad</key>
        <false/>
        <key>WatchPaths</key>
        <array>
            <string>${launchdaemon_watchpath}</string>
        </array>
    </dict>
</plist>
EOF

echo "LaunchDaemon created"

# Create dockProvisioning.sh file

touch "/tmp/dockProvisioning.sh"
chmod u+x "/tmp/dockProvisioning.sh"

cat <<"EOT" > "/tmp/dockProvisioning.sh"
#!/bin/bash

# Wait for Slack.app and Twingate.app to be installed
while [[ ! -d "/Applications/Slack.app" ]] || [[ ! -d "/Applications/Twingate.app" ]]; do
  sleep 1
done

# Wait for Liftoff to close
until ! pgrep "Liftoff" >/dev/null
  do
    sleep 1
  done

export PATH=/usr/bin:/bin:/usr/sbin:/sbin

# Full path to Applications to add to the Dock every time, even if they are not present on the system yet.
# Items will be added in order. None of the additional options of dockutil are used on these items.
alwaysApps=(
"/System/Applications/Launchpad.app"
"/Applications/Google Chrome.app"
"/Applications/Slack.app"
"/Applications/Zoom.us.app"
"/Applications/Kandji Self Service.app"
"/Applications/Twingate.app"
)

# Path to folders and files for the right side of the Dock ("others"); ~/ syntax may be used.
# This list pairs with optionsOthers to specify how you would like these items to be displayed
# (i.e., the first folder listed in alwaysOthers will be run with the options specified on the
# first line of optionsOthers).
alwaysOthers=(
"~/Downloads"
)

# Display options for items in alwaysOthers in order.
# You should have one entry for each entry in alwaysOthers.
# For files, use a pair of quotes (null string) since there are no display options.
optionsOthers=(
"--view fan --display stack --sort dateadded"
)

# Path to items to add to the Dock (apps, folders, files) only if they are present.
# This list pairs with optionsOptional to specify how you would like these items to be displayed.
optionalItems=(
"/Applications/Privileges.app"
"/System/Applications/System Preferences.app"
"/System/Applications/System Settings.app"
)

# Display options for items in optionalItems in order.
# You should have one entry for each entry in optionalItems.
# If you do not want to specify options for an item, use a pair of quotes (null string).
#
# You must escape or quote (with a different type of quote mark) any argument that has a
# space in it (e.g., "--after 'Microsoft Word'" or "--after Microsoft\ Word").
# Using the app identifier instead of the app name is not supported by this script.
#
# Any relative options (e.g., --before, --after) will be applied to the Dock in the State
# it was in after the "always" apps and others are applied
optionsOptional=(
"--after Twingate"
"--position end"
"--position end"
)

###############################################################
# You should not have to edit any of the code after this line #
###############################################################
# COLLECT IMPORTANT USER INFORMATION
# Get the currently logged in user
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )

# Get uid logged in user
uid=$(id -u "${currentUser}")

# Current User home folder - do it this way in case the folder isn't in /Users
userHome=$(dscl . -read /users/${currentUser} NFSHomeDirectory | cut -d " " -f 2)

# Path to plist
plist="${userHome}/Library/Preferences/com.apple.dock.plist"

# Check if dockutil is installed
if [[ -x "/usr/local/bin/dockutil" ]]; then
    dockutil="/usr/local/bin/dockutil"
else
    echo "dockutil not installed in /usr/local/bin, exiting"
    exit 1
fi

# Version dockutil
dockutilVersion=$(${dockutil} --version)
echo "Dockutil version = ${dockutilVersion}"

# Create a clean Dock
"${dockutil}" --remove all --no-restart ${plist}
echo "All items removed from user’s Dock"

sleep 5

# Loop through alwaysApps and add item to the Dock. Log (only) if app is missing.
for app in "${alwaysApps[@]}"; 
do
    "${dockutil}" --add "${app}" --no-restart ${plist};
    if [[ ! -e "${app}" ]]; then
        echo "${app} not installed but Dock item added"
    fi
done

# Need to restart the Dock to allow any relative options to be applied in further commands.
killall -KILL Dock

# Loop through alwaysOthers and add folder/file to the right part of the Dock, even if item is missing.

# Check first to see if there are matching options for each item and log any errors (but do not stop)
itemCount=${#alwaysOthers[@]}
optionsCount=${#optionsOthers[@]}
if [ $itemCount -gt $optionsCount ] ; then
    echo "There are more items for the right side of the Dock than there are matching options; some items will receve default options"
elif [ $itemCount -lt $optionsCount ] ; then
    echo "There are more options than there are items for the right side of the Dock; results may not be as anticipated"
fi

for (( i=0 ; i<itemCount ; i++)); 
do
    eval "${dockutil}" --add \"${alwaysOthers[i]}\" ${optionsOthers[i]} --no-restart ${plist};
    if [[ ! -e "${alwaysOthers[i]}" ]] && [[ "${alwaysOthers[i]:0:1}" != '~' ]] ; then
        echo "${alwaysOthers[i]} not present but Dock item added"
    fi
done

# Loop through optionalItems and check if item is installed. If installed, add to the Dock
# using the options specified in optionsOptional.
itemCount=${#optionalItems[@]}
optionsCount=${#optionsOptional[@]}
if [ $itemCount -gt $optionsCount ] ; then
    echo "There are more optional Dock items than there are matching options; some items will receve default options"
elif [ $itemCount -lt $optionsCount ] ; then
    echo "There are more options than there are optional items for the Dock; results may not be as anticipated"
fi

for (( i=0 ; i<itemCount ; i++)); 
do
    if [[ -e "${optionalItems[i]}" ]]; then
        eval "${dockutil}" --add \"${optionalItems[i]}\" ${optionsOptional[i]} --no-restart ${plist};
    else
        echo "${optionalItems[i]} not present and no Dock item added"
    fi
done

# Turn off "Show Recents" in dock
/bin/launchctl asuser "${uid}" /usr/bin/sudo -u "${currentUser}" /usr/bin/defaults write com.apple.dock "show-recents" -bool "false"
echo "Turned off 'Show Recents'"

# Kill the Dock (again) to use all new settings
killall -KILL Dock
echo "Restarted the Dock"

echo "Finished creating default Dock"

# Clean up launchdaemon and provisioning script
/bin/rm -f \
    "/Library/LaunchDaemons/com.HumanInterest.dockSet.plist" \
    "/tmp/dockProvisioning.sh"
echo "Removed LaunchDaemon and provisioning script"

exit 0

EOT

echo "Provisioning script created"

sleep 5

# Load LaunchDaemon
/bin/launchctl load "${launchdaemon_filepath}"
echo "LaunchDaemon loaded"

exit 0