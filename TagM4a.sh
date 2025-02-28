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
# Recover from backup (ORIG) if the 'usebackup' flag is set
#
recover()
{
  artist="$1"
  album="$2"
  
  ORIG="/Volumes/Music/Converted/Orig/$artist/$album"
  [ $dryrun -eq 1 ] && {
    echo "Recover from: $ORIG"
    return
  }

  #
  # Recover originals if run more then one time
  # on the same directory
  #
  if [ -d "$ORIG" ]
  then
    echo
    echo "Recover originals: $ORIG"
    echo
    for f in *
    do
      [ -f "$ORIG/$f" ] && {
        sum1=$(sum "$ORIG/$f" | awk '{ print $1, $2}')
        sum2=$(sum "$f" | awk '{ print $1, $2}')
        [ "$sum1" != "$sum2" ] && {
          [ $dryrun -eq 1 ] && echo "Restore $ORIG/$f"
          cp "$ORIG/$f" .
        }
      }
    done
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
    TotalDisks="$2"
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
    totalTracks="$2"
    # echo "totalTracks: $totalTracks"
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
# echo "Dryrun => $dryrun"
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

if [ "$YEAR" = "" \
      -o "$artist" = "" \
      -o "$coverArt" = "" \
      -o "$diskNumber" = "" \
      -o "$TotalDisks" = "" \
      -o "$genre" = "" \
      -o "$grouping" = "" ]
then
  echo "Missing something:"
  echo "\tyear       (Y) = $YEAR"
  echo "\tartist     (a) = $artist"
  echo "\tcoverArt   (C) = $coverArt"
  echo "\tdiskNumber (D) = $diskNumber"
  echo "\tTotalDisks (N) = $TotalDisks"
  echo "\tgenre      (g) = $genre"
  echo "\tgrouping   (G) = $grouping"
  usage
  exit 1
fi

if [ "$diskNumber" = "" -o $diskNumber -lt 1 -o $diskNumber -gt $TotalDisks ]
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
TotalTracks=$(/bin/ls *.m4a | wc -l | sed -e 's/ //g')
TotalTracksCnt=$(expr $TotalTracks '+' 0)
echo "Total Tracks = $TotalTracks"

TotalFiles=$(/bin/ls | wc -l | sed -e 's/ //g')
TotalFileCnt=$(expr $TotalFiles '+' 0)

if [ $TotalFileCnt -ne $TotalTracksCnt ]
then
  echo "Files don't align: File $TotalFileCnt, m4a $TotalTracksCnt"
  usage
  exit 1
fi

if [ $usebackup -eq 1 ]
then
  recover $artist $album
fi

for f in *.m4a
do
  [ $dryrun -eq 0 ] && echo && echo && echo Processing: $f

  [ $usebackup -eq 1 -a ! -f "$ORIG/$f" ] && cp "$f" "$ORIG"

  tracknum=$(echo $f | sed -e 's/\([0-9]*\)\(.*\)/\1/')
  if [ "$tracknum" = "" -o $tracknum -lt 1 -o $tracknum -gt $TotalTracksCnt ]
  then
    echo "tracknum out of range: $tracknum"
    exit 1
  fi
  #
  # Strip leading digits and any leading spaces
  # Strip trailing extension
  #
  title=$(echo "$f" | sed -e 's/\([0-9]*\)//' -e 's/^ //' -e 's/^- //' -e "s/.m4a//")
  if [ "$title" = "" ]
  then
    echo "Title missing: $f"
    exit 2
  fi
  
  echo=
  n=
  [ $dryrun -eq 1 ] && echo=echo && n="\n\t"
  $echo AtomicParsley $n \
              "$f" "$n"\
              --title="$title"         "$n"\
              --tracknum=$tracknum/$TotalTracks \
              --disk=$diskNumber/$TotalDisks    \
              --year=$YEAR                 \
              --artist="$artist"           \
              --composer="$composer"       \
              --albumArtist="$artist"      \
              --genre="$genre"         "$n"\
              --grouping="$grouping"       \
              --album="$album"             \
              --artwork="$coverArt"        \
              --overWrite
done

exit 0