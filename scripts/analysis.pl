#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long qw(:config pass_through);
use XML::Simple;
use List::Util qw(max sum);
use List::MoreUtils qw(uniq);
use Text::CSV;
use Data::Dumper;

my $usage = q~Usage:
  analysis.pl [--out=<csv file>] [--plot=<html file>] [--include=<csv files>] <xml files> [...]
~;

my $outfile;
my $plotfile;
my @include;
GetOptions( "out=s" => \$outfile,
            "plot=s" => \$plotfile,
            "include=s" => \@include);

if(scalar(@ARGV) < 1 and !@include) { print $usage; exit; }

if($outfile and $outfile !~ /\.csv$/) {
  $outfile .= ".csv";
}
if($plotfile and $plotfile !~ /\.html$/) {
  if($plotfile =~ /\.htm$/) {
    $plotfile .= "l";
  } else {
    $plotfile .= ".html";
  }
}

# read in all the xml files
my $tree = [];
my @files;
foreach(@ARGV) {
  push(@files, glob);
}
foreach(sort(uniq(@files))) {
  push(@$tree, new XML::Simple->XMLin($_));
}

# grab the info we want from the xml files
my @data;
my $total_error = 0;
foreach my $report (@$tree) {
  $report->{DatasetInformation}->{Filename} =~ /^(\w+)/;
  my $granule = $1;
  if($granule =~ /^(.*)(_SIGMA)$/) {
    $granule = $1; #uuurrrggghhh
  }
  if($report->{PointTargetAnalysisReport} and $report->{PointTargetAnalysisReport}->{CornerReflectorPTAResults}) {
    my @reflectors;
    if(ref($report->{PointTargetAnalysisReport}->{CornerReflectorPTAResults}) eq 'ARRAY') {
      @reflectors = @{$report->{PointTargetAnalysisReport}->{CornerReflectorPTAResults}};
    } else {
      @reflectors = ($report->{PointTargetAnalysisReport}->{CornerReflectorPTAResults});
    }
    foreach my $ref (@reflectors) {
      my $ref_xoff = $ref->{GeolocationOffsetIn_X_Meter};
      my $ref_yoff = $ref->{GeolocationOffsetIn_Y_Meter};
      my $ref_error = sprintf("%.5f", sqrt($ref_xoff**2 + $ref_yoff**2));
      $total_error += $ref_error;
      push(@data, [
        $granule,
        $report->{DatasetInformation}->{OrbitDir},
        $ref->{ReflectorNumber},
        max($report->{DatasetInformation}->{RngPxSize}, $report->{DatasetInformation}->{AzPxSize}),
        $ref->{Resolution_X_from_Neg3db_Width_Meter},
        $ref->{PSLR_X_left_dB},
        $ref->{PSLR_X_right_dB},
        $ref->{Resolution_Y_from_Neg3db_Width_Meter},
        $ref->{PSLR_Y_left_dB},
        $ref->{PSLR_Y_right_dB},
        $ref->{ImagePosition_X_ofPointTarget},
        $ref->{ImagePosition_Y_ofPointTarget},
        $ref_xoff * $report->{DatasetInformation}->{RngPxSize},
        $ref_yoff * $report->{DatasetInformation}->{AzPxSize},
        $ref_xoff,
        $ref_yoff,
        $ref_error]);
    }
  }
}

# grab any extra csv data
foreach(@include) {
  foreach(glob) {
    my $csv = Text::CSV->new();
    open (CSV, "<", $_) or die $!;
    while (<CSV>) {
        if ($csv->parse($_)) {
            my @columns = $csv->fields();
            if($columns[0] !~ /^(Scene Name|Average|Standard Deviation|RMSE|CE95)/i and $columns[0] !~ /^\s*$/) { # ignore headers and footers
              push @data, [@columns];
            }
        } else {
            my $err = $csv->error_input;
            print "Failed to parse line: $err";
        }
    }
    close CSV;
  }
}

