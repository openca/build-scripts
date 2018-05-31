#!/bin/bash
YEAR=`date +%Y`

### Functions ######################################################

function banner () {
	echo
	echo "Snapshot Uploader - v0.1"
	echo "(c) 1998-$YEAR by Massimiliano Pala and OpenCA Labs"
	echo "All Rights Reserved"
	echo
}

function details () {
	echo "  Upload Details:"
	echo "  ==============="
	echo "  * Package ............: $pkg"
	echo "  * Upload Host ........: $host"
	echo "  * Upload Dir .........: $host_dir"
	echo
}

function usage () {
	echo
	echo "   Usage: $0 <pkg>"
	echo
	exit 1
}

function get_sources() {
	[ -d "$tmp_dir" ] || mkdir -p "$tmp_dir"
	cd "$tmp_dir"

	CVSROOT=:ext:$USER@cvs.openca.org:/cvsroot/projects \
		cvs export -r HEAD "$pkg" 2>"$tmp_dir/err.log" > "$tmp_dir/log.log"

	if [ $? -gt 0 ] ; then
		cd "$c_dir"
		echo "ERROR: can not build SNAP!"
		exit 1;
	fi

	cd "$c_dir"
}

function build_snap() {

	cd "$tmp_dir/$pkg"

	(./configure && make snap) 2>"$tmp_dir/err.log" > "$tmp_dir/log.log"

	if [ $? -gt 0 ] ; then
		cd "$c_dir"
		echo "ERROR: can not build SNAP!"
		exit 1;
	fi

	cd "$c_dir"
}

### Main ############################################################

date=`date +%Y%m%d`
pkg="$1"
basedir=$HOME/Devel/OpenCA/cvs
pkgname="$pkg-SNAP-$date.tar.gz"
host="ftp.openca.org"
host_dir="/repository/projects/$pkg/snapshots/sources/"
tmp_dir="/var/tmp/$$"
c_dir=`pwd`

banner

if [ "$pkg" = "" ] ; then
	usage
fi

details

echo "  Operation Progress:"
echo "  ==================="
echo -n "  * Getting the package sources from repository ..."
get_sources
if [ $? -gt 0 ] ; then
	echo "ERROR: can not fetch sources!"
	exit 1;
fi
echo "Ok."

echo -n "  * Generating snapshot package ... "
build_snap
echo "Ok."

## Let's go into the tmp dir
cd "$tmp_dir/$pkg"

echo -n "  * Uploading package ... "
## This creates the directory if it does not exists
ssh -q "$host" "[ -d \"${host_dir}\" ] || mkdir -p \"${host_dir}\""

## This copies the snap package
scp -q "${pkgname}" "$host":"$host_dir"
echo "Ok."

echo "  * All Done."
echo

exit 0;
