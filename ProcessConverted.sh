#! /bin/sh
# SearchDiscogs.sh and TagM4a.sh are in /Volumes/Music
#
PATH=$PATH:/Volumes/Music
prog=$0

dryrun=
backup=
useTempFile=
Artist=
echo=

usage()
{
  echo "$prog [-d] [-b] [-u] [-A \"Artist\"] -- Directory"
  echo "    -b backup to Orig when running TagM4a.sh"
  echo "    -d dryrun - don't make any changes"
  echo "    -u - use temp files, don't overwrite in AtomicParsley"
  echo "    -A \"Artist\" force artist to always be named."
  echo "       forces any other artist named to become Performer"
  echo "$prog -- Directory"
  echo "$prog -d -A \"Stevie Wonder\" -- Directory"
  exit 1 
}

#
# getopt farks up the options with spaces
# -A "this and that"
# becomes
# -A this and that
#
# args=$(getopt dbhA: $*)
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
  -b)
    # must be -b because we pass it through to TagM4a.sh
    backup=-b
    shift
    ;;
  -d)
    # must be -d because we pass it through to TagM4a.sh
    dryrun=-d
    echo=echo
    shift
    ;;
  -u)
    useTempFile=-u
    shift
    ;;
  -A)
    Artist="$2"
    shift
    shift
    ;;
  --)
    shift
    break
    ;;
  * | -h)
    echo Unknown flag: $1
    usage
    ;;
  esac
done

#
# /Volumes/Music/Original has AIFF versions of files
# these are converted using XLD to m4a files and
# saved into /Volumes/Music/Converted
# Converted has albums with very long names
# laid out in the following format
# LongAlbumName/Artist/Album/m4a files
# the Album and Artist are used to lookup
# in Discogs.com the Year, Gener, and Grouping
#
CONVERTED_ROOT="/Volumes/Music/Converted"

ConvertedAlbumsRoot="$1"
Genre=
Grouping=
Year=

FetchCovers()
{
  parent=$(basename "$(pwd)")

  for Album in *
  do
    [ ! -d "$Album" ] && continue
    [ ! -f "$Album"/cover.jpg ] && {
      ln ../../Downloads/"$parent/$Album"/cover.jpg "$Album"/cover.jpg
      if [ $? -ne 0 ]
      then
        echo "Failed cover: $Album"
        exit 15
      fi
    }
  done
}

#
# Using SearchDiscogs.sh
# extract the Genre, Grouping and Year
# of the Artist with this Album name
#
setGenreGroupingYear()
{
  Artist="$1"
  Album="$2"

  [ "$dryrun" != "" ] && echo "setGenreGroupingYear - $Artist - $Album"

  if [ "$Artist" = "" -o "$Album" = "" ]
  then
    echo "Missing artist ($Artist) or Album ($Album)"
    exit 120
  fi

  #
  # Lifted from ValidateM4aTags.sh
  #
  Genre=
  Grouping=
  Year=

  Discogs=/tmp/data."$Artist"."$Album"
  SearchDiscogs.sh "$Artist" "$Album" > "$Discogs"

  Year=$(grep     Year     /tmp/data."$Artist"."$Album" | sed -e 's/Year=//')
  Genre=$(grep    Genre    /tmp/data."$Artist"."$Album" | sed -e 's/Genre=//')
  Grouping=$(grep Grouping /tmp/data."$Artist"."$Album" | sed -e 's/Grouping=//')

  if [ "$Genre" = "" -o "$Grouping" = "" -o "$Year" = "" ]
  then 
    echo "$Artist/$Album: Missing something, check $Discogs"
    echo "Failed to find Genre:    $Genre"
    echo "Failed to find Grouping: $Grouping"
    echo "Failed to find Year:     $Year"
    exit 22
    # ValidateM4aTags.sh - echo "echo \"$Artist/$Album: Year $Year; Group $Grouping; Genre $Genre\"" >> "$FIXUP/$Artist/Year-Group-Genre-$Album.sh"
  fi

  /bin/rm "$Discogs"

  Year=$((Year + 0))
  if [ $Year -eq 0 ]
  then
    echo "Missing Year for $Artist/$Album"
    exit 23
  else
    [ $Year -lt 1950 -o $Year -gt 2025 ] && {
      echo "Invalid Year $Year for $Artist/$Album"
      exit 24
    }
  fi

  [ "$dryrun" != "" ] && echo "ProcessArtistAlbum: $Song -- Year $Year; Group \"$Grouping\"; Genre \"$Genre\""
  #
  # End theft
  #

  if [ "$dryrun" != "" ]
  then
    echo Album: $Album
    echo Year:  $Year
    echo Genre: $Genre
    echo Grouping: $Grouping
  fi
}

