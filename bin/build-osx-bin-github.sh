#!/bin/bash


######################### FUNCTIONS ################
function usage () {
	echo "Usage: $0 <pkgname> [ snap | rel <ver> ]"
	exit 1;
}

function create_tmp () {
	echo "Deleting TMP directory ($1) ..."
	if [ -d "$1" ] ; then
		rm -rf "$1"
	fi
	mkdir -p "$1"
}

function cleanup () {

	echo "Deleting TMP directory ($1) ..."
	if [ -d "$1" ] ; then
		rm -rf "$1"
	fi
}

function get_github_src () {
	cd "${tmpdir}"
	wget -q -O "${pkg}.zip" "${github_url}" 2>&1 >/dev/null
	if [ $? -gt 0 ]  ; then
		echo "ERROR: can not get $1 master.zip src file!"
		exit 1;
	fi
	unzip -qq "${pkg}.zip" 2>&1 > /dev/null
	if ! [ -d "${pkg}-${github_branch}" ] ; then
		echo "ERROR: missing dir $pkg-${github_branch} in $tmpdir!"
		exit 1;
	fi
	mv "${pkg}-${github_branch}" "${pkg}"
	cd - 2>&1 >/dev/null
}

function build_src () {
	if ! [ -d "$1" ] ; then
		echo "ERROR: dir $1 does not exists!"
		exit 1;
	fi

	cd "$1"

	. /etc/profile

	( ./configure --prefix="$prefix" ) 2>../src_build_err.txt \
			 >../src_build_log.txt

	if [ $? -gt 0 ] ; then
		echo "ERROR: build FAILED!!!"
		env
		exit 1;
	fi

}

function build_rel_pkg () {

	cd "$1"
	touch *
	make pkgbuild 2>../rpm-build-err.txt \
				>../rpm-build-log.txt

	if [ $? -gt 0 ] ; then
		echo "ERROR: pkg creation error!"
		exit 1;
	fi

}

function build_snap_pkg () {

	cd "$1"
	touch *
	sudo make snaprpm 2>../rpm-build-err.txt \
				>../rpm-build-log.txt

	if [ $? -gt 0 ] ; then
		echo "ERROR: pkg creation error!"
		exit 1;
	fi

}

function publish_pkg () {
	scp -q $1*.dmg "$2"
	if [ $? -gt 0 ] ; then
		echo "ERROR: can not publish archive $1 @ $2!"
		exit 1;
	fi
}

function build_rel() {

	srcfile="$pkg-${ver}.tar.gz"
	rel_bin_dir="$prj_dir/releases/v${ver}/binaries/osx/${dist}"
	rel_bin_rep="$SSH_USER@$rep_host:${rel_bin_dir}"

	echo
	echo "OpenCA Software Build for OSX:"
	echo "=============================="
	echo
	echo " - Version ......... : ${ver}"
	echo " - PKG ............. : ${pkg}"
	echo " - System .......... : "`uname -n`
	echo " - Architecture .... : "`uname -p`" ("`uname -m`")"
	echo " - PKG ............. : ${pkg}"
	echo 

	echo " - Processing Package:"
	echo "   * Cleaning tmp dirs ... "
	cleanup "$tmpdir" "${inst_dest}"
	create_tmp "$tmpdir"

	echo "   * Retrieving source file ($srcfile) ... "
	get_github_src "${pkg}"

	echo "   * Compiling ... "
	build_src "$tmpdir/$pkg"

	echo "   * Building Package ${pkgname} ... "
	build_rel_pkg "${tmpdir}/${pkg}"

	echo "   * Publishing Package [$rep_host]... "
	ssh -l $SSH_USER "${rep_host}" "mkdir -p \"${rel_bin_dir}\""
	publish_pkg "${pkgrelfile}" "${rel_bin_rep}"

	echo "   * Cleaning Up ... "
	cd $HOME && cleanup "$tmpdir"

	echo "   * Syncing SF repository ... "
	ssh ftp.openca.org /repository/scripts/sf-sync.sh \
  		${pkgname} rel ${ver} 2>&1 > sync.log

	echo "   * Success!"
	echo " - Done."
	echo
}

function build_snap() {

	srcfile="$pkg-SNAP-${date}.tar.gz"
	snap_bin_rep="$rep_host:$prj_dir/snapshots/${month}/binaries/osx/${dist}"
	snap_bin_dir="$prj_dir/snapshots/${month}/binaries/osx/${dist}"

	echo
	echo "OpenCA Software Build for OSX:"
	echo "=============================="
	echo
	echo " - SNAP ............ : ${date}"
	echo " - PKG ............. : ${pkg}"
	echo " - System .......... : "`uname -n`
	echo " - Architecture .... : "`uname -p`" ("`uname -m`")"
	echo " - PKG ............. : ${pkg}"
	echo 

	echo " - Processing Package:"
	echo "   * Cleaning tmp dirs ... "
	cleanup "$tmpdir" "${inst_dest}"
	create_tmp "$tmpdir"

	echo "   * Retrieving source file ($srcfile) ... "
	get_github_src "${pkg}"

	echo "   * Compiling ... "
	build_src "$tmpdir/$pkg"

	echo "   * Building Package ${pkgname} ... "
	build_snap_pkg "${tmpdir}/${pkg}"

	echo "   * Publishing Package [$rep_host]... "
	ssh -l $SSH_USER "${rep_host}" "mkdir -p \"${snap_bin_dir}\""
	publish_pkg "${pkgsnapfile}" "${snap_bin_rep}"

	echo "   * Cleaning Up ... "
	cd $HOME && cleanup "$tmpdir"

	echo "   * Syncing SF repository ... "
	ssh ftp.openca.org /repository/scripts/sf-sync.sh \
  		${pkgname} snap ${date} 2>&1 > sync.log

	echo "   * Success!"
	echo " - Done."
	echo
}

function get_dist () {
	n="unknown"
	o=""

	# o=`system_profiler | grep "System Version" | sed -e "s|[^0-9]*||" | sed -e "s|\..*||"`
	# if ! [ "x$o" = "x" ] ; then
	# 	n="darwin"
	# fi

	dist=`uname -s`.`uname -m`
}

######################### MAIN BODY ##################

pkg=$1
target=$2
ver=$3
branch=$4

if [ "${pkg}" = "" ] ; then
	usage
fi

prefix=/usr
tmpdir="$HOME/tmp-${pkg}"

arch=`uname -m`
dist=unknown

get_dist

rep_host="pki.openca.org"
prj_dir="/repository/projects/${pkg}"
month=`date +%B_%Y`
date=`date +%Y%m%d`

os=`uname -s`-`uname -r`.`uname -v`-`uname -m`
DIST_NAME=`head -n 1 /etc/issue | cut -f 1,1 -d ' '`
DIST_VERSION=`egrep -o [[0-9.]]+ /etc/issue | head -n 1`
SSH_USER=$USER

pkgsnapfile="${pkg}-SNAP-${date}"
pkgrelfile="${pkg}-${ver}"

if [ "x$branch" = "x" ] ;
	github_branch="master"
else
	github_branch="$branch"
fi

github_zip="$github_branch.zip"
github_base="https://github.com/openca"
github_suffix="archive/$github_zip"
github_url="${github_base}/${pkg}/${github_suffix}"

case "$target" in
	snap)
		build_snap
		;;
	rel)
		if [ "$ver" = "" ] ; then
			usage
		fi
		pkgrelfile="${pkg}-${ver}"
		build_rel
		;;
	*)
		usage
		;;
esac

exit 0
