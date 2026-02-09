
#use strict 'vars';
#use strict 'refs';
#use strict 'subs';

my %myDefs;
my %myUnDefs;

##############################################################################
# main program!

my @files;
my $defs = 0;

    # parse command line arguments; 
my $arg;
while ($arg = shift @ARGV) {
	if ($arg =~ /^[\/-]U(\w+)$/) {
		$myUnDefs{$1} = 1;
		$defs++;
		}
	elsif ($arg =~ /^[\/-]D(\w+)$/) {
		$myDefs{$1} = 1;
		$defs++;
		}
	elsif ($arg =~ /^[\/-]D(\w+)=(\S*)/) {
		$myDefs{$1} = $2;
		$defs++;
		}
    elsif ($arg =~ /^[\/\-]\?/ || $arg =~ /^[\/\-]h(elp)?/i) {   
        print "Usage: stripIfDef [options] file [file ...]\n";   
        print "    file [file...]         The files strip ifdefs from\n";
        print "    /D<var>                Define 'var'\n";
        print "    /D<var>=<val>          Define 'var' to be 'val'\n";
        print "    /U<var>                Undefine 'var'\n";
        print "    /h[elp]                Help\n";    
        print "    /?                     Help\n";    
        exit(0);    
        }
    elsif ($arg =~ /^[\/\-]/) {
        print STDERR "Bad qualifier '$arg', use /? for help\n"; 
        exit(-1);   
        }   
    else {  
        if (!-f $arg) {
			print STDERR "Error: '$arg' not found or not a file\n";
			exit(-1);
			}
		elsif (!-w $arg) {
			print STDERR "Error: '$arg' not writable\n";
			exit(-1);
			}
		elsif ($arg !~ /\.(cpp|c|def|inc|asm|h|hpp|bat|pl|y)$/) {
			print STDERR "Warning: '$arg' not recognized file type, skiping\n";
			next;
			}
		push(@files, $arg);
        }   
    }

if ($defs == 0) {
	print STDERR "Error: No defines or undefines given, use /? for help\n"; 
	exit(-1);
	}
if (@files == 0) {
	print STDERR "Error: no files given, use /? for help\n"; 
	exit(-1);
	}
	


my $file;
foreach $file (@files) {
	stripIfDef($file);
	}

exit(0);

##############################################################################
# is 'var' defined.  return 1 if true, -1 if false, and 0 for I don't know.
sub isDefined {
	my ($var) = @_;
	return(defined($myDefs{$var}) - defined($myUnDefs{$var}));
}

