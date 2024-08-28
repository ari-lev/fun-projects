#!/bin/zsh

##############################################################
# Information
##############################################################

# This script alerts the user to enable screen sharing for the listed apps.

# Written by Ari Lev. https://github.com/ari-lev/macAdmin
# Adapted from the script written by Brian Van Peski at https://github.com/bvanpeski/ScreenNudge

# This script is intended to run from Kandji Self Service.
# If you want this script to run automatically during Liftoff, add a second library item to set a launchdaemon that calls
# this library item when Liftoff is closed and all apps listed below are installed. 

##############################################################
# Requirements
##############################################################

# macOS 14 or higher
# Kandji MDM
# Pre-approval for standard user to allow screen recording via PPPC

##############################################################
# User Defined Variables
##############################################################

# List the target app(s) here in format BUNDLEIDENTIFIER:NAME
apps_to_check=(
  "com.tinyspeck.slackmacgap:Slack"
  "com.teamviewer.TeamViewerHost:TeamViewer Host"
  "us.zoom.xos:Zoom"
)

attempts=3 # The number of times to display the dialog to the user
delay=60 # The amount of time to wait to display the dialog again after first dismissal
timeout=600 # The amount of time to wait to exit the script if dialog is ignored by the user

##############################################################
# Static Variables 
##############################################################

currentUser=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')
uid=$(id -u "$currentUser")
newline=$'\n'
dialog_count=0
start_time=$(date +%s)
settings_opened=0

##############################################################
# Functions
##############################################################

runAsUser() {
  if [ "$currentUser" != "loginwindow" ]; then
    launchctl asuser "$uid" "$@"
  else
    echo "No user logged in"
    exit 1
  fi
}

validate_bundle_id() {
  local bundle_id="$1"
  if [[ $bundle_id =~ ^[a-zA-Z0-9][-a-zA-Z0-9.]*\.[-a-zA-Z0-9.]+$ ]]; then
    return 0  # Valid bundle identifier
  else
    echo "Invalid bundle identifier: $bundle_id"
    return 1  # Invalid bundle identifier
  fi
}

check_app_installed() {
  local bundle_id="$1"
  local name="$2"
  if ! validate_bundle_id "$bundle_id"; then
    echo "Skipping $name ($bundle_id) due to invalid bundle identifier."
    return 1
  fi
  local app_path
  app_path=$(mdfind "kMDItemCFBundleIdentifier == '$bundle_id'" | head -n 1)

  if [ -z "$app_path" ]; then
    echo "$name ($bundle_id) is not installed."
  fi
}

check_app_pppc() {
  for app in "${apps_to_check[@]}"; do
    IFS=':' read -r bundleID appName <<< "$app"
    authorization=$(/usr/libexec/PlistBuddy -c "print '${bundleID}:kTCCServiceScreenCapture:Authorization'" "/Library/Application Support/com.apple.TCC/MDMOverrides.plist" 2>/dev/null)
    if [ "$authorization" != "AllowStandardUserToSetSystemService" ]; then
      echo "PPPC is not set to allow standard users to approve screen recording for $bundleID."
      exit 1
    fi
  done
  echo "PPPC is set to allow standard users to approve screen recording for all apps."
}

approvalCheck() {
  not_enabled=()
  scApproval=0

  for app in "${apps_to_check[@]}"; do
    IFS=':' read -r bundleID appName <<< "$app"
    if [ -z "$(sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "SELECT client FROM access WHERE service = 'kTCCServiceScreenCapture' AND auth_value = 2" 2>/dev/null | grep -o "$bundleID")" ]; then
      ((scApproval++))
      not_enabled+=("$appName")
    fi
  done

  app_list=$(printf '%s\n' "${not_enabled[@]}")
}

