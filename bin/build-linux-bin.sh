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

function get_cvs_src () {
	cd "${tmpdir}"
	cvs -Q export -r HEAD "$1"
	if [ $? -gt 0 ]  ; then
		echo "ERROR: can not get $1 CVS src file!"
		exit 1;
	fi
	cd - 2>&1 >/dev/null
}

function usage () {
	echo "Usage: $0 <pkgname> [ snap | rel <ver> ]"
	exit 1;
}

function build_cvs_src () {
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

function build_src () {
	if ! [ -d "$1" ] ; then
		echo "ERROR: dir $1 does not exists!"
		exit 1;
	fi

	if ! [ -r "$1/$2" ] ; then
		echo "ERROR: package file $1/$2 does not exists!"
		exit 1;
	fi

	cd "$1"

	build_dir=`echo $2 | sed "s|.tar.gz||"`
	gunzip -c "$2" | tar xf -

	if [ $? -gt 0 ] ; then
		echo "ERROR: package file is corrupted!"
		exit 1;
	fi

	. /etc/profile

	cd "$build_dir"

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
	fname="";
	if [ -f $1*.bin ] ; then
		fname=$1*.bin;
	fi

	if [ -f $1*.run ] ; then
		fname=$1*.run;
	fi

	echo "   * Transferring $fname ... "
	scp -q $fname "$2"
	if [ $? -gt 0 ] ; then
		echo "ERROR: can not publish archive $1 @ $2!"
		exit 1;
	fi
}

function build_rel() {

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
	echo " - PKG ............. : ${pkg}"
	echo 

	echo " - Processing Package:"
	echo "   * Cleaning tmp dirs ... "
	cleanup "$tmpdir" "${inst_dest}"
	create_tmp "$tmpdir"

	echo "   * Retrieving source file ($srcfile) ... "
	get_cvs_src "${pkg}"

	echo "   * Compiling ... "
	# build_src "$tmpdir" "$srcfile"
	build_cvs_src "$tmpdir/$pkg"

	echo "   * Building Package ${pkg} ... "
	# build_snap_pkg "${tmpdir}/${pkgsnapfile}"
	build_rel_pkg "${tmpdir}/${pkg}"

	echo "   * Publishing Package ... "
	ssh "${rep_host}" "mkdir -p \"${rel_bin_dir}\""
	publish_pkg "${pkgrelfile}" "${rel_bin_rep}"
	# cp "${tmpdir}/${pkgsnapfile}.gz" "$HOME"

	echo "   * Cleaning Up ... "
	cd $HOME && cleanup "$tmpdir"

	echo "   * Syncing SF repository ... "
	ssh ftp.openca.org /repository/scripts/sf-sync.sh \
				${pkg} ${ver} 2>&1 > sync.log

	echo "   * Success!"
	echo " - Done."
	echo
}

function build_snap() {

	srcfile="$pkg-SNAP-${date}.tar.gz"
	snap_bin_rep="$rep_host:$prj_dir/snapshots/${month}/binaries/linux/${dist}-${arch}"
	snap_bin_dir="$prj_dir/snapshots/${month}/binaries/linux/${dist}-${arch}"

	echo
	echo "OpenCA Software Build for Linux:"
	echo "================================"
	echo
	echo " - SNAP ............ : ${date}"
	echo " - PKG ............. : ${pkg}"
	echo " - System .......... : "`uname -n`
	echo " - Architecture .... : "`uname -i`" ("`uname -m`")"
	echo " - PKG ............. : ${pkg}"
	echo 

	echo " - Processing Package:"
	echo "   * Cleaning tmp dirs ... "
	cleanup "$tmpdir" "${inst_dest}"
	create_tmp "$tmpdir"

	echo "   * Retrieving source file ($srcfile) ... "
	get_cvs_src "${pkg}"

	echo "   * Compiling ... "
	# build_src "$tmpdir" "$srcfile"
	build_cvs_src "$tmpdir/$pkg"

	echo "   * Building Package ${pkg} ... "
	# build_snap_pkg "${tmpdir}/${pkgsnapfile}"
	build_snap_pkg "${tmpdir}/${pkg}"

	echo "   * Publishing Package ... "
	ssh "${rep_host}" "mkdir -p \"${snap_bin_dir}\""
	publish_pkg "${pkgsnapfile}" "${snap_bin_rep}"
	# cp "${tmpdir}/${pkgsnapfile}.gz" "$HOME"

	echo "   * Cleaning Up ... "
	cd $HOME && cleanup "$tmpdir"

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

if [ "${pkg}" = "" ] ; then
	usage
fi

prefix=/usr/sfw
tmpdir="$HOME/tmp-${pkg}-$$"

export CVSROOT=":ext:$USER@cvs.openca.org:/cvsroot/projects"
export CVS_RSH=ssh

arch=`uname -m`
dist=unknown

os=`uname -s`-`uname -r`.`uname -v`-`uname -m`
DIST_NAME=`head -n 1 /etc/issue | cut -f 1,1 -d ' '`
DIST_VERSION=`egrep -o [0-9.]+ /etc/issue | head -n 1`

get_dist

rep_host="cvs.openca.org"
prj_dir="/repository/projects/${pkg}"
month=`date +%B_%Y`
# rel_bin_rep="$rep_host:$prj_dir/releases/${ver}/linux/${dist}/binaries"
# snap_bin_rep="$rep_host:$prj_dir/snapshots/${month}/linux/${dist}/binaries"
# bin_rep="cvs.openca.org:/repository/projects/${pkg}/snapshots/binaries/linux/${dist}-${arch}"
# rel_bin_rep="cvs.openca.org:/repository/projects/${pkg}/releases/binaries/linux/${dist}-${arch}"
date=`date +%Y%m%d`

pkgsnapfile="${pkg}-SNAP-${date}"
pkgrelfile="${pkg}-${ver}"

case "$2" in
	snap) build_snap
		;;
	rel)
		ver=$3
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
