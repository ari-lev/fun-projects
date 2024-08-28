#!/bin/zsh

# Written by Ari Lev
# Based on the It's-Log project by Brad Chapman
# https://github.com/bradtchapman/psumac2023

# VARIABLES

# Variables for creating system diagnostic report
CurrentUser=$(ls -la /dev/console | awk '{ print $3 }') # Get the current user
CurrentUser=$(echo "$CurrentUser" | sed 's/\./-/g') # Replace . with - if present in the username
DeviceSerial=$(system_profiler SPHardwareDataType | awk '/Serial Number/ {print $4}') # Get the device serial number
DiagDate=$(date +%Y%m%d_%H%M%S) # Get the current date and time
OutputFile="$tempDir/SysDiag_${CurrentUser}_${DeviceSerial}_${DiagDate}.tar.gz"

# Variables for creating a temporary directory
randomNumber=$(( (RANDOM % 9 + 1) * 1000000000 + RANDOM * 100000 + RANDOM ))
tempDir="/var/tmp/SysDiag_$randomNumber"

# Variables for connecting to AWS
aws_ak="XXXX" # Access Key
aws_sk="XXXX" # Secret Key
destination="XXXX" # Bucket@Region
bucket="$(echo "$destination" | awk 'BEGIN{FS="@"}{print $1}')"
region="$(echo "$destination" | awk 'BEGIN{FS="@"}{print $2}')"
s3_endpoint="https://${bucket}.s3.${region}.amazonaws.com"
resource="/XXXX/$(basename $OutputFile)"
content_type="application/x-compressed-tar"
date_value=$(date -R)
signature_string="PUT\n\n${content_type}\n${date_value}\n/${bucket}${resource}"
signature=$(echo -en "${signature_string}" | openssl sha1 -hmac "${aws_sk}" -binary | base64)

# LOGIC

# Create a temporary directory for the output file
mkdir "$tempDir"

# Generate system diagnostic report
echo "Starting sysdiagnose process. This may take a few minutes..."
/usr/bin/sysdiagnose -b -u -f "$tempDir" -A "$(basename $OutputFile)" > /dev/null 2>&1
echo "sysdiagnose process complete."

# Check sysdiagnose output
echo "Generated file at $tempDir$tempDir"

# Wait for sysdiagnose to complete
wait

# Check if OutputFile exists before attempting to upload
if [ ! -f "$OutputFile" ]; then
    echo "Error: Output file $OutputFile not found."
    exit 1
fi

# Upload to S3 bucket using curl
echo "Starting upload. This may take a few minutes..."
curl -X PUT -T "$OutputFile" \
    -H "Host: ${bucket}.s3.${region}.amazonaws.com" \
    -H "Date: ${date_value}" \
    -H "Content-Type: ${content_type}" \
    -H "Authorization: AWS ${aws_ak}:${signature}" \
    "${s3_endpoint}${resource}"
if [ $? -ne 0 ]; then
    echo "Error: Upload failed."
    exit 1
fi
echo "Upload complete."

# Cleanup
rm -rf "$tempDir"
rm -f "$OutputFile"

exit 0