#! /bin/sh
#
# Script to force the Grouping of any album's files
# to be that found in Discogs.com
#
if [ "$1" = "" -o "$2" = "" ]
then
  echo "Missing Artist($1) or Disk Name ($2)"
  exit 1
fi

cd /Volumes/Music/Music_link
if [ $? -ne 0 ]
then
  echo "missing symlink /Volumes/Music/Music_link to Music/iTunes/iTunes Media/Music"
  exit 4
fi

if [ ! -d "$1" ]
then
  echo "No such Artist ($1)"
  exit 2
fi

if [ ! -d "$1/$2" ]
then
  echo "No such Disk ($2)"
  exit 3
fi

Grouping=$(/Volumes/Music/SearchDiscogs.sh "$1" "$2" | grep Grouping | sed -e 's/Grouping=//')

if [ "$Grouping" = "" ]
then
  echo "Failed to fetch grouping for $1/$2"
  exit 5
fi

cd "$1/$2"
for f in *.m4a
do
  AtomicParsley "$f" --grouping="$Grouping" -overWrite
done