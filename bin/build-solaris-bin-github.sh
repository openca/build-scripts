#!/bin/bash


######################### FUNCTIONS ################
function usage () {
	echo "Usage: $0 <pkgname> [ snap | rel <ver> ]"
	exit 1;
}

function create_tmp () {
	if [ -d "$1" ] ; then
		pfexec rm -rf "$1"
	fi
	mkdir -p "$1"
}

function cleanup () {

	if [ -d "$1" ] ; then
		pfexec rm -rf "$1"
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
		echo "ERROR: missing dir $pkg-$github_branch in $tmpdir!"
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

	# echo "   * Running libtool, aclocal and autoconf... "
	# ( libtoolize --force -c ; aclocal-1.10 ; autoconf ) \
	# 		2>../src_conf_err.txt >../src_conf_log.txt


	echo "   * Configuring and building the package ... "
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
	pfexec make pkgbuild 2>../rpm-build-err.txt \
				>../rpm-build-log.txt

	if [ $? -gt 0 ] ; then
		echo "ERROR: pkg creation error!"
		exit 1;
	fi

}

function build_snap_pkg () {

	cd "$1"
	touch *
	pfexec make snaprpm 2>../rpm-build-err.txt \
				>../rpm-build-log.txt

	if [ $? -gt 0 ] ; then
		echo "ERROR: pkg creation error!"
		exit 1;
	fi

}

function publish_pkg () {
	scp -q $1*.bin $1*.run "$2"
	if [ $? -gt 0 ] ; then
		echo "ERROR: can not publish archive $1 @ $2!"
		exit 1;
	fi
}

function build_rel() {

	srcfile="$pkg-${ver}.tar.gz"
	rel_bin_dir="${prj_dir}/releases/v${ver}/binaries/solaris/${dist}"
	rel_bin_rep="$rep_host:${rel_bin_dir}"

	echo
	echo "OpenCA Software Build for Solaris:"
	echo "=================================="
	echo
	echo " - Version ......... : ${ver}"
	echo " - PKG ............. : ${pkg}"
	echo " - System .......... : "`uname -n`
	echo " - Architecture .... : "`uname -i`" ("`uname -p`")"
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

	echo "   * Publishing Package ... "
	ssh "${rep_host}" "mkdir -p \"${rel_bin_dir}\""
	publish_pkg "${pkgrelfile}" "${rel_bin_rep}"

	echo "   * Cleaning Up ... "
	cd $HOME && cleanup "$tmpdir"

	echo "   * Syncing SF repository ... "
	ssh ftp.openca.org /repository/scripts/sf-sync.sh \
                                ${pkgname} rel ${rel} 2>&1 > sync.log

	echo "   * Success!"
	echo " - Done."
	echo
}

function build_snap() {

	srcfile="$pkg-SNAP-${date}.tar.gz"
	snap_bin_rep="$rep_host:$prj_dir/snapshots/binaries/solaris/${dist}"
	snap_bin_dir="$prj_dir/snapshots/binaries/solaris/${dist}"

	echo
	echo "OpenCA Software Build for Solaris:"
	echo "================================="
	echo
	echo " - SNAP ............ : ${date}"
	echo " - PKG ............. : ${pkg}"
	echo " - System .......... : "`uname -n`
	echo " - Architecture .... : "`uname -i`" ("`uname -p`")"
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

	echo "   * Publishing Package ... "
	ssh "${rep_host}" "mkdir -p \"${snap_bin_dir}\""
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
	dist="$DIST_NAME$DIST_VERSION"

	if [ "x$dist" = "x" ] ; then
		if [ -r "/etc/redhat-release" ] ; then
			o=`cat /etc/redhat-release | sed "s|.*release ||" | sed "s| .*$||"`
			res=`grep -i "Fedora Core" "/etc/redhat-release"`
			if [ $? -gt 0 ] ; then
				n="rh"
			else
				n="fc"
			fi
		fi
		dist="${n}${o}"
	fi

}

######################### MAIN BODY ##################

pkg=$1
target=$2
ver=$3
branch=$4

if [ "${pkg}" = "" ] ; then
	usage
fi

prefix=/usr/sfw
tmpdir="$HOME/tmp-${pkg}"
inst_dest="/tmp/inst/${pkg}"

arch=`uname -p`
month=`date +%B_%Y`
dist=unknown
ver=`uname -r`
dist="Solaris${ver}-${arch}"

rep_host="ftp.openca.org"
rep_dir="/repository/projects/${pkg}"
src_rep="${rep_host}:/${rep_dir}/sources"
snap_rep="${rep_host}:${rep_dir}/snapshots/sources"
bin_rep="${rep_host}:${rep_dir}/snapshots/${month}/binaries/solaris/${dist}"
rel_bin_rep="${rep_host}:${rep_dir}/releases/v${ver}/binaries/solaris/${dist}"
date=`date +%Y%m%d`
os=`uname -s`-`uname -r`-`uname -p`
prj_dir="${rep_dir}"

DIST_NAME="solaris"
DIST_VERSION=`uname -r`

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
		pkgrelfile="${pkg}"
		build_rel
		;;
	*)
		usage
		;;
esac

exit 0
