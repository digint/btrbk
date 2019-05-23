#!/usr/bin/perl
#
# Linux::ExtentsMap - Read and Manipulate List of Extents
#
# Copyright (C) 2014-2019 Axel Burri
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# ---------------------------------------------------------------------
# The official btrbk website is located at:
# https://digint.ch/btrbk/
#
# Author:
# Axel Burri <axel@tty0.ch>
# ---------------------------------------------------------------------
#
# Based on work from:
# Graham Cobb: https://github.com/GrahamCobb/extents-lists
# ---------------------------------------------------------------------

package Linux::ExtentsMap;

our $blocksize = 4096; # default blocksize

sub new
{
  my $class = shift;
  my $file = shift;

  my $self = {
    map => defined($file) ? filefrag_extentmap($file) : [],
  };
  bless $self, ref($class) || $class;
  return $self->merge;
}


# returns extents range (unsorted array of [start,end], inclusive) from FIEMAP ioctl
sub filefrag_extentmap($)
{
  my $file = shift || die;

  # NOTE: this returns exitstatus=0 if file is not found, or no files found
  my $ret = `find '$file' -xdev -type f -print0 | xargs -0 -r filefrag -vs`;
  return undef unless(defined($ret));
  return undef if($?);

  my @range;
  foreach (split(/\n/, $ret))
  {
    # get extents start / end
    push @range, [ $1, $2 ] if(/^\s*[0-9]+:\s*[0-9]+\.\.\s*[0-9]+:\s*([0-9]+)\.\.\s*([0-9]+):/);
    if(/block of ([0-9]+) bytes/) {
      die "filefrag reports blocksize=$1 (expected $blocksize) in: $file" if($1 ne $blocksize);
    }
  }
  return \@range;
}


sub total_blocks()
{
  my $self = shift;
  my $count = 0;
  foreach(@{$self->{map}}) {
    $count += ($_->[1] - $_->[0] + 1);
  }
  return $count;
}


sub size()
{
  my $self = shift;
  my $total_blocks = $self->total_blocks();
  return $total_blocks * $blocksize;
}


# merge sorted map
sub merge($)
{
  my $self = shift;
  my @merged;
  my $start = -1;
  my $end = -2;
  foreach (sort { $a->[0] <=> $b->[0] } @{$self->{map}})
  {
    if($_->[0] <= $end + 1) {
      # range overlaps the preceeding one, or is adjacent to it
      $end = $_->[1] if($_->[1] > $end);
    }
    else {
      push @merged, [ $start, $end ] if($start >= 0);
      $start = $_->[0];
      $end = $_->[1];
    }
  }
  push @merged, [ $start, $end ] if($start >= 0);
  $self->{map} = \@merged;
  return $self;
}


sub diff($)
{
  my $self = shift;
  my $l = $self->{map};
  my $r = (shift)->{map};
  my $i = 0;
  my $rn = scalar(@$r);
  my @diff;

  foreach(@$l) {
    my $l_start = $_->[0];
    my $l_end   = $_->[1];
    while(($i < $rn) && ($r->[$i][1] < $l_start)) { # r_end < l_start
      # advance r to next overlapping
      $i++;
    }
    while(($i < $rn) && ($r->[$i][0] <= $l_end)) { # r_start <= l_end
      # while overlapping, advance l_start
      my $r_start = $r->[$i][0];
      my $r_end   = $r->[$i][1];

      push @diff, [ $l_start, $r_start - 1 ] if($l_start < $r_start);
      $l_start = $r_end + 1;
      last if($l_start > $l_end);
      $i++;
    }
    push @diff, [ $l_start, $l_end ] if($l_start <= $l_end);
  }
  my $ret = { map => \@diff };
  bless $ret, ref($self);
  return $ret;
}

1;
