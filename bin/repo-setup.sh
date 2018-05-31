#!/bin/bash

rsync="/usr/bin/rsync"
repo="rsync://ftp.openca.org/repo"
log="/dev/null"
createrepo="/usr/bin/createrepo"
remotedir="$USER@ftp.openca.org:/export/home/"


destdir=$1
copy=$2
log=$3

if ! [ -z "$log" ] ; then
	if ! [ `echo $log | grep '^\/'` ] ; then
		log=`pwd`/$log
	fi
fi

if [ -z "$destdir" -o ! -d "$destdir" ] ; then
	echo
	echo "ERROR: $destdir is not a valid dest directory!"
	echo
	echo "  USAGE: $o <dir> [ copy ] [ logfile ]"
	echo
	exit 1;
fi

if ! [ -z "$log" ] ; then
	echo "Mirroring Repository Dir.. " > $log
else
	echo "Mirroring Repository Dir.. "
fi

if ! [ -z "$log" ] ; then
	$rsync -rztpv --delete "$repo" "$destdir" 2>&1 >$log
else
	$rsync -rztpv --delete "$repo" "$destdir"
fi

if ! [ -z "$log" ] ; then
	echo "Creating Repository Files.." > $log
else
	echo "Creating Repository Files.."
fi

cd "$destdir"
for i in */*/* ; do 
	# cachedir=""
	# cachedir="$i/../../.cachedir"
	# echo "CACHE: $cachedir"

	# if ! [ -d "$cachedir" ] ; then
	# 	echo mkdir -p $cachedir
	# fi

	if ! [ -z "$log" ] ; then
		# $createrepo -c ../../../.cachedir $i 2>&1 >$log
		$createrepo $i 2>&1 >$log
	else
		$createrepo $i
	fi
done

if [ "$copy" = "copy" ] ; then
	rsync -ax --delete "${destdir}" "${remotedir}"
fi

exit 0;
