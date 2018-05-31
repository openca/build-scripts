#!/bin/bash


######################### FUNCTIONS ################
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
	scp -q $1*.bin "$2"
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
	echo "OpenCA Software Build for Linux:"
	echo "================================"
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
	get_cvs_src "${pkg}"

	echo "   * Compiling ... "
	# build_src "$tmpdir" "$srcfile"
	build_cvs_src "$tmpdir/$pkg"

	echo "   * Building Package ${pkgname} ... "
	# build_snap_pkg "${tmpdir}/${pkgsnapfile}"
	build_rel_pkg "${tmpdir}/${pkg}"

	echo "   * Publishing Package ... "
	ssh "${rep_host}" "mkdir -p \"${rel_bin_dir}\""
	publish_pkg "${pkgrelfile}" "${rel_bin_rep}"
	# cp "${tmpdir}/${pkgsnapfile}.gz" "$HOME"

	echo "   * Cleaning Up ... "
	cd $HOME && cleanup "$tmpdir"

	echo "   * Success!"
	echo " - Done."
	echo
}

function build_snap() {

	srcfile="$pkg-SNAP-${date}.tar.gz"
	snap_bin_rep="$rep_host:$prj_dir/snapshots/${month}/binaries/solaris/${dist}"
	snap_bin_dir="$prj_dir/snapshots/${month}/binaries/solaris/${dist}"

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
	get_cvs_src "${pkg}"

	echo "   * Compiling ... "
	# build_src "$tmpdir" "$srcfile"
	build_cvs_src "$tmpdir/$pkg"

	echo "   * Building Package ${pkgname} ... "
	# build_snap_pkg "${tmpdir}/${pkgsnapfile}"
	build_snap_pkg "${tmpdir}/${pkg}"

	echo "   * Publishing Package ... "
	ssh "${rep_host}" "mkdir -p \"${snap_bin_dir}\""
	publish_pkg "${pkgsnapfile}" "${snap_bin_rep}"
	# cp "${tmpdir}/${pkgsnapfile}.gz" "$HOME"

	echo "   * Cleaning Up ... "
	cd $HOME && cleanup "$tmpdir"

	echo "   * Syncing SF repository ... "
        # $HOME/bin/sf-sync.sh ${pkgname} ${ver} 2>&1 > sync.log
	ssh albert.openca.org /repository/scripts/sf-sync.sh \
                                ${pkgname} ${ver} 2>&1 > sync.log

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
tmpdir="$HOME/tmp-${pkg}"
inst_dest="/tmp/inst/${pkg}"

arch=`uname -p`
month=`date +%B_%Y`
dist=unknown
ver=`uname -r`
# dist=`uname -p`
dist="Solaris${ver}-${arch}"

rep_host="cvs.openca.org"
rep_dir="/repository/projects/${pkg}"
src_rep="${rep_host}:/${rep_dir}/sources"
snap_rep="${rep_host}:${rep_dir}/snapshots/sources"
bin_rep="${rep_host}:${rep_dir}/snapshots/${month}/binaries/solaris/${dist}"
rel_bin_rep="${rep_host}:${rep_dir}/releases/v${ver}/binaries/solaris/${dist}"
date=`date +%Y%m%d`
os=`uname -s`-`uname -r`-`uname -p`
prj_dir="${rep_dir}"

# DIST_NAME=`head -n 1 /etc/issue | cut -f 1,1 -d ' '`
DIST_NAME="solaris"
#DIST_VERSION=`egrep -o [0-9.]+ /etc/issue | head -n 1`
DIST_VERSION=`uname -r`

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
