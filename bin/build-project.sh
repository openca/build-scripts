#!/bin/bash

function usage {
	echo
	echo "    USAGE: $0 <project> [ rel | snap ] <version> <option>"
	echo
	echo "  Where <command> is one of all $binlist src"
	echo " $prj, $rel, $ver, $opt"
	echo
}

server="ftp.openca.org"
os=`uname -s`
prj="$1"
rel="$2"
ver="$3"
opt="$4"

# if using github repos, please enable the following line
suffix=-github

if [ -d "${HOME}/bin" ] ; then
	tmpdir="${HOME}/bin"
else
	tmpdir="/var/tmp"
fi

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

echo "OPT: $opt"

case "$opt" in
	all)
		list=$binlist;
		;;
	src)
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

for i in $list ; do
	filename="$prefix-$i${suffix}.sh"
	scp $server:/repository/scripts/$filename "$tmpdir"
	if [ -f "$tmpdir/$filename" ] ; then
		chmod +x "$tmpdir/$filename"
		"$tmpdir/$filename" "$prj" "$rel" "$ver"
	else
		echo "ERROR: can not transfer $filename from server ($server)"
	fi
	# echo rm "$tmpdir/$filename"
done

exit 0;
