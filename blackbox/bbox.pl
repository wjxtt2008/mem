#!/usr/bin/perl
#------------------------------------------------------------------------------ 
# bbox 
#	by Junxiang Wu
#	
#	April 6, 2014
#Function: generate LEF file from VHDL
#
#Usage:
#perl bbox.pl –option arg1 arg2 filename.vhd  
#perl bbox.pl –s width height filename.vhd; set specify the width and height directly (unit: um)
#perl bbox.pl –m addr data filename.vhd; if it’s a memory  block, provide with the address width and data width
#perl bbox.pl filename.vhd; in default, it will simply do a naïve calculation for the size based on number of ports.

#------------------------------------------------------------------------------

#	Retrieve command line argument and option
#
use strict;
use Getopt::Long;
my $standard = 2.4;
my @size;
my @memory;
GetOptions(
	'setsize=f{2}' => \@size, 
	'memory=i{2}' => \@memory
	)or die "Incorrect usage!\n";

if( (scalar(@size)>0) and (scalar(@memory)>0)){  
	die "Incorrect usage!\n";
}

my $file = $ARGV[0];

#	Read in the target file into an array of lines
open(inF, $file) or dienice ("file open failed");
my @data = <inF>;
close(inF);

#	Strip newlines
foreach my $i (@data) {
	chomp($i);
	$i =~ s/--.*//;		#strip any trailing -- comments
}

#	initialize counters
my $lines = scalar(@data);		#number of lines in file
my $line = 0;
my $entfound = -1;
my $cellname;

#	find 'entity' left justified in file
for ($line = 0; $line < $lines; $line++) {
	if ($data[$line] =~ m/^entity\s+((?:[a-z][a-z0-9_]*))/i) {
		$cellname = $1;
		#print "cellname:".$cellname."\n";
		$entfound = $line;
		$line = $lines;	#break out of loop
	}
}

# find 'end $file', so that when we're searching for ports we don't include local signals.
my $entendfound = 0;
$file =~ s/\.vhd$//;
for ($line = $entfound; $line < $lines; $line++) {
	if ($data[$line] =~ m/^end/i) {
		$entendfound = $line;
		$line = $lines;	#break out of loop
	}
}

#	if we didn't find 'entity' then quit
if ($entfound == -1) {
	print("Unable to instantiate-no occurance of 'entity' left justified in file.\n");
	exit;
}

#find opening paren for port list
$entendfound = $entendfound + 1;
my $pfound = -1;