##############################################################################
sub stripIfDef {
	my ($fileName) = @_;

	rename($fileName, "$fileName.orig") || die "Could not rename to $fileName.orig";
	open(INFILE, "$fileName.orig") || die "Could not open file $fileName.orig";
	open(OUTFILE, ">$fileName") || die "Could not open file $fileName for writing";


	my @stack;			# 1 means yes, 0 = means I dont know, 1 means no
	my $enable = 0;				
	my $modified = 0;
	while(<INFILE>) {
		if (/^(\s*#\s*if)(.*)/) {
			push(@stack, $enable);
			if ($enable >= 0) {
				my $front = $1;
				my $rest = $2;
				if ($rest =~ /^def\s+(\w+)/) {
					$enable = isDefined($1);
					}
				elsif ($rest =~ /^ndef\s+(\w+)/) {
					$enable = -isDefined($1);
					}
				elsif ($rest =~ /^(\s+[^\/]*)(.*)/) {
					my $origExp = $1;
					my $comment = $2;
					my $exp = evalExp($1);
					$modified |= ($exp ne $origExp);
					if ($exp eq '0') {
						$enable = -1;
					}
					elsif ($exp eq '1') {
						$enable = 1;
					}
					else {
						$enable = 0;
					}
					$_ = "$front$exp$comment\n";
					}
				else {
					$enable = 0
					}
				$modified |= $enable;
				print OUTFILE if ($enable == 0);
				}
			}
		elsif (/^\s*#\s*else/) {
			print OUTFILE if ($enable == 0);
			$enable = -$enable if (@stack == 0 || $stack[$#stack] >= 0);
			}
		elsif (/^\s*#\s*endif/)  {
			print OUTFILE if ($enable == 0);
			$enable = pop(@stack);
			}
		elsif ($enable >= 0) {
			print OUTFILE;
			}
		}

    close(INFILE);
    close(OUTFILE);

		# keep the file mod time if I have not changed it
	if (!$modified) {
		print STDERR "no change to $fileName\n";
		rename("$fileName.orig", $fileName) || die "Could not rename from $fileName.orig";
		}
	else {
		print STDERR "modifiying $fileName, original in $fileName.orig\n";
		}
}

##############################################################################
# evaluate a #if expression.  return 1 if true, -1 if false, and 0 for I don't know.
# 
# note that only handles 'defined' and ||, and && operators.  
#
sub evalExp {
    my ($exp) = @_; 

	my $origExp = $exp;
	#print "Evaluating '$origExp'\n";
	my $didSub = 0;

	#  expresions in  {} have been symbolically evaluated.
	$exp =~ s/\b(\w+)\b/{}$1/g;	 

		# substitute all the 'defined' operators,  {} surround 'unknown' things
	while ($exp =~ s/\{\} defined (\s*) \( (\s*) \{\} (\w+) (\s*) \)/{defined$1($2$3$4)}/x) {
		my $var = $3;
		#print "Got variable $var\n";
		if (defined($myDefs{$var})) {
			$exp =~ s/\Q{defined$1($2$3$4)}\E/{1}/;
			$didSub = 1;
		}
		elsif (defined($myUnDefs{$var})) {
			$exp =~ s/\Q{defined$1($2$3$4)}\E/{0}/;
			$didSub = 1;
		}
		#print "after subing defined($var) -> $exp\n";
	}

		# substitute all the variable names, 
	while ($exp =~ s/ \{\} (\w+)/{$1}/x) {
		my $val = $myDefs{$1}; 
		if (defined($val)) {
			$exp =~ s/\Q{$1}\E/{$val}/;
			$didSub = 1;
		}
		#print "after subing $val -> $exp\n";
	}

		# if we didn't substitute any variables, then bail	
		# Note this optimization also has the effect of keeping #if 0 expression
		# since these will have no variables that we are substituting
	return $origExp if (!$didSub);

	#print "Before Normalization '$exp'\n";

		# evaluate expression
	while(
		  ($exp =~ s/\( (\s*) \{ (\d+) \} (\s*) \)             	  /{$2}/xg) 			||	# () rules
		  ($exp =~ s/\( (\s*) \{ ([^}]*) \} (\s*) \)              /{($1$2$3)}/xg)		||

	      ($exp =~ s/\! (\s*) \{ 0 \}                             /{1}/xg) 				||	# ! rules
	      ($exp =~ s/\! (\s*) \{ \d+ \}                           /{0}/xg) 				||
	      ($exp =~ s/\! (\s*) \{ ([^}]*) \}                       /{!$1$2}/xg)			||

	      ($exp =~ s/\{ 0 \} (\s*) \&\& (\s*) \{ ([^}]*) \}       /{0}/xg)				||	# and rules
	      ($exp =~ s/\{ ([^}]*) \} (\s*) \&\& (\s*) \{ 0 \}       /{0}/xg)				||
	      ($exp =~ s/\{ ([^}]*) \} (\s*) \&\& (\s*) \{ \d+ \}     /{$1}/xg)				||
	      ($exp =~ s/\{ \d+ \} (\s*) \&\& (\s*) \{ ([^}]*) \}     /{$3}/xg)				||
	      ($exp =~ s/\{ ([^}]*) \} (\s*) \&\& (\s*) \{ ([^}]*) \} /{$1$2&&$3$4}/xg)		|| 

	      ($exp =~ s/\{ ([^}]*) \} (\s*) \|\| (\s*) \{ 0 \}       /{$1}/xg)				||	# or rules
	      ($exp =~ s/\{ 0 \} (\s*) \|\| (\s*) \{ ([^}]*) \}       /{$3}/xg)				||
	      ($exp =~ s/\{ \d+ \} (\s*) \|\| (\s*) \{ ([^}]*) \}     /{1}/xg)				||
	      ($exp =~ s/\{ ([^}]*) \} (\s*) \|\| (\s*) \{ \d+ \}     /{1}/xg)				||
	      ($exp =~ s/\{ ([^}]*) \} (\s*) \|\| (\s*) \{ ([^}]*) \} /{$1$2||$3$4}/xg)		|| 
		 0) {
		#print "EXP = $exp \n";
	}

	#print "Done eval $exp \n";

	$exp =~ s/[\{\}]//g;							# remove all {}s
	$exp =~ s/^\s*(\d+)\s*$/$1/;					# remove spaces in normalized result
	#print "returning '$exp' \n";
	return($exp);
}

