#!/bin/bash

currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
emailDomain="humaninterest.com"
image="FILENAME.EXTENSION" #Insert name of image including file extension
url="https://S3 FILE PATH" #Full URL path, including file name, to image to download

# Check that user is logged in
if [[ "$currentUser" != "root" ]]; then
/bin/echo "$currentUser is logged in. Continuing..."

if [[ $currentUser == *@"$emailDomain" ]]; then
    # Remove the "@humaninterest.com"
    currentUser=${currentUser%%@"$emailDomain"}

fi

if [ -e  "/Users/$currentUser/Pictures/$image" ] ; then

      echo "Wallpaper already downloaded. Skipping download."

    exit 0

else

curl -s "$url" --output "/Users/$currentUser/Pictures/$image"
echo "Wallpaper downloaded to /$currentUser/Pictures folder"

exit 0

fi
fi