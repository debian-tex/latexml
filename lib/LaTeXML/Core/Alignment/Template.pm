# /=====================================================================\ #
# |  LaTeXML::Core::Alignment                                           | #
# | Support for tabular/array environments                              | #
# |=====================================================================| #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #
package LaTeXML::Core::Alignment::Template;
use strict;
use warnings;
use base qw(LaTeXML::Common::Object);
use LaTeXML::Global;
use LaTeXML::Common::Object;
use LaTeXML::Core::Token;
use LaTeXML::Core::Tokens;

sub new {
  my ($class, %data) = @_;
  $data{columns}       = [] unless $data{columns};
  $data{repeating}     = 1 if $data{repeating} || $data{repeated};
  $data{repeated}      = [] unless $data{repeated};
  $data{non_repeating} = scalar(@{ $data{columns} });
  $data{save_before}   = [] unless $data{save_before};
  $data{save_between}  = [] unless $data{save_between};    # between comes before before!

  map { $$_{empty} = 1 } @{ $data{columns} };
  map { $$_{empty} = 1 } @{ $data{repeated} };
  return bless {%data}, $class; }

sub revert {
  my ($self) = @_;
  return @{ $$self{tokens} }; }

# Methods for constructing a template.

sub setReversion {
  my ($self, @tokens) = @_;
  $$self{tokens} = [@tokens];
  return; }

sub setRepeating {
  my ($self) = @_;
  $$self{repeating} = 1;
  return; }

# These add material before & after the current column
sub addBeforeColumn {
  my ($self, @tokens) = @_;
  unshift(@{ $$self{save_before} }, @tokens);    # NOTE: goes all the way to front!
  return; }

# NOTE: \lx@column@trimright should ONLY be added to LaTeX tabular style templates!!!!
# NOT \halign style templates!
sub addAfterColumn {
  my ($self, @tokens) = @_;
  $$self{current_column}{after} = Tokens(T_CS('\lx@column@trimright'),
    @tokens, @{ $$self{current_column}{after} });
  return; }

# Or between this column & next...
sub addBetweenColumn {
  my ($self, @tokens) = @_;
  my @cols = @{ $$self{columns} };
  if (my $col = $$self{current_column}) {
    if (!$$self{disabled_intercolumn}) {
      unshift(@tokens, T_CS('\lx@intercol')); }
    $$self{current_column}{after} = Tokens(@{ $$self{current_column}{after} }, @tokens); }
  else {
    push(@{ $$self{save_between} }, @tokens); }
  return; }

sub disableIntercolumn {
  my ($self) = @_;
  if (my $col = $$self{current_column}) {
    $$self{disabled_intercolumn} = 1; }
  return; }

sub addColumn {
  my ($self, %properties) = @_;
  my $col = {%properties};
  if (my $prev = $$self{current_column}) {
    $$prev{after} = Tokens(($$prev{after} || ()), T_CS('\lx@intercol'))
      unless $$self{disabled_intercolumn}; }
  my @before = ();
  push(@before, @{ $$self{save_between} }) if $$self{save_between};
  push(@before, T_CS('\lx@intercol')) unless $$self{disabled_intercolumn};
  delete $$self{disabled_intercolumn};

  push(@before, $properties{before}->unlist) if $properties{before};
  push(@before, @{ $$self{save_before} })    if $$self{save_before};
  $$col{before} = Tokens(@before);
  my @after = ();
  push(@after, T_CS('\lx@column@trimright'));
  push(@after, $properties{after}->unlist) if $properties{after};
  $$col{after}           = Tokens(@after);
  $$col{thead}           = $properties{thead};
  $$col{empty}           = 1;
  $$self{save_between}   = [];
  $$self{save_before}    = [];
  $$self{current_column} = $col;

  if ($$self{repeating}) {
    $$self{non_repeating} = scalar(@{ $$self{columns} });
    push(@{ $$self{repeated} }, $col); }
  else {
    push(@{ $$self{columns} }, $col); }
  return; }

sub finish {
  my ($self) = @_;
  if (my $prev = $$self{current_column}) {
    $$prev{after} = Tokens(($$prev{after} || ()), T_CS('\lx@intercol'))
      unless $$self{disabled_intercolumn}; }
  return; }

# Methods for using a template.
sub clone {
  my ($self) = @_;
  my @dup = ();
  foreach my $cell (@{ $$self{columns} }) {
    push(@dup, {%$cell}); }
  return bless { columns => [@dup],
    repeated  => $$self{repeated}, non_repeating => $$self{non_repeating},
    repeating => $$self{repeating} }, ref $self; }

sub show {
  my ($self) = @_;
  my @strings = ();
  push(@strings, "\nColumns:\n");
  foreach my $col (@{ $$self{columns} }) {
    push(@strings, "\n{" . join(', ', map { "$_=>" . Stringify($$col{$_}) } sort keys %$col) . '}'); }
  if ($$self{repeating}) {
    push(@strings, "\nRepeated Columns:\n");
    foreach my $col (@{ $$self{repeated} }) {
      push(@strings, "\n{" . join(', ', map { "$_=>" . Stringify($$col{$_}) } sort keys %$col) . '}'); } }
  return join(', ', @strings); }

sub column {
  my ($self, $n) = @_;
  my $N = scalar(@{ $$self{columns} });
  if (($n > $N) && $$self{repeating}) {
    my @rep = @{ $$self{repeated} };
    if (my $m = scalar(@rep)) {
      for (my $i = $N ; $i < $n ; $i++) {
        my %dup = %{ $rep[($i - $$self{non_repeating}) % $m] };
        push(@{ $$self{columns} }, {%dup}); } } }
  return ($n > 0 ? $$self{columns}->[$n - 1] : undef); }

sub columns {
  my ($self) = @_;
  return @{ $$self{columns} }; }

#======================================================================
1;
