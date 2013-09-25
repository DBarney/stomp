#!/bin/bash
## graphtest.sh -- by Patsie
# Draw a graph using an ASCII graph function
# The graph will have a width equal to the number of data points
# and a height equal to the first argument
# Usage: graphtest.sh

## Should the graph move from right to left or vice versa
right_to_left=1

## include graphing function
. ./graph.fnc


## starting value, fill graph data
val=100000
data=`for i in $(seq 60); do echo $((val+=RANDOM%1000-500)); done`

i=0
clear

## repeat 100 times
while [ $((i++)) -lt 100 ]; do
  ## Go to top left corner and print date
  printf "\e[H`date`\n"

  ## Add new datapoint to graph
  if [ $right_to_left -eq 1 ]; then
    val=$(echo $data | awk '{print $NF}')
    data=$(echo $data $((val+=RANDOM%1000-500)) | cut -d' ' -f2-60)
  else
    val=$(echo $data | awk '{print $1}')
    data=$(echo $((val+=RANDOM%1000-500)) $data | cut -d' ' -f1-59)
  fi

  ## Draw graph and wait
  graph 9 $data
done