for ($line = $entfound; $line < $entendfound; $line++) { #start looking from where we found module
	$data[$line] =~ s/--.*//;		#strip any trailing --comment

        if ($data[$line] =~ m/\(/) {		#0x28 is '('
		$pfound = $line;
                $data[$line] =~ s/.*\x28//;	#consume up to first paren
		$line = $entendfound;			#break out of loop
	}
}

#	if couldn't find '(', exit
if ($pfound == -1) {
	print("Unable to instantiate-no occurance of '(' after module keyword.\n");
	exit;
}

#collect port names
my @inport;
#my @inportnum;
my @inportstart;
my @inportend;

my @outport;
#my @outportnum;
my @outportstart;
my @outportend;

my $inportcount;
my $outportcount;


for ($line = $pfound; $line < $entendfound; $line++) {
	$data[$line] =~ s/--.*//;		#strip any trailing --comment
	#collect input ports
	if ($data[$line] =~ m/\s+(\w+)\s*:\s*IN\s+(.+)/i) 
	{
		push @inport, $1;
		#check if vector or not
		if($2 =~ m/std_logic_vector\s*\(\s*(\d+)\s*\w+\s*(\d+)\s*\)/i)
		{
			#print $1." ".$2."\n";
			push @inportstart, $1;
			push @inportend, $2;
			$inportcount+=$1-$2+1;
		}
		elsif($2 =~ m/std_logic/i){
			push @inportstart, 0;
			push @inportend, 0;
			$inportcount++;
		}
	}
	#collect output ports
	elsif ($data[$line] =~ /\s+(\w+)\s*:\s*OUT\s+(.+)/i) {
		push @outport, $1;
		#check if vector or not
		if($2 =~ m/std_logic_vector\s*\(\s*(\d+)\s*\w+\s*(\d+)\s*\)/i)
		{
			#print $1." ".$2."\n";
			push @outportstart, $1;
			push @outportend, $2;
			$outportcount+= $1-$2+1;
		}
		elsif($2 =~ m/std_logic/i){
			push @outportstart, 0;
			push @outportend, 0;
			$outportcount++;
		}

	}

}

#print $inportcount."inportcount\n";
#print $outportcount."outportcount\n";

#calculate Macro size 

my $width;
my $height;

my $default = (scalar(($inportcount+$outportcount)/2)) * $standard;

#mode setsize
if(scalar(@size)) {
	print "setsize width: ".@size[0]." height: ".@size[1]."\n";
	$width = (@size[0]>$default)? @size[0]: $default;
	$height = (@size[1]>$default)? @size[1]: $default;
}
#mode memory
elsif(scalar(@memory)) {
	print "memory addr_width: ".@memory[0]." data_width: ".@memory[1]."\n";
	$width = @memory[1]*$standard;

	my $addr = @memory[0];
	$height = (1<<$addr)* $standard;
}
#default
else{
	$height = $default;
	$width = $default;
}

#print size
print "Macro width:".$width." height:".$height."\n";
#write to output LEF file
open (outF,">".$cellname.".lef");
print outF "VERSION 5.5 ;\n";
print outF "NAMESCASESENSITIVE ON ;\n";
print outF "BUSBITCHARS \"[]\" ;\n";
print outF "DIVIDERCHAR \"/\" ;\n\n";

print outF "MACRO ".$cellname."\n";
print outF " CLASS BLOCK ;\n";
print outF " ORIGIN 0 0 ;\n";
print outF " FOREIGN ".$cellname." 0 0 ;\n";
print outF " SIZE ".$width." BY ".$height." ;\n";
print outF " SYMMETRY X Y R90 ;\n";

my $x= 0.81;
my $y=$height - 0.81;

#print inputs pins
for(my $i = 0; $i < scalar(@inport); $i++) {
	if(@inportstart[$i]==0) {
		print outF " PIN ".@inport[$i]." \n";
		print outF "  DIRECTION INPUT ;\n";
		print outF "  USE SIGNAL ;\n";
		print outF "  PORT\n";
		print outF "   LAYER metal1 ;\n";
		print outF "    RECT 0 ".$y." 0.27 ".($y+0.27)." ;\n";
		print outF "  END\n";
		print outF " END ".@inport[$i]."\n";

		$y -= 0.81;
	}
	else {
		for(my $j = @inportstart[$i]; $j >= @inportend[$i]; $j--) {
					print outF " PIN ".@inport[$i]."[".$j."]\n";
					print outF "  DIRECTION INPUT ;\n";
					print outF "  USE SIGNAL ;\n";
					print outF "  PORT\n";
					print outF "   LAYER metal1 ;\n";
					print outF "    RECT 0 ".$y." 0.27 ".($y+0.27)." ;\n";
					print outF "  END\n";
					print outF " END ".@inport[$i]."[".$j."]\n";

					$y -= 0.81;
		}
	}
}
#print output pins
for(my $i = 0; $i < scalar(@outport); $i++) {
	if(@outportstart[$i]==0) {
		print outF " PIN ".@outport[$i]." \n";
		print outF "  DIRECTION OUTPUT ;\n";
		print outF "  USE SIGNAL ;\n";
		print outF "  PORT\n";
		print outF "   LAYER metal1 ;\n";
		print outF "    RECT ".$x." 0 ".($x+0.27)." 0.27 ;\n"; 
		print outF "  END\n";
		print outF " END ".@outport[$i]."\n";

		$x += 0.81;
	}
	else {
		for(my $j = @outportstart[$i]; $j >= @outportend[$i]; $j--) {
					print outF " PIN ".@outport[$i]."[".$j."]\n";
					print outF "  DIRECTION OUTPUT ;\n";
					print outF "  USE SIGNAL ;\n";
					print outF "  PORT\n";
					print outF "   LAYER metal1 ;\n";
					print outF "    RECT ".$x." 0 ".($x+0.27)." 0.27 ;\n"; 
					print outF "  END\n";
					print outF " END ".@outport[$i]."[".$j."]\n";

					$x += 0.81;
		}
	}
}
#print obstacles from metal1 to metal10 
print outF " OBS\n";
print outF "  LAYER metal1 ;\n";
print outF "   RECT 0.27 0.27 ".$width." ".$height." ;\n";

for(my $i = 2; $i <= 10; $i++ ){
	print outF "  LAYER metal".$i." ;\n";
	print outF "   RECT 0 0 ".$width." ".$height." ;\n";
	#print "   RECT 0.27 0.27 ".$width." ".$height." ;\n";
}
print outF " END\n";
print outF "END ".$cellname."\n";
print outF "END LIBRARY\n";

print $cellname.".lef generated. Thank you!\n";
exit;

#------------------------------------------------------------------------------ 
# Generic Error and Exit routine 
#------------------------------------------------------------------------------

sub dienice {
	my($errmsg) = @_;
	print"$errmsg\n";
	exit;
}


