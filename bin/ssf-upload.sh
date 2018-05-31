#!/bin/bash

project=$1
rel=$2

if [ "x$project" = "x" ] ; then
	echo
	echo "ERROR: Usage $0 <project> <rel>"
	echo
	exit 1;
fi

if [ "x$rel" = "x" ] ; then
	echo
	echo "ERROR: Usage $0 <project> <rel>"
	echo
	exit 1;
fi

sf_usr=openca
sf_acc=openca
basedir=/repository/projects
host=shell.sourceforge.net
target=/home/frs/project/o/op/openca

echo "changing dir to $basedir..."
cd $basedir

bin=`find $project/releases/v$rel/ -name '*.bin'`;
rpm=`find $project/releases/v$rel/ -name '*.rpm'`;
dmg=`find $project/releases/v$rel/ -name '*.dmg'`;
tgz=`find $project/releases/v$rel/ -name '*.gz'`;

for i in $tgz $bin $rpm $dmg ; do
	echo "Transferring $i ... "
	rsync -e ssh $i $sf_usr,$sf_acc@$host:$target/$i
done

exit 0;
