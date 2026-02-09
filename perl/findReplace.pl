# 
#use strict 'vars';
#use strict 'refs';
#use strict 'subs';

################################################################
# these are the things you may want to change from run to run

my $verbose = 0;    # print out more detailed information
my $showLines = 0;  # show the updated lines
my $noupdate = 0;   # don't update files, just check out and show what you would do
my $recursive = 1;  # decend into subDirectories
my $checkout = 1;   # try to check out the file
my @subs;           # from/to pairs to look for

    # Only file names matching this pattern will be considered
my $fileIncludePat = "\\.((cpp)|c|(hpp)|h|(asm)|(cs)|(cool))\$";

    # directory names matching this pattern will be excluded
my $dirExcludePat = "^(obji)|(objd)|(obj)|(checked)|(free)\$";

# this gets called for the line in every file, should return
# true if it modified the line
sub doLine {
    # $_[0] is the first argument, which is the line to be modified
    my $modified = 0;

        # add as many of these as you need
#   $modified = 1 if ($_[0] =~ s/\bcallvirt\b/CALLVIRT/g);

        # do command line subsitutions
    my $sub = 0;
    while ($sub < @subs) {
        my $from = $subs[$sub];
        my $to   = $subs[$sub+1];
        $sub +=2;
        $modified = 1 if ($_[0] =~ s/\b\Q$from\E\b/$to/g);
        }

    return($modified)
}

################################################################
# main program, parse args and go

push(@ARGV, "/?") if (@ARGV == 0);      # no arguments, print help

my $arg;
while ($arg = shift @ARGV) {
    if($arg =~ /^[\/\-]v(erbose)?/i && @ARGV) {   
        $verbose = 1;
        $showLines = 1;
        }   
    elsif($arg =~ /^[\/\-]noupdate/i && @ARGV) {     
        $noupdate = 1;
        }   
    elsif($arg =~ /^[\/\-]nocheckout/i && @ARGV) {     
        $checkout = 0;
        }   
    elsif($arg =~ /^[\/\-]rec/i && @ARGV) {     
        $recursive = 1;
        }   
    elsif($arg =~ /^[\/\-]s\/([^\/]+)\/([^\/]*)\//i && @ARGV) {     # /s/FROM/TO/ 
        push(@subs, $1);    				# push from pattern 
        push(@subs, $2);            		# push the 'to' string
        }   
    elsif($arg =~ /^[\/\-]norec/i && @ARGV) {     
        $recursive = 0;
        }   
    elsif($arg =~ /^[\/\-]showlines/i && @ARGV) {     
        $showLines = 1;
        }   
    elsif ($arg =~ /^[\/\-]\?/ || $arg =~ /^[\/\-]h(elp)?/i) {   
        print "Performs a global search and substitute\n";
        print "\n";
        print "findReplace.pl /s/<from>/<to>/ [/<option>]* [paths]\n";    
        print "    paths            Files or directories to update\n";
        print "    /s/<from>/<to>/  substitute the word <from> with <to> no metaChars\n";
        print "    /noupdate        Just print out what you would do\n";
        print "    /showlines       print the changed lines\n";
        print "    /norec           Don't Recurse into directories that follow\n";
        print "    /rec             Turn recurse back on for rest of command line\n";
        print "    /nocheckout      Don't try to check out the file if read only\n";
        print "    /v               Verbose\n";
        print "    /?               Quick Help\n";
		print "Original files samed in <fileName>.orig\n";
		print "Multiple /s commands are allowed\n";
		print "Only complete words are matched (thus Foo does not match FooBar)\n";
		print "Only files with .cpp .c .hpp .h .asm .java suffixes are affected\n";
		print "By default, if the file is read only, a vssCheckout is attempted\n";
		print "Directories objd obj obji checked free are excluded\n";
        exit(0);    
        }   
    elsif ($arg =~ /^[\/\-]/) {     
        die "Bad qualifier '$arg', use /? for help\n";  
        }   
    else {  
        if (-d $arg) {
            doDir($arg);
            }
        elsif (-f $arg) {
            doFile($arg);
            }
        else {
            printf STDERR "ERROR: $arg not a file or a directory\n";
            }
        }
    }
exit(0);

################################################################
# process one file 
sub doFile {
    my ($fileName) = @_;

    print "Processing $fileName\n" if ($verbose);

    if (!open(FILE, $fileName)) {
        printf STDERR "ERROR: Could not open file $fileName\n";
        return;
        }
    my $lines = [];
    @$lines = <FILE>;   # read every line in the file
    close(FILE);

        # see if we touch this file at all
    my $modified = 0;
    my $lineNum = 0;
    my $line;
    foreach $line (@$lines) {
        $lineNum++;
        if (doLine($line)) {
            $modified = 1;
            print "$fileName ($lineNum): $line" if ($showLines);
            }
        }

    return if (!$modified);
    if ($noupdate) {
        print STDERR "Will Update $fileName\n";
        return;
        }

    my $oldModTime = modTime($fileName);
    if ($checkout && !-w $fileName) {
        print STDERR "File $fileName is read-only attempting a checkout\n";
        system("sd edit $fileName > NUL: 2>1");
        }

    if (!-w $fileName) {
        print STDERR "ERROR: $fileName is read-only, could not check out, skipping\n";
        return;
        }

    if (modTime($fileName) != $oldModTime) {
        print STDERR "WARNING new version checked out, you will need to resync!\n";
        doFile($fileName);      # try again
        return;
        }

    unlink("$fileName.orig");
    if (!rename($fileName, "$fileName.orig")) {
        printf STDERR "ERROR: Could not rename file $fileName\n";
        return;
        }

        # write out the new file
    if (!open(OUTFILE, ">$fileName")) {
        printf STDERR "ERROR: Could not open file $fileName for writing, original in $fileName.orig\n";
        return;
        }

    print OUTFILE @$lines;
    close(OUTFILE);
    print STDERR "Updating   $fileName\n";
}

################################################################
# process one directory 

sub doDir {
    my ($dirName) = @_;

    opendir(DIR, $dirName);
    my @names = grep(!/^\.\.?$/, readdir(DIR));
    closedir(DIR);

    my $name;
    foreach $name (@names) {
        next if ($name =~ /^\.\.?/);    # skip . and ..
        my $fullName = "$dirName\\$name";
        if (-d $fullName && $recursive && $name !~ /$dirExcludePat/)  {
            doDir($fullName);
            }
        if ($name =~ /$fileIncludePat/) {
            doFile($fullName);
            }
        }
}

################################################################
sub modTime {
    my ($fileName) = @_;
    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks);
    (($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($fileName)) || return(undef);
    return($mtime);
}