TagM4aFiles()
{
  Artist="$1"
  Performer="$2"
  Album="$3"
  Disk="$4"
  totalDisks="$5"
  Cover="$6"
  totalTracks=$7

  #
  # Sanity check
  #
  [ ! -f "$Cover" ] && {
    echo "Missing $Cover"
    pwd
    echo -----------
    return 1
  }

  [ $totalDisks -ne 1 ] && Album="$Album [Disk $Disk]"

  [ "$dryrun" != "" ] && echo \
        TagM4a.sh $dryrun $backup $useTempFile -D $Disk -N $totalDisks -T $totalTracks \
              -g "$Genre" -G "$Grouping" -Y $Year \
              -A "$Album" \
              -a "$Performer" -c "$Artist" \
              -C "$Cover"

  TagM4a.sh $dryrun $backup $useTempFile -D $Disk -N $totalDisks -T $totalTracks \
        -g "$Genre" -G "$Grouping" -Y $Year \
        -A "$Album" \
        -a "$Performer" -c "$Artist" \
        -C "$Cover"

  if [ $? -ne 0 ]
  then
    echo Something is wrong with TagM4a.sh
    exit 1
  fi

  return 0
}

totalTracks=0

CountTracks()
{
  tracks=$(find . -name *.m4a | wc -l)
  totalTracks=$(expr $tracks '+' 1)
}

#
# For albums that come as multiple disks
# process the sub disk here
#
ProcessDisk()
{
  diskNum=$1
  totalDisks=$2
  diskName="$3"
  Cover="$4"

  cd "$diskName"
  if [ $? -ne 0 ]
  then
    echo "Failed to change to disk $diskName for album $Album"
    pwd
    exit 122
  fi

  basis="$(pwd)"

  CountTracks

  for Performer in *
  do
    # reset where we are for the next performer
    cd "$basis"

    # avoid cover.jpg files
    [ ! -d "$Performer" ] && continue
    cd "$Performer"
    if [ $? -ne 0 ]
    then
      echo "Failed to change directory"
      echo "$basis/$Performer"
      pwd
      exit 123
    fi

    cd *
    if [ $? -ne 0 ]
    then
      echo "Failed to cd to final directory"
      pwd
      exit 124
    fi

    Album=$(basename "$(pwd)")
    #
    # Use Genre as flag to avoid calling
    # Discogs.com API too often.
    # This is reset before we process each album
    # see main below.
    #
    [ "$Genre" = "" ] && setGenreGroupingYear "$Artist" "$Album"
    [ "$Artist" = "" ] && Artist="$Performer"
  
    TagM4aFiles "$Artist" "$Performer" "$Album" $diskNum $totalDisks "$Cover" $totalTracks
  done
}

ProcessMultipleDisks()
{
  Disc="Disc"
  [ -d "CD 1" ] && Disc="CD"

  totalDisks=$(/bin/ls | grep "$Disc" | wc -l)
  totalDisks=$(expr $totalDisks '+' 0)

  subDisksRoot="$(pwd)"
  for disk in $(seq 1 $totalDisks)
  do
    subdisk=$(echo "$Disc $disk")
    ProcessDisk $disk $totalDisks "$subDisksRoot/$subdisk" ../../../cover.jpg
  done
}

#
# Main
#

[ "$ConvertedAlbumsRoot" = "" ] && {
  echo "Usage: $0 <Root>"
  echo "Like: $0 \"Stevie Wonder - Discography [FLAC Songs] [PMEDIA]/\""
  exit 1
}

cd "$CONVERTED_ROOT/$ConvertedAlbumsRoot"
if [ $? -ne 0 ]
then
  echo "No Such Directory: $CONVERTED_ROOT/$ConvertedAlbumsRoot"
  exit 1
fi

FetchCovers

for LongAlbum in *
do
  cd "$CONVERTED_ROOT/$ConvertedAlbumsRoot"
  [ ! -d "$LongAlbum" ] && continue;

  cd "$LongAlbum"
  [ $? -ne 0 ] && {
    echo "Failed cd: $CONVERTED_ROOT/$ConvertedAlbumsRoot/$LongAlbum"
    pwd
    echo --------
    continue
  }

  #
  # Reset Genre, Grouping, Year for each album
  # This forces a call to SearchDiscogs.sh
  #
  Genre=""
  Grouping=""
  Year=""

  #
  # If we have multiple disks, process them
  # otherwise process this single disk
  #
  if [ -d "Disc 1" -o -d "CD 1" ]
  then
    ProcessMultipleDisks
  else
    ProcessDisk 1 1 "$(pwd)" ../../cover.jpg
  fi
done
