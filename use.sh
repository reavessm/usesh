#!/bin/bash
# use.sh
# Written by Stephen Reaves
# This script presents the users with a dialog prompt showing the available use
# options for a given software, then it installs the software with those use
# flags.
# 
# Copyright (c) 2019, Stephen Reaves
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
# TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# The views and conclusions contained in the software and documentation
# are those
# of the authors and should not be interpreted as representing official
# policies,
# either expressed or implied, of the use.sh project.

# Make sure user isn't a dumbass
if [[ $# != 1 ]]
then
  echo "Usage: $0 <name of package to install>"
  exit 1
fi

# Set temp files
file="/tmp/usething"
dialogPrompt="/tmp/dialog"
dialogAnswers="/tmp/dialog.answers"
makeconf="/etc/portage/make.conf"
pkguse="/etc/portage/package.use"
autounmask="$pkguse/zz-autounmask"
fullname=`awk -F ":" "/$1:/"'{print $1;exit}' /usr/portage/profiles/use.local.desc`

# Make sure files exist
for thing in "$file" "$dialogPrompt" "$dialogAnswers"
do
  rm -f "$thing"
  touch "$thing"
done

# This helps the greppy boi
touch "$pkguse/$1"

grep $1 /usr/portage/profiles/use.local.desc || emerge -av $1

# Search use options for given package
awk -F [\/:[:space:]] "/$1:/ "'{print $3,"\t",substr($0, index($0,$5))}' \
  /usr/portage/profiles/use.local.desc > "$file"

# Format options for Dialog
awk -F "\t" '{print $1,"\""$2"\"","off"}' "$file" > "$dialogPrompt"

# Check multiple places for use flags
for use in `awk '{print $1}' "$dialogPrompt" `
do 
  grep "$use" $makeconf &>/dev/null && \
    sed -i '/'"$use"'/ s/off/on/g' "$dialogPrompt"
  grep -E "$1.*$use" $autounmask &>/dev/null && \
    sed -i '/'"$use"'/ s/off/on/g' "$dialogPrompt"
  grep "$use" "$pkguse/$1" &>/dev/null && \
    sed -i '/'"$use"'/ s/off/on/g' "$dialogPrompt"
done

# Present user with options and save the answers
dialog --title "$1" --stdout --checklist "Choose USE flags:" 0 0 0 --file "$dialogPrompt" \
  > "$dialogAnswers" || exit 0

# Shove those bad bois in the global use flags.  Could also put them in package
# specific use flags, but that would require changing the first awk statement
for use in `cat "$dialogAnswers"`
do
  # I know i can use 'sed' here, but am too drunk
  grep "$use" "$pkguse/$1" || echo "$fullname $use" >> "$pkguse/$1"
done

# Clean up.  Maybe this is more secure
for thing in "$file" "$dialogPrompt" "$dialogAnswers"
do
  rm "$thing"
done

# Install Software
sudo emerge -a "$1" || ( sudo dispatch-conf && sudo emerge -a "$1")

# Make the user do stuff
echo "You make want to run 'emerge --changed-use @world'"

# Delete use file if empty
#[ -n "$pkguse/$1" ] && rm "$pkguse/$1"
