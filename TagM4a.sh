#! /bin/sh
#
# Add M4a tags using AtomicParsley to all files in the directory.
#
# any error exits the script
set -e

export LC_ALL=en_US.UTF-8
dryrun=0
verbose=0
usebackup=0
maximumTrackNum=0
# default is to overwrite in place
overWrite=--overWrite

# echo "Starting with $*"

YEAR=
genre=""
grouping=""

usage()
{
cat << EOF
  -d        dryrun
  -v        verbose
  -b        backup originals
  -h        help
  -u        update to *temp* file, don't overwrite
  -D <num>  disk number (required)
  -N <num>  total disks (required)
  -Y YYYY   year (required)
  -g <str>  genre (Rock, Electronic, etc) (required) (called Genre at www.discogs.com)
  -G <str>  grouping ("Prog Rock, Rock", "Jazz, Fusion", etc) (required) (called Style at www.discogs.com)
  -a <str>  artist
  -c <str>  composer (defaults to artist)
  -A <str>  album
  -C <path> cover Art (default ../../cover.jpg)
  -T <num>  total tracks (m4a only)
  
EOF

}

#
# Show basic information
# used on error and dryruns
#
ShowBasics()
{
  echo "\tyear       (Y) = $YEAR"
  echo "\tartist     (a) = $artist"
  echo "\tcoverArt   (C) = $coverArt"
  echo "\tdiskNumber (D) = $diskNumber"
  echo "\tTotalDisks (N) = $totalDisks"
  echo "\tgenre      (g) = $genre"
  echo "\tgrouping   (G) = $grouping"
}

#
# Recover from backup (ORIG) if the 'usebackup' flag is set
#
recover()
{
  artist="$1"
  album="$2"
  
  ORIG="/Volumes/Music/Converted/Orig/$artist/$album"
  if [ $dryrun -eq 1 ]
  then
    echo "Recover from: $ORIG"
  else
    #
    # Recover originals if run more then one time
    # on the same directory
    #
    if [ -d "$ORIG" ]
    then
      echo
      echo "Recover originals: $ORIG"
      echo
      for track in *
      do
        [ -f "$ORIG/$track" ] && {
          sum1=$(sum "$ORIG/$track" | awk '{ print $1, $2}')
          sum2=$(sum "$track" | awk '{ print $1, $2}')
          [ "$sum1" != "$sum2" ] && {
            [ $dryrun -eq 1 ] && echo "Restore $ORIG/$track"
            cp "$ORIG/$track" .
          }
        }
      done
    fi
  fi

  mkdir -p "$ORIG"
}


#
# getopt farks up the options with spaces
# -G "this and that"
# becomes
# -G this and that
#
# args=$(getopt dha:c:D:A:C:T:N:Y:g:G: $*)
# if [ $? -ne 0 ]
# then
#   echo "Using error"
#   exit 1
# fi
# 
# set -- $args
# 
# echo "args is now $*"
# 
while [ $# -gt 0 ]
do
  # echo "Getopt $1"
  case "$1" in
  -d)
    dryrun=1
    shift
    ;;
  -b)
    usebackup=1
    shift
    ;;
  -v)
    verbose=1
    shift
    ;;
  -u)
    overWrite=""
    shift
    ;;
  -a)
    artist="$2"
    shift
    shift
    ;;
  -c)
    composer="$2"
    shift
    shift
    ;;
  -D)
    diskNumber="$2"
    shift
    shift
    ;;
  -N)
    totalDisks="$2"
    shift
    shift
    ;;
  -A)
    album="$2"
    # echo "Album: $album"
    shift
    shift
    ;;
  -C)
    coverArt="$2"
    # echo "coverArt: $coverArt"
    shift
    shift
    ;;
  -T)
    maximumTrackNum="$2"
    # echo "maximumTrackNum: $maximumTrackNum"
    shift
    shift
    ;;
  -Y)
    YEAR=$2
    # echo "YEAR=$YEAR"
    shift
    shift
    ;;
  -g)   # genre Rock, Electronic, etc
    genre="$2"
    # echo "genre=$genre"
    shift
    shift
    ;;
  -G)   # grouping "Prog Rock, Rock", "Jazz, Fusion", etc
    grouping="$2"
    # echo "grouping=$grouping"
    shift
    shift
    ;;
  * | -h)
    echo "Saw $1 as unknown arg"
    echo
    usage
    exit 99
    ;;
  esac
done

echo
echo ---------
echo
echo "Starting in $(pwd)"
echo "Dryrun is $dryrun"
echo
echo
echo

