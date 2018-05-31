#!/usr/bin/bash


######################### FUNCTIONS ################
function create_tmp () {
	if [ -d "$1" ] ; then
		pfexec rm -rf "$1"
	fi
	pfexec mkdir -p "$1"
	pfexec chown $USER "$1"
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

function build_src () {
	if ! [ -d "$1" ] ; then
		echo "ERROR: dir $1 does not exists!"
		exit 1;
	fi

	if ! [ -r "$1/$2" ] ; then
		echo "ERROR: package file $1/$2 does not exists!"
		exit 1;
	fi

	create_tmp "$3"
	if ! [ -d "$3" ] ; then
		echo "ERROR: can not creat temp inst directory $3!"
		exit 1;
	fi

	dest="$3"

	cd "$1"

	build_dir=`echo $2 | sed "s|.tar.gz||"`
	gunzip -c "$2" | tar xf -

	if [ $? -gt 0 ] ; then
		echo "ERROR: package file is corrupted!"
		exit 1;
	fi

	. /etc/profile

	cd "$build_dir"

	# We need to rebuild the build tools
	# echo "   * Running libtool, aclocal and autoconf... "
	# ( libtoolize --force -c ; aclocal-1.10 ; autoconf ) \
        #                 2>../src_conf_err.txt >../src_conf_log.txt

	echo "   * Configuring and building the package ... "
	( DESTDIR="${inst_dest}" ./configure --prefix="$prefix" && \
		make && make man ; \
			make DESTDIR="${inst_dest}" prefix="${prefix}" \
				install install-man ) 2>../src_build_err.txt \
					 >../src_build_log.txt

	if [ $? -gt 0 ] ; then
		echo "ERROR: build FAILED!!!"
		env
		exit 1;
	fi

}

function build_cvs_src () {
	if ! [ -d "$1" ] ; then
		echo "ERROR: dir $1 does not exists!"
		exit 1;
	fi

	if ! [ -r "$1/$2" ] ; then
		echo "ERROR: package file $1/$2 does not exists!"
		exit 1;
	fi

	create_tmp "$3"
	if ! [ -d "$3" ] ; then
		echo "ERROR: can not creat temp inst directory $3!"
		exit 1;
	fi

	dest="$3"

	build_dir="$1/$2"

	. /etc/profile

	cd "$build_dir"

	# We need to rebuild the build tools
	# echo "   * Running libtool, aclocal and autoconf... "
	# ( libtoolize --force -c ; aclocal-1.10 ; autoconf ) \
        #                 2>../src_conf_err.txt >../src_conf_log.txt

	echo "   * Configuring and building the package ... "
	( DESTDIR="${inst_dest}" ./configure --prefix="$prefix" && \
		make && \
			make DESTDIR="${inst_dest}" prefix="${prefix}" \
				install ) 2>../src_build_err.txt \
					 >../src_build_log.txt

	if [ $? -gt 0 ] ; then
		echo "ERROR: build FAILED!!!"
		env
		exit 1;
	fi

}

function build_pkg () {

	if ! [ -d "$1" ] ; then
		echo "ERROR: dir $1 does not exists!"
		exit 1;
	fi

	cd "$1"

	pfexec echo "i pkginfo=./${prefix}/share/${pkg}/pkginfo" > prototype

	find . -type f \! -name "prototype" -print | pkgproto | \
			sed "s|$USER|root|" | \
				pfexec sed "s|openca|bin|" >> prototype

	dir=`pwd`
	pfexec /usr/bin/pkgmk -o -r "${dir}" 2>${tmpdir}/pkg_build_err.txt \
					>${tmpdir}/pkg_build_log.txt

	if [ $? -gt 0 ] ; then
		echo "ERROR: pkg creation error!"
		exit 1;
	fi

	cd - 2>/dev/null >/dev/null

	if [ -f "$2" ] ; then
		rm "$2"
	fi

	pfexec /usr/bin/pkgtrans -s "${pkgrep}" "$2" "${pkgname}" \
			2>${tmpdir}/pkg_trans_err.txt \
				>${tmpdir}/pkg_trans_log.txt

	if [ $? -gt 0 ] ; then
		echo "ERROR: pkg trans error!"
		exit 1;
	fi

	gzip -9 "$2"
}

function publish_pkg () {
	scp -q "$1" "$2"
	if [ $? -gt 0 ] ; then
		echo "ERROR: can not publish archive $1 @ $2!"
		exit 1;
	fi
}

function build_rel() {

	srcfile="$pkg-${ver}.tar.gz"

	echo
	echo "OpenCA Software Build for Solaris:"
	echo "=================================="
	echo
	echo " - Version ........ : ${ver}"
	echo " - PKG ............ : ${pkg}"
	echo " - PKG Name ....... : ${pkgname}"
	echo " - PKG File ....... : ${pkgfile}"
	echo " - Build Host ..... : "`uname -n`
	echo " - Architecture ... : "`uname -i`
	echo 

	echo " - Processing Package:"
	echo "   * Cleaning tmp dirs ... "
	cleanup "$tmpdir" "${inst_dest}"
	create_tmp "$tmpdir"

	echo "   * Retrieving source file ($srcfile) ... "
	get_cvs_src "${pkg}"

	echo "   * Compiling ... "
	# build_src "$tmpdir" "$pkg" "$inst_dest"
	build_cvs_src "$tmpdir" "$pkg" "$inst_dest"

	echo "   * Building Package ${pkgname} ... "
	build_pkg "${inst_dest}" "${tmpdir}/${pkgrelfile}"

	echo "   * Publishing Package ... "
	ssh "$rep_host" "mkdir -p \"${rel_dir}\""
	publish_pkg "${tmpdir}/${pkgrelfile}.gz" "${rel_bin_rep}"
	# cp "${tmpdir}/${pkgrelfile}.gz" "$HOME"

	echo "   * Cleaning Up ... "
	cd $HOME && cleanup "$tmpdir" && \
			cleanup "${pkgrep}/OCA${pkg}"

	echo "   * Syncing SF repository ... "
        # $HOME/bin/sf-sync.sh ${pkgname} ${ver} 2>&1 > sync.log
	project_name=`echo ${pkgname} | sed -e "s|OCA||"`
	ssh ${rep_host} /repository/scripts/sf-sync.sh \
                         ${project_name} ${ver} 2>&1 > sync.log
	

	echo "   * Success!"
	echo " - Done."
	echo
}

function build_snap() {

	srcfile="$pkg-SNAP-${date}.tar.gz"

	echo
	echo "OpenCA Software Build for Solaris:"
	echo "=================================="
	echo
	echo " - SNAP ........... : ${date}"
	echo " - PKG ............ : ${pkg}"
	echo " - PKG Name ....... : ${pkgname}"
	echo " - PKG File ....... : ${pkgfile}"
	echo " - Build Host ..... : "`uname -n`
	echo " - Architecture ... : "`uname -i`
	echo 

	echo " - Processing Package:"
	echo "   * Cleaning tmp dirs ... "
	cleanup "$tmpdir" "${inst_dest}"
	create_tmp "$tmpdir"

	echo "   * Retrieving source file ($srcfile) ... "
	get_cvs_src "${pkg}"

	echo "   * Compiling ... "
	# build_src "$tmpdir" "$pkg" "$inst_dest"
	build_cvs_src "$tmpdir" "$pkg" "$inst_dest"

	echo "   * Building Package ${pkgname} ... "
	build_pkg "${inst_dest}" "${tmpdir}/${pkgsnapfile}"

	echo "   * Publishing Package ... "
	ssh "$rep_host" "mkdir -p \"${snap_dir}\""
	publish_pkg "${tmpdir}/${pkgsnapfile}.gz" "${snap_bin_rep}"
	# cp "${tmpdir}/${pkgsnapfile}.gz" "$HOME"

	echo "   * Cleaning Up ... "
	cd $HOME && cleanup "$tmpdir" && \
			cleanup "${pkgrep}/OCA${pkg}"

	echo "   * Success!"
	echo " - Done."
	echo
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
ver=`uname -r`
month=`date +%B_%Y`
dist="Solaris${ver}-${arch}"

rep_host="cvs.openca.org"
rep_dir="/repository/projects/${pkg}"
src_rep="$rep_host:/${rep_dir}/sources"
snap_rep="${rep_host}:${rep_dir}/snapshots/sources"
bin_rep="${rep_host}:${rep_dir}/snapshots/${month}/binaries/solaris/${dist}"
rel_bin_rep="${rep_host}:${rep_dir}/releases/v${ver}/binaries/solaris/${dist}"
date=`date +%Y%m%d`
os=`uname -s`-`uname -r`-`uname -p`

pkgname="OCA${pkg}"
pkgfile="OCA${pkg}-${os}.pkg"
pkgsnapfile="OCA${pkg}-SNAP-${date}-${os}.pkg"
pkgrelfile="OCA${pkg}-Unknown-${os}.pkg"
pkgrep="/var/spool/pkg"
ver=""

export CVSROOT=":ext:$USER@cvs.openca.org:/cvsroot/projects"
export CVS_RSH="ssh"

case "$2" in
	snap) 
		snap_dir="${rep_dir}/snapshots/${month}/binaries/solaris/${dist}"
		snap_bin_rep="${rep_host}:${snap_dir}"
		build_snap
		;;
	rel)
		ver=$3
		if [ "$ver" = "" ] ; then
			usage
		fi
		rel_dir="${rep_dir}/releases/v${ver}/binaries/solaris/${dist}"
		rel_bin_rep="${rep_host}:${rel_dir}"
		pkgrelfile="OCA${pkg}-${ver}-${os}.pkg"
		build_rel "$ver"
		;;
	*)
		usage
		;;
esac

exit 0