# spit out some csv
my $csv = '';
my @header = (["Scene Name", "Orbit Direction", "Corner Reflector", "Resolution", "Resolution X from -3db Width (Meters)", "PSLR X left dB", "PSLR X right dB", "Resolution Y from -3db Width (Meters)", "PSLR Y left dB" ,"PSLR Y right dB", "X Pos", "Y Pos", "X Offset (Pixels)", "Y Offset (Pixels)", "X Offset (Meters)", "Y Offset (Meters)", "Total Error (Meters)"]);
my @footer = (
  ['Average', '', '', '',
    mean(map($_->[4], @data)), mean(map($_->[5], @data)), mean(map($_->[6], @data)),
    mean(map($_->[7], @data)), mean(map($_->[8], @data)), mean(map($_->[9], @data)),
    '', '',
    mean(map($_->[12], @data)), mean(map($_->[13], @data)),
    mean(map($_->[14], @data)), mean(map($_->[15], @data)),
    mean(map($_->[16], @data))],
  ['Standard Deviation', '', '', '',
    std_dev(map($_->[4], @data)), std_dev(map($_->[5], @data)), std_dev(map($_->[6], @data)),
    std_dev(map($_->[7], @data)), std_dev(map($_->[8], @data)), std_dev(map($_->[9], @data)),
    '', '',
    std_dev(map($_->[12], @data)), std_dev(map($_->[13], @data)),
    std_dev(map($_->[14], @data)), std_dev(map($_->[15], @data)),
    std_dev(map($_->[16], @data))],
  ['RMSE', '', '', '', '', '', '', '', '', '', '', '',
    sqrt(mean(map($_->[12] ** 2, @data))), sqrt(mean(map($_->[13] ** 2, @data))),
    sqrt(mean(map($_->[14] ** 2, @data))), sqrt(mean(map($_->[15] ** 2, @data))),
    sqrt(mean(map($_->[14] ** 2 + $_->[15] ** 2, @data)))],
  ['CE95', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', sqrt(3) * sqrt(mean(map($_->[14] ** 2 + $_->[15] ** 2, @data)))]);
foreach my $row (@header, @data, @footer) {
  $csv .= join(',', @$row) . "\n";
}

if($outfile) {
  open(OUT, ">$outfile");
  print OUT $csv;
  close(OUT);
}

if($plotfile) {
  open(PLOT_OUT, ">$plotfile");
  print PLOT_OUT get_plot_html(@header, @data);
  close(PLOT_OUT);
}

if(!$outfile and !$plotfile) {
  print $csv;
}

exit;


sub mean {
  return sum(@_) / @_;
}

sub std_dev {
  my $mean = mean(@_);
  my $sqtotal = 0;
  foreach(@_) {
    $sqtotal += ($mean - $_) ** 2;
  }
  return sqrt($sqtotal / scalar(@_));
}

sub ingest_csv {
  my $file = shift;
  my @data;
  return @data;
}

sub get_plot_html {
  my $template = q~<html>
  <head>
    <script type="text/javascript" src="https://www.google.com/jsapi"></script>
    <script type="text/javascript">
      var raw_data = [/***plot_data***/];
      
      google.load("visualization", "1.0", {packages:['corechart', 'table']});
      google.setOnLoadCallback(drawCharts);
      
      function drawCharts() {
        // build a data table with our data
        var data = google.visualization.arrayToDataTable(raw_data);
        var formatter = new google.visualization.NumberFormat({fractionDigits: 5});
        formatter.format(data, 4);
        formatter.format(data, 5);
        formatter.format(data, 6);
        formatter.format(data, 7);
        formatter.format(data, 8);
        formatter.format(data, 9);
        formatter.format(data, 12);
        formatter.format(data, 13);
        formatter.format(data, 14);
        formatter.format(data, 15);
        formatter.format(data, 16);
        
        // set up the spreadsheet
        var spreadsheet = new google.visualization.Table(document.getElementById('spreadsheet'));
        spreadsheet.draw(data, null);
        
        // set up a view for labels
        var labels = new google.visualization.DataView(data);
        
        
        // set up the asc/desc-grouped plots
        var asc_view = new google.visualization.DataView(data);
        asc_view.setRows(asc_view.getFilteredRows([{column: 1, minValue: "ASCENDING", maxValue: "ASCENDING"}]));
        asc_view.setColumns([14, 15, {}]);
        
        var desc_view = new google.visualization.DataView(data);
        desc_view.setRows(desc_view.getFilteredRows([{column: 1, minValue: "DESCENDING", maxValue: "DESCENDING"}]));
        desc_view.setColumns([14, 15]);
        
        var ascdesc_table = new google.visualization.data.join(asc_view, desc_view, 'full', [[0,0]], [1], [1]);
        ascdesc_table.setColumnLabel(1, 'Ascending');
        ascdesc_table.setColumnLabel(2, 'Descending');
        
        var ascdesc_options = {
          title: 'Geolocation Offsets Grouped by Orbit Direction',
          hAxis: {title: 'X Offset (meters)'},
          vAxis: {title: 'Y Offset (meters)'},
          legend: {position: 'right'},
          maximize: 1
        };
        var ascdesc_plot = new google.visualization.ScatterChart(document.getElementById('ascdesc_plot'));
        ascdesc_plot.draw(ascdesc_table, ascdesc_options);
        
        // set up the reflector-grouped plot
        var reflector_view = new google.visualization.DataView(data);
        reflector_view.setColumns([14, 15]);
        var reflector_options = {
          title: 'Geolocation Offsets Grouped by Reflector',
          hAxis: {title: 'X Offset (meters)'},
          vAxis: {title: 'Y Offset (meters)'},
          legend: {position: 'right'},
          maximize: 1
        };
        var reflector_plot = new google.visualization.ScatterChart(document.getElementById('reflector_plot'));
        reflector_plot.draw(reflector_view, reflector_options);
        
        // set up the granule-grouped plot
        var granule_view = new google.visualization.DataView(data);
        granule_view.setColumns([14, 15]);
        var granule_options = {
          title: 'Geolocation Offsets Grouped by Granule',
          hAxis: {title: 'X Offset (meters)'},
          vAxis: {title: 'Y Offset (meters)'},
          legend: {position: 'right'},
          maximize: 1
        };
        var granule_plot = new google.visualization.ScatterChart(document.getElementById('granule_plot'));
        granule_plot.draw(granule_view, granule_options);
      }
    </script>
  </head>
  <body>
    <div id="ascdesc_plot" style="width: 900px; height: 500px;"></div>
    <div id="reflector_plot" style="width: 900px; height: 500px;"></div>
    <div id="granule_plot" style="width: 900px; height: 500px;"></div>
    <div id="spreadsheet"></div>
  </body>
</html>
~;
  
  my $js_array_rows = '';
  $js_array_rows = join(',', map({'[' . join(',', map({$_ =~ /[a-z]/i ? "\"$_\"" : $_} @$_)) . ']'} @_));
  $template =~ s/\/\*\*\*plot_data\*\*\*\//$js_array_rows/;
  return $template;
}