#!/usr/bin/env python
#############################################
# NAME: setconfig.py
# VERSION: 2.0
# PURPOSE: convert braces formatted JUNOS config to "set" commands
#          and print them to stdout
# Author: Francis Luong (Franco) - @francisluong - http://about.me/francisluong
#
# LICENSE: http://opensource.org/licenses/MIT
# Copyright (c) 2013 Francis Luong
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#############################################

#read in filepath from commandline
from sys import argv
import os 
if len(argv) < 2:
  print "Usage: {} <filepath>".format(argv[0])
  exit()
filepath = argv[1]

#open filepath for reading
f = open(filepath, "r")

from string import whitespace as ws
current_path = []
deactivate_on_pop = []

def traverse_juniper_config( filehandle, current_path ):
  lineorig = filehandle.readline()
  #EOF check
  if len(lineorig) == 0:
    return "-1"
  line = lineorig.strip()

  ### ignore version and commented lines - return current_path
  if current_path == [] and line.startswith("version "):
    return current_path
  elif line.startswith('#'):
    return current_path
  #else: ---> continue

  ### detect if line starts with inactive and set a flag if so
  #     also, remove 'inactive: ' from the head of the line
  if line.startswith("inactive: "):
    inactive = True
    parts = line.split(' ')
    line = " ".join(parts[1:])
  else:
    inactive = False

  current_path_joined = " ".join(current_path)

  ###if line ends in ';', join/print 
  if line.endswith(";"):
    out_text = "{} {}".format(current_path_joined, line.rstrip(";"))
    if inactive:
      print "deactivate {}".format(out_text)
    else:
      print "set {}".format(out_text)

  ###elif line ends in '}', remove last element of current_path
  elif line.endswith("}"):
    removed = current_path.pop()
    #add a deactivate statement if we match the top of the deactivate on pop stack
    if len(deactivate_on_pop) > 0:
      deactivate_if_match = deactivate_on_pop.pop()
      if removed == deactivate_if_match:
        out_text = "deactivate {}".format(current_path_joined)
        print out_text
      else:
        deactivate_on_pop.append(deactivate_if_match)
      

  ###elif line ends in '{', update current_path and recurse
  elif line.endswith("{"):
    line_stripped = line.rstrip(ws + "{")
    current_path.append(line_stripped)
    if inactive:
      deactivate_on_pop.append(line_stripped)
    current_path = traverse_juniper_config( filehandle, current_path )

  return current_path

#iterate through file until EOF
while current_path != "-1":
  current_path = traverse_juniper_config( f, current_path )


