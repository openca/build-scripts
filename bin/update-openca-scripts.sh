#!/bin/bash

CVSROOT=/cvsroot/projects
basedir=/mnt/big/System/OpenCA/ftp

# Exit if basedir does not exists
[ -d "$basedir" ] || exit 1

# Let's change directory
cd "$basedir"

# Move the "old" scripts directory
[ -d "scripts" ] && mv "scripts" "scripts.old"

# Get the CVS repository scripts
CVSROOT=$CVSROOT cvs export -r HEAD scripts 2>/dev/null >/dev/null

# If an error, let's exit with that
[ $? -gt 0 ] && exit $?

# Everything was ok, let's delete the old script dir
[ -d "scripts.old" ] && rm -rf "scripts.old"

# All Done
exit 0



