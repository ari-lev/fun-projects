#!/bin/bash

currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

# Check that user is logged in
if [[ "$currentUser" != "root" ]]; then

if [[ $currentUser == *@humaninterest.com ]]; then
    # Remove the "@humaninterest.com"
    currentUser=${currentUser%%@humaninterest.com}
    /bin/echo "Removed @humaninterest.com from $currentUser. Continuing..."
else
    /bin/echo "$currentUser is logged in. Continuing..."
fi

 if [[ -f "$currentUser/Library/HumanInterest/wallpaper.set" ]]; then
  echo "Wallpaper flag already set."
  exit 0

  elif
  [[ -d "$currentUser/Library/HumanInterest" ]]; then
  touch "$currentUser/Library/HumanInterest/wallpaper.set"
  echo "Wallpaper flag set."
  exit 0

  else
  mkdir -p "$currentUser/Library/HumanInterest"
  touch "$currentUser/Library/HumanInterest/wallpaper.set"
  echo "HumanInterest folder created and wallpaper flag set."
  exit 0

  fi

else

echo "User is not logged in. Cannot set wallpaper flag now."
exit 1
fi