#!/bin/bash

prj=$1
ver=$2
date=$3

tmpdir="$prj-update"
today=`date +%Y%m%d`

echo "PRJ = $prj ; VER = $ver ; DATE = $date"

case "$prj" in
	openca-base)
		dirlist="openca-base/src/common/lib/functions openca-base/src/common/lib/cmds"
		;;
	*)
		echo "Unsupported Project: $prj";
		exit 1;
esac

[ -d "$tmpdir" ] || mkdir -p "$tmpdir";

cd $tmpdir;

for i in $dirlist ; do
	subdir=`echo $i | sed -e 's|.*\/||g'`;
	# echo $subdir
	echo cvs rdiff -D $date -l -c $i $prj-$ver-$subdir-$today.patch ; 
done

exit 0;

