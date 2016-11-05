#!/bin/bash

# Create CS FV2 unlock only user - Proof of Concept Code

# Variables here
cdialogbin="/path/to/cocoadialog.app/path/to/cocoadialog"
localadminact="administrator"
localadminpw="password"

# Check for FV2 been enabled

fv2status=$( fdesetup status )

if [ "$fv2status" != "FileVault is On." ];
then
	echo "FV2 not fully enabled. Quitting."
	exit 0
fi

# Start by disabling FV2 passthrough login

defaults write /Library/Preferences/com.apple.loginwindow DisableFDEAutoLogin -bool YES

# Find user PID from smart card.

# Code from sc_auth. Spits out a bunch of hashes in the following format:
# 2CFF3BBDAD6CDBA0EF6B7D20DA04634CCA10B2BE name.surname (A123456)

hash=`
  string=${1:-'.*'}
  HOME=/no/where /usr/bin/security dump-keychain |
  awk -v RE="$string" '
		/^    0x00000001/       {
				if (matched = ($2 ~ RE)) { name=$0; sub("^.*<blob>=\"", "", name); sub("\"$", "", name); count++; }}
		/^    0x00000006/       {
				if (matched) { hash=$2; sub("<blob>=0x", "", hash); print hash, name; }}
  '
  HOME=/no/where /usr/bin/security dump-keychain |
  awk -v RE="$string" '
		/^    0x01000000/       {
				if (matched = ($2 ~ RE)) { name=$0; sub("^.*<blob>=\"", "", name); sub("\"$", "", name); count++; }}
		/^    0x06000000/       {
				if (matched) { hash=$2; sub("<blob>=0x", "", hash); print hash, name; }}
  '`

# Take the hash report. Strip out first two fields, the () characters and the first letter. This will be the unlock account.
# Can't use the full text at the end of the code as this will be the AD account created later from the card info. Two accounts One space!

newuser=$( echo $hash | awk '{gsub(/[;()'']/," "); print substr($3,2);}' )

# Prompt user with CocoaDialog for a device unlock password. Reference name we gathered earlier.

entry=$( $cdialogbin inputbox --title "Password" --icon-file "$lockscreenlogo" --informative-text "Please enter your password:" --text $hardcode --string-output --button1 "Ok" )
password=$( echo $entry | awk '{ print $2 }' )

# Find the last UIDs for users and groups used and go one higher for new account.

lastgroupuid=$( dscl . -list /Groups PrimaryGroupID | awk '{print $2}' | sort -n | tail -n1 )
groupuid=$( expr $lastgroupuid + 1 )

lastuseruid=$( dscl . -list /Users UniqueID | awk '{print $2}' | sort -n | tail -n1 )
useruid=$( expr $lastuseruid + 1 )

# Create a user group for this user

dscl . -create /Groups/FV2user
dscl . -create /Groups/FV2user PrimaryGroupID "$usergroup"

# Create the new user, hide it and add it to the group

dscl . -create /Users/$newuser
dscl . -create /Users/$newuser UserShell /sbin/nologin
dscl . -create /Users/$newuser RealName "$newuser"
dscl . -create /Users/$newuser UniqueID "$useruid"
dscl . -create /Users/$newuser PrimaryGroupID "$groupuid"
dscl . -create /Users/$newuser IsHidden 1
dscl . -passwd /Users/$newuser $password

# Write out an FV2 plist so we can add this user to the FV2 users list

fv2xml='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>Username</key>
<string>$localadminact</string>
<key>Password</key>
<string>$localadminpw</string>
<key>AdditionalUsers</key>
<array>
    <dict>
        <key>Username</key>
        <string>$newuser</string>
        <key>Password</key>
        <string>$password</string>
    </dict>
</array>
</dict>
</plist>'

echo $fv2xml > /private/tmp/fv.plist

# Now add user to the FV2 authorised users list

fdesetup add -inputplist < /private/tmp/fv.plist

# Clean up

rm /private/tmp/fv.plist
