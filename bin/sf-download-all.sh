#!/bin/bash

project=$1
rel=$2

if [ "x$project" = "x" ] ; then
	echo
	echo "ERROR: Usage $0 <project> <rel>"
	echo
	exit 1;
fi

# Local host
sf_usr=openca
sf_acc=openca
# basedir=/mnt/big/Ftp/openca/projects
basedir=/repository

# Remote Host
host=frs.sourceforge.net
target=/home/frs/project/o/op/openca

echo "changing dir to $basedir..."
cd $basedir

# bin=`find $project/releases/v$rel/ -name '*.bin'`;
# rpm=`find $project/releases/v$rel/ -name '*.rpm'`;
# dmg=`find $project/releases/v$rel/ -name '*.dmg'`;
# tgz=`find $project/releases/v$rel/ -name '*.gz'`;

dir=$project

echo "Syncing $dir ... "
rsync -e ssh -avz $sf_usr,$sf_acc@$host:$target/$dir $dir

exit 0;
