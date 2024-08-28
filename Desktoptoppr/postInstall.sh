#!/bin/bash

# sets the desktop using `desktoppr`

currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
emailDomain="EMAIL DOMAIN" #In format company.com
folder="FOLDER NAME" #Name of the folder where image is located
image="IMAGE NAME" #Name of image including extension

# Check that user is logged in
if [[ "$currentUser" != "root" ]]; then
/bin/echo "$currentUser is logged in. Continuing..."

if [[ $currentUser == *@"$emailDomain" ]]; then
    currentUser=${currentUser%%@"$emailDomain"}
    /bin/echo "Removed @$emailDomain from $currentUser. Continuing..."
else
    /bin/echo "$currentUser is logged in. Continuing..."
fi

if [ -e  "/Users/$currentUser/Library/$folder/wallpaper.set" ] ; then

      echo "Wallpaper already set. Do not set wallpaper."

    exit 0

else

# set the path to the desktop image file here
picturepath="/Users/$currentUser/Pictures/$image"

# verify the image exists
if [[ ! -f "$picturepath" ]]; then
    echo "no file at $picturepath, exiting"
    exit 1
fi

# path to current directory of the script
scriptdir=$(dirname "$0")

# try to locate desktoppr
if [[ -x "$scriptdir/desktoppr" ]]; then
    desktoppr="$scriptdir/desktoppr"
elif [[ -x "/usr/local/bin/desktoppr" ]]; then
    desktoppr="/usr/local/bin/desktoppr"
else
    echo "cannot find desktoppr, exiting"
    exit 1
fi

# get the current user
uid=$(id -u "$currentUser")

if [[ "$currentUser" != "loginwindow" ]]; then
    # set the desktop for the user
    
    if [[ $(sw_vers -buildVersion) > "21" ]]; then
        # behavior with sudo seems to be broken in Montery
        # dropping the sudo will result in a warning that desktoprr seems to be
        # running as root, but it will still work
        launchctl asuser "$uid" "$desktoppr" "$picturepath" &> /dev/null

        if [ -d  "/Users/$currentUser/Library/$folder" ] ; then
        touch "/Users/$currentUser/Library/$folder/wallpaper.set"

        echo "Wallpaper set on Monterey or newer. Flag file set."

        exit 0

        else
        mkdir -p "/Users/$currentUser/Library/$folder"
        touch "/Users/$currentUser/Library/$folder/wallpaper.set"

        echo "Wallpaper set on Monterey or newer. Flag file set."

        exit 0

        fi

    else
        sudo -u "$currentUser" launchctl asuser "$uid" "$desktoppr" "$picturepath"  &> /dev/null

        if [ -d  "/Users/$currentUser/Library/$folder" ] ; then
        touch "/Users/$currentUser/Library/$folder/wallpaper.set"

        echo "Wallpaper set on Big Sur or older. Flag file set."

        exit 0

        else
        mkdir -p "/Users/$currentUser/Library/$folder"
        touch "/Users/$currentUser/Library/$folder/wallpaper.set"

        echo "Wallpaper set on Big Sur or older. Flag file set."

        exit 0

        fi

    fi
else
    echo "no user logged in, no desktop set"
fi
fi
fi

exit 0