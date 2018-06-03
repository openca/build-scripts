#!/bin/bash

function usage {
	echo
	echo "  OpenCA Build Scripts - v0.9.0"
	echo "  (c) 2018 by Massimiliano Pala and OpenCA Labs"
	echo "  All Rights Reserved"
	echo ""
	echo "    USAGE: $0 <project> [ rel | snap ] \\"
	echo "                        <version> <option> <branch>"
	echo
	echo "  Where:"
	echo "  <project> .........: Project's Name (e.g. libpki)"
	echo "  <version> .........: Version of the project (e.g., 0.9.0)"
	echo "  <option> ..........: One of 'src' 'all' 'rpm' 'bin'"
	echo "  <branch> ..........: Repository's Branch to use for the build"
	echo
	echo "  Set USE_LOCAL_SCRIPTS='yes' to use local (same dir) scripts"
	echo "  instead of downloading them from the GIT repository."
	echo
}

os=`uname -s`
prj="$1"
rel="$2"
ver="$3"
opt="$4"
prj_branch="$5"

# if using github repos, please enable the following line
suffix=-github
tmpdir="/var/tmp"

# if [ -d "${HOME}/bin" ] ; then
# 	tmpdir="${HOME}/bin"
# else
# 	tmpdir="/var/tmp"
# fi

if [ "$os" = "Linux" ] ; then
	binlist="rpm bin"
	prefix="build-linux"
else 
	if [ "$os" = "SunOS" ] ; then
		binlist="bin pkg"
		prefix="build-solaris"
     	else 
		if [ "$os" = "Darwin" ] ; then
			binlist="bin"
			prefix="build-osx"
		else
			echo
			echo "ERROR: $os no supported!"
			echo
		fi
	fi
fi

case "$rel" in
	rel)
		;;
	snap)
		opt=$ver;
		ver="DATE";
		;;
	*)
		echo "ERROR: use rel or snap (used $rel)"
		usage;
		exit 1;
esac

if [ -z "$prj" -o -z "$rel" -o -z "$ver" ] ; then
	usage;
	exit 1;
fi

if [ -z "$opt" ] ; then
	opt="all";
fi

all="$binlist"

case "$opt" in
	all)
		list=$binlist;
		;;
	src)
		[ "x$prj_branch" = "x" ] && prj_branch="$4"
		prefix=build;
		list="$opt";
		;;
	*)
		o=`echo "$all" | grep "$opt"`
		if [ $? -gt 0 ] ; then
			echo "ERROR: $opt is not a valid option"
			usage;
			exit 1;
		fi
		list="$opt"
		;;
esac

# server='ftp.openca.org'
# scp $server:/repository/scripts/$filename "$tmpdir"

if [ "x$prj_branch" = "x" ] ; then
	branch="master"
else
	branch=$prj_branch
fi

if [ "x$USE_LOCAL_SCRIPTS" = "xyes" ] ; then
	BUILD_SCRIPTS_LOCAL=yes
else
	BUILD_SCRIPTS_LOCAL=no
fi

echo "[ BUILD: $list, VER: $ver, BRANCH: $branch, LOCAL: $BUILD_SCRIPTS_LOCAL ]"

for i in $list ; do
	filename="$prefix-$i${suffix}.sh"
	if [ "$BUILD_SCRIPTS_LOCAL" = "yes" ] ; then
		cp "$filename" "$tmpdir/$filename"
	else
		http_target="https://raw.githubusercontent.com/openca/build-scripts/$branch/bin/$filename"
		wget -q -O "$tmpdir/$filename" "$http_target"
	fi
	if [ -f "$tmpdir/$filename" ] ; then
		chmod +x "$tmpdir/$filename"
		"$tmpdir/$filename" "$prj" "$rel" "$ver" "$branch"
	else
		echo "ERROR: can not transfer $filename from server ($server)"
	fi
	# echo rm "$tmpdir/$filename"
done

exit 0;
