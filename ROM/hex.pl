#!/usr/local/bin/perl
$num = $ARGV[0];
$filename = $ARGV[1];
open(FP,"$filename"); 
$data[4];
$data_sum[4];
$line=0;

while(<FP>){
	chomp($_);
	my $temp= '0b'.substr($_,0,8);
	my $value =oct($temp);
	$data[0] .= sprintf("%02X",$value);
	$data_sum[0] += $value;
	#printf ("%02X",$value);
	#print "    ";
	if($num>1){
	  my $temp= '0b'.substr($_,8,8);
	  my $value =oct($temp);
	  $data[1] .= sprintf("%02X",$value);
	  $data_sum[1] += $value;
	  #printf ("%02X",$value);
	  #print "    ";
	}
	if($num>2){
	  my $temp= '0b'.substr($_,16,8);
	  my $value =oct($temp);
	  $data[2] .= sprintf("%02X",$value);
	  $data_sum[2] += $value;
	  #printf ("%02X",$value);
	  #print "    ";
	}
	if($num>3){
	  my $temp= '0b'.substr($_,24,8);
	  my $value =oct($temp);
	  $data[3] .= sprintf("%02X",$value);
	  $data_sum[3] += $value;
	  #printf ("%02X",$value);
	  #print "    ";
	}

	$line++;
	#print $line;
	#print "\n";
}

$filename =~ s/\.(\w+)$//;
print "generating...";
while($num){
  $checksum = -($line + $data_sum[$num-1])& 0xff; 
  print $filename."_".$num.".hex ";
  open(FH,">".$filename."_".$num.".hex");
  printf FH (":%02X000000".$data[$num-1]."%02X\n",$line,$checksum);
  print FH (":00000001FF");
  close(FH);
  $num--;
}
print "\nThank you \n";







