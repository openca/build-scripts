#!/bin/bash


######################### FUNCTIONS ################
function create_tmp () {
	if [ -d "$1" ] ; then
		rm -rf "$1"
	fi
	mkdir -p "$1"
}

function cleanup () {

	if [ -d "$1" ] ; then
		rm -rf "$1"
	fi
}

function get_daily_src () {
	file="$1/"
	scp -q "${file}" "${tmpdir}"
	if [ $? -gt 0 ]  ; then
		echo "ERROR: can not get ${uri} src file!"
		exit 1;
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

function usage () {
	echo "Usage: $0 <pkgname> [ snap | rel <ver> ]"
	exit 1;
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
	sudo make rpm 2>../rpm-build-err.txt \
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
	scp -q $1*.rpm "$2"
	if [ $? -gt 0 ] ; then
		echo "ERROR: can not publish archive $1 @ $2!"
		exit 1;
	fi
}

function build_rel() {

	get_dist

	srcfile="$pkg-${ver}.tar.gz"
	rel_bin_dir="$prj_dir/releases/v${ver}/binaries/linux/${dist}-${arch}"
	rel_bin_rep="$rep_host:${rel_bin_dir}"

	echo
	echo "OpenCA Software Build for Linux:"
	echo "================================"
	echo
	echo " - Version ......... : ${ver}"
	echo " - PKG ............. : ${pkg}"
	echo " - System .......... : "`uname -n`
	echo " - Architecture .... : "`uname -i`" ("`uname -m`")"
        echo " - Distribution .... : "${distname}
        echo " - Distro Version .. : "${distver}
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

	echo "   * Building Package ${pkg} ... "
	build_rel_pkg "${tmpdir}/${pkg}"

	echo "   * Publishing Package ... "
	ssh "${rep_host}" "mkdir -p \"${rel_bin_dir}\""
	publish_pkg "${pkg}" "${rel_bin_rep}"

	echo "   * Cleaning Up ... "
	cd $HOME && cleanup "$tmpdir"

	echo "   * Syncing SF repository (${pkg}-${ver}) ... "
        # $HOME/bin/sf-sync.sh ${pkg} ${ver} 2>&1 > sync.log
	ssh ftp.openca.org /repository/scripts/sf-sync.sh \
                                ${pkg} rel ${ver} 2>&1 > sync.log

	echo "   * Success!"
	echo " - Done."
	echo
}

function build_snap() {

	srcfile="$pkg-SNAP-${date}.tar.gz"
	snap_bin_rep="$rep_host:$prj_dir/snapshots/binaries/linux/${dist}-${arch}"
	snap_bin_dir="$prj_dir/snapshots/binaries/linux/${dist}-${arch}"

	echo
	echo "OpenCA Software Build for Linux:"
	echo "================================"
	echo
	echo " - SNAP ............ : ${date}"
	echo " - PKG ............. : ${pkg}"
	echo " - System .......... : "`uname -n`
	echo " - Architecture .... : "`uname -i`" ("`uname -m`")"
	echo " - Distribution .... : ${distname} ${distver}"
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
	# build_snap_pkg "${tmpdir}/${pkgsnapfile}"
	build_snap_pkg "${tmpdir}/${pkg}"

	echo "   * Publishing Package ... "
	ssh "${rep_host}" "mkdir -p \"${snap_bin_dir}\""
	publish_pkg "${pkgsnapfile}" "${snap_bin_rep}"
	# cp "${tmpdir}/${pkgsnapfile}.gz" "$HOME"

	echo "   * Cleaning Up ... "
	cd $HOME && cleanup "$tmpdir"

	echo "   * Syncing SF repository (${pkg}-${ver}) ... "
        # $HOME/bin/sf-sync.sh ${pkg} ${ver} 2>&1 > sync.log
	ssh ftp.openca.org /repository/scripts/sf-sync.sh \
                                ${pkg} snap 2>&1 > sync.log

	echo "   * Success!"
	echo " - Done."
	echo
}

function get_dist () {

  is_mandrake=`test -e /etc/mandrake-release && echo 1 || echo 0`;
  is_suse=`test -e /etc/SuSE-release && echo 1 || echo 0`
  is_fedora=`test -e /etc/fedora-release && echo 1 || echo 0`
  is_ubuntu=`test -e /usr/bin/ubuntu-bug && echo 1 || echo 0`
  is_centos=`echo ``rpm -qf /etc/redhat-release --qf '%{name} 0' 2>/dev/null | sed -e 's@centos-release@1 1@' | sed -e 's@[^ ]*@@' | awk {'print $1'}`` `

  dist=redhat
  disttag=rh
  distname=Redhat

  if [ $is_mandrake -gt 0 ] ; then
    dist=mandrake
    distname=Mandrake
    disttag=mdk
  fi
  if [ $is_suse -gt 0 ] ; then
    dist=suse
    distname=Suse
    disttag=suse
  fi
  if [ $is_fedora -gt 0 ] ; then
    dist=fedora
    distname=Fedora
    disttag=rhfc
  fi
  if [ $is_ubuntu -gt 0 ] ; then
    dist=ubuntu
    distname=Ubuntu
    disttag=ub
    distver=`cat /etc/issue | grep -o -e '[0-9.]*' | sed -e 's/\\.//'`
  fi

  if [ $is_centos -gt 0 ] ; then
    dist=centos
    distname=CentOS
    disttag=el
  fi

  release="`rpm -q --queryformat='%{VERSION}' ${dist}-release 2> /dev/null | tr . : | sed s/://g`" 
  distver=`if test $? != 0 ; then release="" ; fi ; echo "$release"`

  dist="${distname}${distver}"

}

######################### MAIN BODY ##################

pkg=$1
target=$2
ver=$3
branch=$4

if [ "${pkg}" = "" ] ; then
	usage
fi

dist=unknown
disttag=unknown
distver=unknown
distname=unknown

prefix=/usr/sfw
tmpdir="$HOME/tmp-${pkg}-$$"

os=`uname -s`-`uname -r`.`uname -v`-`uname -m`
arch=`uname -m`
month=`date +%Y-%m`
date=`date +%Y%m%d`

get_dist

rep_host="ftp.openca.org"
prj_dir="/repository/projects/${pkg}"

pkgsnapfile="${pkg}-SNAP-${date}"
pkgrelfile="${pkg}-${ver}"

if [ "x$branch" = "x" ] ; then
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
	dist)
		get_dist
		echo "DIST: ${dist}"
		;;
	*)
		usage
		;;
esac

exit 0
