#!/bin/bash

# Get the current logged in user and store it in the "currentUser" variable
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
emailDomain="EMAIL DOMAIN" #Email domain in format company.com
folder="FOLDER NAME" #folder to place logo file in

# Check that user is logged in
if [[ "$currentUser" != "root" ]]; then
/bin/echo "$currentUser is logged in. Continuing..."

if [[ $currentUser == *@"$emailDomain" ]]; then
    currentUser=${currentUser%%@"$emailDomain"}
    /bin/echo "Removed @$emailDomain from $currentUser. Continuing..."
else
    /bin/echo "$currentUser is logged in. Continuing..."
fi

# Create folder if it does not exist
if [[ ! -d "/Users/$currentUser/Library/$folder" ]]; then
  mkdir "/Users/$currentUser/Library/$folder"
fi

# Move the "beacon.png" file from /tmp to /Users/$currentUser/Library/$folder
mv /tmp/beacon.png /Users/$currentUser/Library/$folder/
/bin/echo "Placed beacon.png into $folder folder."

else

/bin/echo "User is not logged in."
exit 1

fi