dialogDisplay() {
  local title="$1"
  local message="$2"
  local icon="$3"
  local help="https://captain401.atlassian.net/l/cp/JJ4revNe"

  # Check if the app icon exists
  if [ -e "$icon" ]; then
    iconCMD=(--icon "$icon")
    echo "Using custom icon: $icon"
  else
    # If the icon file doesn't exist, fall back to the default icon
    iconCMD=()
    echo "Custom icon not found, using default icon"
  fi

  echo "Dialog Displayed: $dialog_count time(s)"
  
  /usr/local/bin/kandji display-alert --title "$title" --message "$message" --help-url "$help" "${iconCMD[@]}"
}

dialogDisplayInitial() {
  local title="Screen Sharing Approval"
  local message="Please approve screen sharing for:$newline $newline $app_list"
  local icon="/Users/$currentUser/Library/HumanInterest/beacon.png"
  dialogDisplay "$title" "$message" "$icon"
}

dialogDisplaySecondary() {
  local title="Screen Sharing Approval"
  local message="You still need to approve screen sharing for:$newline $newline $app_list"
  local icon="/Users/$currentUser/Library/HumanInterest/beacon.png"
  dialogDisplay "$title" "$message" "$icon"
}

dialogDisplayEndSuccess() {
  local title="Congratulations"
  local message="Thanks for setting up screen sharing.$newline $newline You're all set!"
  local icon="/tmp/screenSharing/success.png"
  dialogDisplay "$title" "$message" "$icon"
}

dialogDisplayEndFailure() {
  local title="Warning"
  local message="You'll need to enable screen sharing for the apps listed below later:$newline $newline $app_list"
  local icon="/tmp/screenSharing/warning.png"
  dialogDisplay "$title" "$message" "$icon"
}

settingsOpen() {
  if pgrep -x "System Settings" > /dev/null; then
    echo "Settings already open"
  else
    runAsUser open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    settings_opened=1
    echo "Opened Settings."
  fi
}

settingsClose() {
  if [ "$settings_opened" -eq 1 ]; then
    pkill -x "System Settings"
    settings_opened=0
    echo "Closing settings"
  fi
}

dialogClose() {
    pkill -x "Kandji Menu"
    echo "Closing Kandji Alert Window"
}

##############################################################
# Logic
##############################################################

sleep 5

# Run initial checks
for app in "${apps_to_check[@]}"; do
  IFS=':' read -r bundleID appName <<< "$app"
  check_app_installed "$bundleID" "$appName"
done

check_app_pppc
approvalCheck

# Start dialog displays
if [ ${#not_enabled[@]} -eq 0 ]; then
  sleep 1
  echo "Screen sharing already allowed for all apps."
  exit 0
else
  settingsOpen
  dialogDisplayInitial
  ((dialog_count++))
  start=$(date +%s)
  timeout=30
  while [ $(($(date +%s) - $start)) -lt $timeout ]; do
    sleep 1
    approvalCheck
    if [ ${#not_enabled[@]} -eq 0 ]; then
      dialogDisplayEndSuccess
      settingsClose
      exit 0
    fi
  done
fi

# Loop every second
while sleep 1; do
  approvalCheck
  # Check if not_enabled is empty
  if [ ${#not_enabled[@]} -eq 0 ]; then
    dialogDisplayEndSuccess
    settingsClose
    exit 0
  fi
  
  # Every x seconds, display secondary dialog
  if (( $(date +%s) - $start_time >= $delay )); then
    dialogDisplaySecondary
    settingsOpen
    ((dialog_count++))
    start_time=$(date +%s)
  fi
  
  # Exit the script with failure if not_enabled is not empty after x attempts or 10 minutes
  if [ ${#not_enabled[@]} -ne 0 ] && ((dialog_count >= $attempts || $(date +%s) - $start_time >= $timeout)); then
    approvalCheck
    if [[ ${#not_enabled[@]} -ne 0 ]]; then
      dialogDisplayEndFailure
      dialogClose
      settingsClose
      exit 0
    else
      dialogDisplayEndSuccess
      settingsClose
      exit 0
    fi
  fi
done