#
# Some basic defaults
# The results of running XLD leaves the
# files in <Artist>/<Album>/<filename>.m4a
# Copy the image for the cover from the original
# source files or from the internet and put it
# in the appropriate directory
# XLD Settings:
#   Output Format: Apple Lossless
#   Output Directory: /Volumes/Music/Converted
# File Naming
#   Custom: %a/%T/%n %t
#   <Rename>
# Batch
#   Preserve Directory Structure
#   Restrict files to open: wav aiff flac wv ape tta
#   Automatically split file with embedded cue sheet
# CDDB
#   Server: freedb.freedb.org:80
#   Path:   /~cddb/cddb.cgi
# Metadata
#   Embed cover art images into files
#   Scale large images when embedding
#   Scale longer side
#   Load following files in same folder as cover art
#     cover.jpg folder.jpg front.jpg
#  Set the Compilation flag  automatically
#  Preserve unknown metadata if possible
#
[ "$coverArt" = "" ] && coverArt=../../cover.jpg
[ "$artist" = "" ]   && artist=$(basename "$(dirname "$(pwd)")")
[ "$composer" = "" ] && composer="$artist"
[ "$album" = "" ]    && album=$(basename "$(pwd)")

#
# MacOS and Music.app specific.
# keep your data elsewhere, modify these tests
#
if [ "$album" = "" -o "$album" = '/' -o "$album" = "/Volumes" -o "$album" = "Music" -o "$album" = "Converted" ]
then
  echo "Album (A) is corrupt: $album"
  pwd
  exit 5
fi

[ $dryrun -eq 1 ] && ShowBasics

if [ "$YEAR" = "" \
      -o "$artist" = "" \
      -o "$coverArt" = "" \
      -o "$diskNumber" = "" \
      -o "$totalDisks" = "" \
      -o "$genre" = "" \
      -o "$grouping" = "" ]
then
  echo "Missing something:"
  ShowBasics
  usage
  exit 1
fi

if [ "$diskNumber" = "" -o $diskNumber -lt 1 -o $diskNumber -gt $totalDisks ]
then
  echo "Invalid Disk Number (D): $diskNumber"
  usage
  exit 7
fi

if [ ! -f "$coverArt" ]
then
  echo "No such file: $coverArt"
  usage
  exit 98
fi

# echo "artist     = $artist"
# echo "diskNumber = $diskNumber"
# echo "coverArt   = $coverArt"

#
# Doesn't work for multi-disk leading numbers '1-02 <filename>', etc.
#
totalTracks=$(/bin/ls *.m4a | wc -l | sed -e 's/ //g')
totalTracksCnt=$(expr $totalTracks '+' 0)
echo "Total Tracks = $totalTracks"

[ $maximumTrackNum -eq 0 ] && maximumTrackNum=$totalTracksCnt

totalFiles=$(/bin/ls | wc -l | sed -e 's/ //g')
totalFilesCnt=$(expr $totalFiles '+' 0)

if [ $totalFilesCnt -ne $totalTracksCnt ]
then
  echo "Files don't align: File $totalFilesCnt, m4a $totalTracksCnt"
  usage
  exit 1
fi

if [ $usebackup -eq 1 ]
then
  recover "$artist" "$album"
fi

for tracl in *.m4a
do
  [ $dryrun -eq 0 ] && echo && echo && echo Processing: $track

  [ $usebackup -eq 1 -a ! -f "$ORIG/$track" ] && cp "$track" "$ORIG"

  tracknum=$(echo $track | sed -e 's/\([0-9]*\)\(.*\)/\1/')
  if [ "$tracknum" = "" -o $tracknum -lt 1 -o $tracknum -gt $maximumTrackNum ]
  then
    echo "tracknum out of range: $tracknum, limit $maximumTrackNum"
    exit 1
  fi
  #
  # Strip leading digits and any leading spaces
  # Strip trailing extension
  #
  title=$(echo "$track" | sed -e 's/\([0-9\-]*\)//' -e 's/^ //' -e 's/^- //' -e "s/.m4a//")
  if [ "$title" = "" ]
  then
    echo "Title missing: $track"
    exit 2
  fi
  
  echo=
  n=
  [ $dryrun -eq 1 ] && echo=echo && n="\n\t"
  $echo AtomicParsley $n \
              "$track" "$n"\
              --title="$title"         "$n"\
              --tracknum=$tracknum/$maximumTrackNum \
              --disk=$diskNumber/$totalDisks    \
              --year=$YEAR                 \
              --artist="$artist"           \
              --composer="$composer"       \
              --albumArtist="$composer"    \
              --genre="$genre"         "$n"\
              --grouping="$grouping"       \
              --album="$album"             \
              --artwork="$coverArt"        \
              $overWrite

  if [ "$overWrite" = "" ]
  then
    mv *-temp-*.m4a "$track"
  fi

done

exit 0