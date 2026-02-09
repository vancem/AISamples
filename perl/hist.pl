# a histograph utility, given a file of lines, print out histogram of counts of identical lines
#

my $outFile;
if ($ARGV[0] eq "-o") {
	$outFile = $ARGV[1];
	shift; shift;
	}

my $table = {};
while(<>) {
	$table->{$_}++;
}

my $lines = hist($table);

$outFile = '-' if ($outFile eq '');		# stdout
open(OUT, ">$outFile") || die "Could not open '$outFile'";
print OUT @$lines;
close OUT;
exit 0;



############################################################################
# given a table indexed by key whose values are counts, create a histograph
# and return it as a array of strings. 
#
sub hist {
	my ($table) = @_;
	my @ret;

	my $total = 0;
	my $uniqEntries = 0;
	my $singletons = 0;
	my @out;
	my ($key, $val, $line);
	while (($key,$val) = each %$table) {
		$key =~ s/\s*$//s;		# remove trailing space and newline if present
		$line = "$val|$key";
		push(@out, $line);
		$uniqEntries++;
		$singletons++ if ($val == 1);
		$total += $val;
	}

	@out = sort {$::b <=> $::a} @out;
	my $cum = 0;
	my @fields;
	my $ord = 1;
	push(@ret, " ord    count   %     cum%  val\n");
	foreach $line (@out) {
		@fields = split(/\|/, $line);
		$cum += $fields[0];
		$line = sprintf("%3d %8d %5.1f%% %5.1f%%  %s", $ord, $fields[0], $fields[0] * 100 / $total, $cum * 100 / $total, $fields[1]);
		push(@ret, $line, "\n");
		$ord++;
	}

	push(@ret, "\n");
	push(@ret, "There were $total entries\n");
	push(@ret, "There were $uniqEntries unique entries\n");
	push(@ret, "There were $singletons singletons\n");

	return \@ret;
}

