#!/bin/bash

#### Functions Section #################################################

function push_scripts () {
	host=$1
	shift
	tmp=$1

	for((i=0;i<$#;i++)); do
		shift
		scp -q "${basedir}/$1" "$host":"${tmp}/"
	done
}

function remote_exec () {
	host=$1
	shift
	ssh "$host" $@
}

function remote_clean () {
	host=$1
	shift

	for((i=0;i<$#;i++)); do
		ssh "$host" rm "$1"
	done
}

function get_snap () {

	prj="$1"
	host="$2"

	# Push the upload script
	push_scripts "$host" "${tmpdir}" "mm-upload-snap.sh"
	remote_exec "$host" "${tmpdir}/mm-upload-snap.sh" "$prj"
	remote_clean "$host" "${tmpdir}/mm-upload-snap.sh"

}

function build_solaris_snap () {
	prj="$1"
	host="$2"
	script="$3"

	# Push the right build script
	push_scripts "$host" "${tmpdir}" "${script}"
	remote_exec "$host" "${tmpdir}/${script}" "${prj}" "snap"
	remote_clean "$host" "${tmpdir}/${script}"
}

function build_linux_snap () {
	prj="$1"
	host="$2"
	script="$3"

	# Push the right build script
	push_scripts "$host" "${tmpdir}" "${script}"
	remote_exec "$host" "${tmpdir}/${script}" "${prj}" "snap"
	remote_clean "$host" "${tmpdir}/${script}"
}

#### Main Section #####################################################

prjs=libpki
basedir="/repository/scripts"
tmpdir="/tmp"

for o in $prjs ; do
	# get_snap "$o" "mm.cs.dartmouth.edu"

	echo "Building Linux Package on mm.cs.dartmouth.edu..."
	build_linux_snap "$o" "mm.cs.dartmouth.edu" "build-linux-rpm.sh"
	echo

	echo "Building Solaris Package on pki.openca.org..."
	build_solaris_snap "$o" "pki.openca.org" "build-solaris-pkg.sh"
	echo

	# echo "Building Solaris Package on hope.cs.dartmouth.edu..."
	# build_solaris_snap "$o" "hope.cs.dartmouth.edu" "build-solaris-pkg.sh"
	# echo

	# echo "Building Solaris Package on sulfuric.cs.dartmouth.edu..."
	# build_solaris_snap "$o" "sulfuric.cs.dartmouth.edu" "build-solaris-pkg.sh"
	# echo

	echo "Building Solaris Package on os11.cs.dartmouth.edu..."
	build_solaris_snap "$o" "os11.cs.dartmouth.edu" "build-solaris-pkg.sh"
	echo

	echo "Building Solaris Package on marty.cs.dartmouth.edu..."
	build_solaris_snap "$o" "marty.cs.dartmouth.edu" "build-solaris-pkg.sh"
	echo

	# echo "Building Solaris Package on marty.cs.dartmouth.edu..."
	# build_bsd_snap "$o" "devil.cs.dartmouth.edu" "build-bsd-pkg.sh"
	# echo

	# echo "Building Solaris Package on niky.cs.dartmouth.edu..."
	# build_solaris_snap "$o" "niky.cs.dartmouth.edu" "build-solaris-pkg.sh"
	# echo

done

exit 0;
