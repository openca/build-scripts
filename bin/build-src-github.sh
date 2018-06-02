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

function get_github_src () {
	cd "${tmpdir}"
	wget -q -O "${pkgname}.zip" "${github_url}"
	if [ $? -gt 0 ]  ; then
		echo "ERROR: can not get $1 master.zip src file!"
		exit 1;
	fi
	unzip -qq "${pkgname}.zip"
	if ! [ -d "${pkgname}-${github_branch}" ] ; then
		echo "ERROR: missing dir $pkgname-$github_branch in $tmpdir!"
		exit 1;
	fi
	mv "${pkgname}-${github_branch}" "${pkgname}"
	cd - 2>&1 >/dev/null
}

function usage () {
	echo "Usage: $0 <pkgname> <snap | rel <version> >"
	exit 1;
}

function build_github_src () {
	if ! [ -d "$1" ] ; then
		echo "ERROR: dir $1 does not exists!"
		exit 1;
	fi

	if ! [ -r "$1/$2" ] ; then
		echo "ERROR: package file $1/$2 does not exists!"
		exit 1;
	fi

	if ! [ "$target" = "snap" -o "$target" = "dist" ] ; then
		echo "ERROR: need dist or snap (got $target)!"
		exit 1;
	fi

	dest="$target"
	build_dir="$1/$2"

	. /etc/profile

	cd "$build_dir"

	( ./configure --prefix="$prefix" && \
		make $dest  ) 2>../src_build_err.txt \
				 >../src_build_log.txt

	if [ $? -gt 0 ] ; then
		echo "ERROR: build FAILED!!!"
		env
		exit 1;
	fi

}

function publish_pkg () {

	openssl="/opt/csw/bin/openssl"
	if ! [ -x "$openssl" ] ; then
		openssl="/usr/bin/openssl"
	fi
	if ! [ -x "$openssl" ] ; then
		openssl="/usr/sfw/bin/openssl"
	fi
	if ! [ -x "$openssl" ] ; then
		openssl="/usr/bin/openssl"
	fi

	scp -q "$1" "$2:$3"

	if [ $? -gt 0 ] ; then
		echo "ERROR: can not publish archive $1 @ $2!"
		exit 1;
	fi
	ssh "$2" "${openssl} dgst -sha1 < \"$3/$4\" > \"$3/$4.sha1\" "
}

function build_src_snap() {

	srcfile="$pkg-SNAP-${date}.tar.gz"
	src_snap_dir="${prj_dir}/snapshots/sources"
	src_snap_rep="${rep_host}:${src_snap_dir}"

	echo
	echo "OpenCA Software - Source Package(s) building:"
	echo "=============================================="
	echo
	echo " - SNAP ........... : ${date}"
	echo " - PKG ............ : ${pkg}"
	echo " - Build Host ..... : "`uname -n`
	echo " - Architecture ... : "`uname -i`
	echo " - Project Dir .... : ${prj_dir}"
	echo 

	echo " - Processing Package:"
	echo "   * Cleaning tmp dirs ... "
	cleanup "$tmpdir" "${inst_dest}"
	create_tmp "$tmpdir"

	echo "   * Retrieving source archive ($github_branch.zip) files ... "
	get_github_src "${pkg}"

	echo "   * Configuring and building archive file ... "
	build_github_src "$tmpdir" "$pkg" "$target"

	echo "   * Publishing Archive ... "
	ssh "${rep_host}" "mkdir -p \"${src_snap_dir}\""
	for i in ${tmpdir}/${pkg}/*SNAP*.tar.gz ; do
		publish_pkg "${i}" "${rep_host}" "${src_snap_dir}" \
			"${i##${tmpdir}/${pkg}/}"
	done

	echo "   * Cleaning Up ... "
	cd $HOME && cleanup "$tmpdir" && \
	cleanup "${pkgrep}/OCA${pkg}"

	echo "   * Syncing SF repository (${pkg}-${month}) ... "
        ssh ftp.openca.org /repository/scripts/sf-sync.sh \
           ${pkg} snap 2>&1 > sync.log

	echo "   * Success!"
	echo " - Done."
	echo
}

function build_src_rel() {

	srcfile="${pkg}-${ver}.tar.gz"
	src_rel_dir="${prj_dir}/releases/v${ver}/sources"
	src_rel_rep="${rep_host}:${src_rel_dir}"

	echo
	echo "OpenCA Software - Source Package(s) building:"
	echo "=============================================="
	echo
	echo " - SNAP ........... : ${date}"
	echo " - PKG ............ : ${pkg}"
	echo " - Build Host ..... : "`uname -n`
	echo " - Architecture ... : "`uname -i`
	echo 

	echo " - Processing Package:"
	echo "   * Cleaning tmp dirs ... "
	cleanup "$tmpdir" "${inst_dest}"
	create_tmp "$tmpdir"

	echo "   * Retrieving source archive (master.zip) files ... "
	get_github_src "${pkg}"

	echo "   * Configuring and building archive file ... "
	build_github_src "$tmpdir" "$pkg" "$target"

	echo "   * Publishing Archive ... "
	ssh "$rep_host" "mkdir -p \"${src_rel_dir}\""
	for i in ${tmpdir}/${pkg}/*.tar.gz ; do
		publish_pkg "$i" "${rep_host}" "${src_rel_dir}" \
			"${i##${tmpdir}/${pkg}/}"
	done

	echo "   * Cleaning Up ... "
	cd $HOME && cleanup "$tmpdir" && \
			cleanup "${pkgrep}/OCA${pkg}"

        echo "   * Syncing SF repository (${rel}-${ver}) ... "
        ssh ftp.openca.org /repository/scripts/sf-sync.sh \
                ${pkg} rel ${ver} 2>&1 > sync.log

	echo "   * Success!"
	echo " - Done."
	echo
}
######################### MAIN BODY ##################

pkg=$1
target=$2
ver=$3
brach=$4

os=`uname -s`-`uname -r`
arch=`uname -p`
month=`date +%B_%Y`
date=`date +%Y%m%d`

if [ "${pkg}" = "" -o "${target}" = "" ] ; then
	usage
fi

prefix=/usr/sfw
tmpdir="$HOME/tmp-${pkg}-src-$$"
inst_dest="/tmp/inst/${pkg}-$$"

prj_dir="/repository/projects/${pkg}"
rep_host="ftp.openca.org"
src_rel_rep="${rep_host}:${prj_dir}/releases/v${ver}/sources"
src_snap_rep="${rep_host}:${prj_dir}/snapshots/${month}/sources"

pkgname="${pkg}"
pkgsnapfile="${pkg}-SNAP-${date}.tar.gz"
pkgrelfile="${pkg}-${ver}.tar.gz"
pkgrep="/var/spool/pkg"
target=""

if [ "x$branch" = "x" ] ; then
	github_branch="master"
else
	github_branch="$branch"
fi

github_zip="$github_branch.zip"
github_base="https://github.com/openca"
github_suffix="archive/$github_zip"
github_url="${github_base}/${pkg}/${github_suffix}"

case "$2" in
	snap) 
		target=snap
		src_snap_rep="${rep_host}:${prj_dir}/snapshots/${month}/sources"
		pkgsnapfile="${pkg}-SNAP-${date}.tar.gz"
		build_src_snap
		;;
	rel)
		target=dist
		if [ "$ver" = "" ] ; then
			usage
		fi
		src_rel_rep="${rep_host}:${prj_dir}/releases/v${ver}/sources"
		pkgrelfile="${pkg}-${ver}.tar.gz"
	  build_src_rel
		;;
	*)
		usage
		;;
esac

exit 0
