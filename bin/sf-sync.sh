#!/bin/bash

project=$1
target=$2
rel=$3
opt=$4

sf_usr=openca
sf_acc=openca
basedir=/repository
host=frs.sourceforge.net
oca_prefix=/home/frs/project/openca
prj_prefix=

function usage() {
	echo
	echo "ERROR: Usage $0 <project> [ rel <version> | snap ]"
	echo
	exit 1;
}

if [ "x$project" = "x" -o "x$target" = "x" ] ; then
	usage;
fi

case "$target" in
  rel)
      if [ "x$rel" = "x" ] ; then
        echo
        echo "ERROR: Missing '<version>' parameter"
        echo
        usage
      else 
        if ! [ -d "$basedir/$project/releases/v${rel}" ] ; then
          echo
          echo "ERROR: Missing local directory:"
          echo
          echo "       $basedir/$project/releases/v${rel}"
          echo
          usage
        fi
      fi
    ;;
  snap)
    ;;
  default)
    echo
    echo "Missing 'target' parameter"
    echo
    usage
    ;;
esac

case "$project" in
  libpki) prj_prefix=/home/frs/project/libpki
    ;;
  default) prj_target=
    ;;
esac

echo "changing dir to $basedir..."
cd $basedir

if [ "x$target" = "xrel" ] ; then
  local_prefix=${basedir}/${project}/releases/v${rel}
  remote_prefix=${project}/releases
else
  local_prefix=${basedir}/${project}/snapshots
  remote_prefix=${project}
fi

echo "Syncing $dir ... "

# OpenCA Sync
ssh "$sf_usr"@"$host" mkdir -p "$oca_prefix/$remote_prefix"
rsync -e ssh -avz "$local_prefix" "$sf_usr"@"$host":"$oca_prefix/$remote_prefix"

# Project Specific
if ! [ "x$prj_target" = "x" ] ; then
  ssh "$sf_usr"@"$host" mkdir -p "$prj_prefix/$remote_prefix"
  rsync -e ssh -avz "$local_prefix" "$sf_usr"@"$host":"$prj_prefix/$remote_prefix"
fi

exit 0;
