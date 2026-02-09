#use strict 'vars';
#use strict 'subs';
#use strict 'refs';

	my $list = [];
    my $du = du(".");
    flattenDu($du, 10000, $list);
	if (@$list == 0) {
		push (@$list, du);
	}

	printf("Inclusive  Exclusive       Directory\n");
	printf("  size        size\n");
	printf("---------------------------------------------------------------------------\n");
	foreach $du (sort { $b->{'inclusiveSize'} <=> $a->{'inclusiveSize'} } @$list) {
		printf("%7.2fM : %6.2fM : %s\n",
			$du->{'inclusiveSize'} / 1000000, $du->{'exclusiveSize'} / 1000000, $du->{'name'});
	}
	exit 0;


###############################################################################
# pretty print the 'du' structure below
sub flattenDu {
    my ($du, $minSize, $list) = @_;

	if ($du->{'inclusiveSize'} <= $minSize) {
		#print "Min size - returning\n";
		return;
	}

	my $children = $du->{'children'};
	push(@$list, $du);
	my $child;
	foreach $child (@$children) {
		flattenDu($child, $minSize, $list);
	}
}


###############################################################################
# given a directory name, compute a list of structures describing the disk usage 

sub du {
    my ($dirName) = @_;
	#print "Doing du $dirName\n";

	my $ret;
    if (!opendir(DIR, $dirName)) {
		printf STDERR "Node $dirName is not a directory\n";
		return $ret;
	}
    my @names = grep(!/^\.\.?$/, readdir(DIR));
    closedir(DIR);

	$ret = {};
	$ret->{'name'} = $dirName;
	$ret->{'exclusiveSize'} = 0;
	$ret->{'inclusiveSize'} = 0;
	
	my $children = [];

    my $name;
    foreach $name (sort(@names)) {
		my $fullName = "$dirName\\$name";
		#print "Got $name fullName $fullName \n";
		if (-f $fullName) {
			my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($fullName);  
			$ret->{'exclusiveSize'}+= $size;
			$ret->{'inclusiveSize'}+= $size;
		}
		elsif (-d $fullName) {
			my $child = du($fullName);
			$ret->{'inclusiveSize'} += $child->{'inclusiveSize'};
			push(@$children, $child);
		}
	}

	#print "Got size incl = $ret->{'inclusiveSize'} excl = $ret->{'exclusiveSize'} for $ret->{'name'}\n";
	$ret->{'children'} = $children;
	return $ret;
}

