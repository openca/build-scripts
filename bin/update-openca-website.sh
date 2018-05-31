#!/bin/bash
YEAR=`date +%Y`

### Functions ######################################################

function banner () {
	echo
	echo "OpenCA Website Updater - v0.1"
	echo "(c) 1998-$YEAR by Massimiliano Pala and OpenCA Labs"
	echo "All Rights Reserved"
	echo
}

function usage () {
	echo
	echo "   Usage: $0 <pkg>"
	echo
	exit 1
}

function get_sources() {

	CVSROOT=:ext:$USER@cvs.openca.org:/cvsroot/projects \
		cvs export -r HEAD "$pkg" 2>"logs/update-err.log" > "logs/update.log"

	if [ $? -gt 0 ] ; then
		cd "$c_dir"
		echo "ERROR: can not build SNAP!"
		exit 1;
	fi
}

function update_web() {
	# Creates the Backup dir
	[ -d ".bak" ] || mkdir -p ".bak"

	# Removes the old backups
	[ -d ".bak/html.old" ] && rm -rf ".bak/html.old"
	[ -d ".bak/cgi-bin.old" ] && rm -rf ".bak/cgi-bin.old"

	# Creates backups of the html and cgi directories
	[ -d "html" ] && mv "html" ".bak/html.old"
	[ -d "cgi-bin" ] && mv "cgi-bin" ".bak/cgi-bin.old"

	mv "$pkg/html" "html"
	mv "$pkg/cgi-bin" "cgi-bin"

	# Creates the link for the wiki pages
	if [ -d "wiki" ] ; then
		( cd "html" && ln -s ../wiki wiki);
	fi

	# Creates the link for the pki (OpenCA Install) pages
	if [ -d "pki" ] ; then
		( cd "html" && ln -s ../pki/html pki);
		( cd "cgi-bin" && ln -s ../pki/cgi-bin pki);
	fi
}

### Main ############################################################

date=`date +%Y%m%d`
pkg="openca-web"
basedir=/mnt/big/System/WebSites/OpenCA
htmldir=$basedir/html
cgidir=$basedir/cgi-bin
c_dir=`pwd`

cd "$basedir"

banner

echo "  Operation Progress:"
echo "  ==================="
echo -n "  * Getting the package sources from repository ..."
get_sources
if [ $? -gt 0 ] ; then
	echo "ERROR: can not fetch sources!"
	exit 1;
fi
echo "Ok."

echo -n "  * Updating html and cgi-bin directories ... "
update_web
echo "Ok."

echo "  * All Done."
echo

# Removes the sources directory
[ -d "openca-web" ] && rm -rf "openca-web"
cd "$c_dir"

exit 0;
