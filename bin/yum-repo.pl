#!/usr/bin/perl

my $base="/export/home/repo";
my $srcdir="/repository/projects";

my @prjList = ("libpki", "openca-tools", "openca-base", "openca-ocspd",
		"openca-prqpd", "prqpd" );

my @osList = ("linux");

foreach $prj ( @prjList ) {
	print "PROJECT: $prj\n";

	foreach $os ( @osList ) {
		$subdir="releases/current/binaries/$os";

		$dir = "$srcdir/$prj/$subdir";

		if ( opendir ( DIR, "$srcdir/$prj/$subdir" ) ) {
			@dirList = grep /^([^.]+)/, readdir DIR;
			closedir ( DIR );
		} else {
			die "ERROR: can not read dir $srcdir/$prj/$subdir!";
		}

		print "$#dirList dirs found\n";

		for $i ( @dirList ) {
			( $dist, $distVer, $arch ) = ( $i =~
				/^([^\d]+)([\d\.]+)\-(.*)$/ );

			next if ( $dist eq "" );

			$arch = "i386" if ( $arch eq "i686" );

			print "DIST: $dist $distVer ($arch)\n";

			$dest = "$base/". lc($dist) . "/$distVer/$arch/";
			if ( ! -d "$dest" ) {
				print "CREATING DIR: $dest ... \n";
				$rc=`mkdir -p "$dest"`;
				if ( $? > 0 ) {
					print "ERROR: Can not create dir $dest\n";
				}
			}

			print "OPENDIR: $dir/$i\n";

			if ( opendir ( DIR, "$dir/$i") ) {
				@fileList = grep /^[^.]+.*\.rpm$/, readdir DIR;
				closedir ( DIR );

				print "FOUND: $#fileList @fileList\n";
				for $file ( @fileList ) {
					print "Copy: $dir/$i/$file -> $dest\n";
					$ret = `cp "$dir/$i/$file" "$dest"`;
					if ( $? > 0 ) {
						print "COPY ERROR: $file\n";
						exit 1;
					}
				}
			} else {
				print "Can not open $dir/$i\n";
			}
		}
	}
}


exit 0;
