#! /bin/bash
#
# Validate the M4A tags we know about in the files specified
#          Usage: $0 <artist> <album> <track>
# if no args are present, process across all Artists in the current
# directory recursively for all albums and songs.
#
# Output: /Volumes/Music/Fixup/<files>.sh
# which are processed by PatchArt.sh and ApplyFixes.sh
#

# TODO
# 1 - need to escape special chars in $track (like $)
# 2 - Manage file names with multiple spaces. ?? Flag them and do nothing?
# 3 - need to escape ` when echoing track names
#

MUSICROOT="/Volumes/Music"
MUSIC="$MUSICROOT/Music/iTunes/iTunes Media/Music"
FIXUP="$MUSICROOT/Fixup"
LANG=en_US.UTF-8

mkdir -p "$FIXUP"

usage()
{
  echo "Usage: $0 [-v] [-v] [-o] [-m] [-d] [-b basedir] -- <artist> <album> <track>"
  echo "-m   - find .m4a files from the current directory and check tags"
  echo "-v   - set verbose level, may be releated to increase verbosity"
  echo "-o   - set the --overWrite flag for AtomicParsley"
  echo "-b   - set the basedir to start searching"
  echo "-d   - dryrun; show what will happen without doing anything"
  echo "       only works with -m"
  echo "<artist> - the artist to process"
  echo "<album>  - the <artist>/<album> to check"
  echo "<track>  - the specific track <album>/<artist>/<track>"
  exit 1
}

verbose=0
overwrite=0
m4aFilesOnly=0
dryrun=0

while [ $# -gt 0 ]
do
  # echo "Getopt $1"
  case "$1" in
  "--")
      shift
      break
      ;;
  "-v")
      verbose=$((verbose + 1))
      shift
      ;;
  "-o")
      overwrite=1
      shift
      ;;
  "-b")
      basedir="$2"
      shift
      shift
      ;;
  "-m")
      m4aFilesOnly=1
      shift
      ;;
  "-d")
      dryrun=1
      shift
      ;;
  * | -h)
      echo "Unknown flag: $1"
      usage
      ;;
   esac
done

[ $m4aFilesOnly -eq 0 -a ! -d "$basedir/$1" ] && usage

Year=
Genre=
Grouping=

namValid=0
trknValid=0
diskValid=0
totalDiskValid=0
dayValid=0
ARTValid=0
wrtValid=0
aARTValid=0
genValid=0
grpValid=0
albValid=0
covrValid=0
totalCover=0

resetTags()
{
  namValid=0
  trknValid=0
  diskValid=0
  totalDiskValid=0
  dayValid=0
  ARTValid=0
  wrtValid=0
  aARTValid=0
  genValid=0
  grpValid=0
  albValid=0
  covrValid=0
  totalCover=0
}

CheckFailed()
{
	echo "[ \$? -ne 0 ] && {"                               >> "$FIXUP/$artist/$album.sh"
	echo "echo rename failed for \"$artist/$album/$track\"" >> "$FIXUP/$artist/$album.sh"
	echo "exit 1"                                           >> "$FIXUP/$artist/$album.sh"
	echo "}"                                                >> "$FIXUP/$artist/$album.sh"
}

doMove()
{
  # sadly using basename farks up too often.
  # base=$(basename "$track" .m4a)
  #	echo mv \"$base\"-temp-*.m4a \"$track\" >> "$FIXUP/$artist/$album.sh"
  echo "mv *-temp-*.m4a \"$track\""         >> "$FIXUP/$artist/$album.sh"
}

extractTags()
{
	albumPath="$1"
  track="$2"

 	[ $verbose -ge 2 ] && echo "extractTags $artist/$album/$track"

  #
  # Avoid sub-shell. The pipe loses the export of variables to the 'parent'
  # and things go poorly after that.
  #
  # AtomicParsley "$track" --textdata | sed -e 's/"//g' | grep "Atom" | egrep -v -e '----' | while read tag
  # doesn't work.....
  #
  [ $verbose -ge 2 ] && echo "AtomicParsley $track --textdata"

  AtomicParsley "$track" --textdata > /tmp/rawdata
  [ $? -ne 0 ] && {
  	echo ""
  	echo ""
  	echo "        AtomicParsley failed on $artist/$album/$track"
  	echo "echo AtomicParsley failed on $artist/$album/$track" >> $FIXUP/AtomicParsleyFailures.sh
  	echo "AtomicParsley \"$albumPath/$track\" --textdata" >> $FIXUP/AtomicParsleyFailures.sh
  	echo ""
  	echo ""
  	return
  }

  cat /tmp/rawdata | sed -e 's/"//g' | grep "Atom" | egrep -v -e '----' > /tmp/lines
  /bin/rm -f /tmp/rawdata

  while read tag
  do
    # Atom "©nam" contains: I Gotta Have A track (Single Version ／ Mono)
    # Atom "trkn" contains: 27 of 27
    # Atom "disk" contains: 2 of 3
    # Atom "©day" contains: 2019
    # Atom "©ART" contains: Stevie Wonder
    # Atom "©wrt" contains: Stevie Wonder
    # Atom "aART" contains: Stevie Wonder
    # Atom "©gen" contains: Funk / Soul
    # Atom "©grp" contains: Soul
    # Atom "©alb" contains: Mono Singles (Disc 2)
    # Atom "covr" contains: 1 piece of artwork
    set $tag
    [ $verbose -ge 3 ] && echo "Process $2"
    case $2 in
    cpil|pgap|tmpo|©too|soal|soar) continue
      ;;
    "©nam") namValid=1
      ;;
    "trkn") trknValid=1
      ;;
    "disk") diskValid=1
      echo "$tag" | grep 'of' > /dev/null && totalDiskValid=1
      ;;
    "©day") dayValid=1
      ;;
    "©ART") ARTValid=1
      ;;
    "©wrt"|*wrt) wrtValid=1
      ;;
    "aART") aARTValid=1
      ;;
    "©gen"|gnre) genValid=1
      ;;
    "©grp") grpValid=1
      ;;
    "©alb") albValid=1
      ;;
    "covr") covrValid=1
      totalCover=$4
      ;;
    *)
    	[ $verbose -gt 2 ] && {
				echo "File: $artist/$album/$track"
				echo "    Unknown tag $2"
				echo "    $tag"
			}
			;;
    esac
  done < /tmp/lines
  /bin/rm /tmp/lines
}

FixupSong()
{
	albumPath="$1"
	album="$2"
	track="$3"
	AP_Flags="$4"

  escAlbumPath=$(echo $albumPath | sed -e 's/"/\\\\"/g')
  escAlbum=$(echo $album | sed -e 's/"/\\\\"/g')

	[ $verbose -ge 1 ] && echo "FixupSong $artist/$album/$track into \"$FIXUP/$artist/$escAlbum.sh\""
	
	[ $dryrun -eq 1 ] && return 0

	mkdir -p "$FIXUP/$artist"
	
  echo "cd \"$escAlbumPath\""      >> "$FIXUP/$artist/$escAlbum.sh"
  [ $overwrite -eq 1 ] && {
    echo "echo Processing \"$artist/$track\"" >> "$FIXUP/$artist/$escAlbum.sh"
    AP_Flags="$AP_Flags --overWrite"
  }

	[ "$verbose" -gt 1 ] && echo AtomicParsley \"$track\" $AP_Flags

	echo "AtomicParsley \"$track\" $AP_Flags"   >> "$FIXUP/$artist/$escAlbum.sh"

	[ $overwrite -eq 0 ] && doMove
	CheckFailed
	return 0
}

#
# For any MISSING tags, build up the AP_Flags to add that
# metadata to the file
#
BuildAPFlags()
{
	albumPath="$1"
	artist="$2"
  album="$3"
  track="$4"

	[ $verbose -gt 1 ] && echo "BuildAPFlags \"$artist\" \"$album\" \"$track\""

	# special case for skipping "artists"
	if [ "$artist" = "Ford Prefect" ]
	then
		return
	fi

	AP_Flags=""

  [ $diskValid -ne 1 ] && {
    AP_Flags="$AP_Flags --disk=1/1"
  }
  [ $totalDiskValid -ne 1 -a $diskValid -eq 1 ] && {
    AP_Flags="$AP_Flags --disk=1/1"
  }
  [ $ARTValid -ne 1 ] && {
    AP_Flags="$AP_Flags --artist=\"$artist\""
  }
  [ $wrtValid -ne 1 ] && {
    AP_Flags="$AP_Flags --composer=\"$artist\""
  }
  [ $aARTValid -ne 1 ] && {
    AP_Flags="$AP_Flags --albumArtist=\"$artist\""
  }
  # we might not know the year
  [ $dayValid -ne 1 -a "$Year" != "" ] && {
    AP_Flags="$AP_Flags --year=\"$Year\""
  }
  # we might not know the Genre
  [ $genValid -ne 1 -a "$Genre" != "" ] && {
    AP_Flags="$AP_Flags --genre=\"$Genre\""
  }
  # we might not know the Grouping
  [ $grpValid -ne 1 -a "$Grouping" != "" ] && {
    AP_Flags="$AP_Flags --grouping=\"$Grouping\""
  }
  [ $albValid -ne 1 ] && {
    AP_Flags="$AP_Flags --album=\"$album\""
  }
  [ $covrValid -ne 1 ] && {
  	mkdir -p "$FIXUP/$artist"
    echo "echo \"$track\": Cover art missing" >> "$FIXUP/$artist/CantFix-$album.sh"
  }
  [ $covrValid -eq 1 -a $totalCover -ne 1 ] && {
  	mkdir -p "$FIXUP/$artist"
    echo "echo \"$track\": TOO MANY cover art entries $totalCover" >> "$FIXUP/$artist/CantFix-$album.sh"
  }

	[ $trknValid -ne 1 ] && {
		totalTracks=$(/bin/ls *.m4a | wc -l)
		totalTracks=$((totalTracks + 0))
		tracknum=$(echo "$track" | sed -e 's/\([0-9]*\)\(.*\)/\1/')
		AP_Flags="$AP_Flags --tracknum=$tracknum/$totalTracks"
	}

	[ $namValid -ne 1 ] && {
		title=$(echo "$track" | sed -e 's/\([0-9]*\)//' -e 's/^ //' -e 's/^- //' -e "s/.m4a//")
		if [ "$title" = "" ]
		then
			echo "Title missing: $artist/$album/$track"
			exit 2
		fi
		AP_Flags="$AP_Flags --title \"$title\""
	}

  [ "$AP_Flags" != "" ] && FixupSong "$albumPath" "$album" "$track" "$AP_Flags"

	resetTags

	return 0
}

curArtist=""
curAlbum=""

processM4a()
{
	albumPath="$1"
	artist="$2"
  album="$3"
  track="$4"

	if [ $verbose -ge 1 -a "$artist" != "$curArtist" -o "$album" != "$curAlbum" ]
	then
		echo "$artist/$album"
	fi

	curAlbum="$album"
	curArtist="$artist"
	
  extractTags "$albumPath" "$track"
  BuildAPFlags "$albumPath" "$artist" "$album" "$track"
  return 0
}

#
# Process specific album by specified artist
# optionally just a single track
#
ProcessArtistAlbum()
{
  artist="$1"
	album="$2"
	track="$3"
            
  cd "$BASE/$artist"

  if [ $? -ne 0 ]
  then
    echo "No such artist: $artist"
    exit 1
  fi

  cd "$album"
  if [ $? -ne 0 ]
  then
    echo "No such album: $artist/$album"
    exit 1
  fi

	albumPath="$BASE/$artist/$album"

  resetTags
  /bin/rm -rf "$FIXUP/$artist"
  mkdir -p "$FIXUP/$artist"

  #
	# Fetch Discogs information
	# Copied into ProcessConverted.sh
	#
	Discogs=/tmp/data."$artist"."$album"
	/Volumes/Music/SearchDiscogs.sh "$artist" "$album" > "$Discogs"

	Year=$(grep     Year     /tmp/data."$artist"."$album" | sed -e 's/Year=//')
	Genre=$(grep    Genre    /tmp/data."$artist"."$album" | sed -e 's/Genre=//')
	Grouping=$(grep Grouping /tmp/data."$artist"."$album" | sed -e 's/Grouping=//')

  if [ "$Genre" = "" -o "$Grouping" = "" -o "$Year" = "" ]
  then 
    echo "$artist/$album: Missing something, check $Discogs"
    echo "Failed to find Genre:    $Genre"
    echo "Failed to find Grouping: $Grouping"
    echo "Failed to find Year:     $Year"
    # ProcessConverted.sh will exit 22
    echo "echo \"$artist/$album: Year $Year; Group $Grouping; Genre $Genre\"" >> "$FIXUP/$artist/Year-Group-Genre-$album.sh"
    return
  fi

	/bin/rm "$Discogs"

  Year=$((Year + 0))
  if [ $Year -eq 0 ]
  then
    echo "Missing Year for $artist/$album"
    exit 23
  else
    [ $Year -lt 1950 -o $Year -gt 2025 ] && {
      echo "Invalid Year $Year for $artist/$album"
      exit 24
    }
  fi

	[ $verbose -ge 1 ] && echo "ProcessArtistAlbum: $track -> Year $Year; Group \"$Grouping\"; Genre \"$Genre\""

  #
  # End of copied information.
  #

  if [ "$track" != "" ]
  then
  	if [ ! -f "$track" ]
  	then
  		echo  "No such track \"$track\" for $artist"
  	else
    	processM4a "$albumPath" "$artist" "$album" "$track"
    fi
  else
  	#
  	# make sure we skip directories full of mp3 files
  	#
  	if [ "$(echo *.m4a)" = '*.m4a' ]
  	then
  	  [ $verbose -ge 1 ] && echo "only mp3"
  	  return 0
  	fi

		for track in *.m4a
		do
			processM4a "$albumPath" "$artist" "$album" "$track"
		done
  fi
 	
  if [ -e "$FIXUP/$artist/$album.sh" ]
  then
    echo "exit 0" >> "$FIXUP/$artist/$album.sh"
 	fi

 	# avoid banging on the server too fast (sigh)
 	sleep 2
}

#
# Process all albums by artist
#
ProcessArtist()
{
	artist="$1"
  cd "$BASE/$artist"
  if [ $? -ne 0 ]
  then
    echo "No such artist: $artist"
    return 1
  fi

  for album in *
  do
  	[ $verbose -eq 1 ] && echo "$artist/$album"
  	ProcessArtistAlbum "$artist" "$album" ""
  done
}

ProcessM4aFilesOnly()
{
	BASE=$(pwd -P)
	
  find -s "$BASE" -name '*.m4a' | while read track
  do
  	[ $verbose -gt 1 ] && echo "$track"
  	albumPath=$(dirname "$track")
  	
  	track=$(basename "$track")
  	album=$(basename "$albumPath")
		artist=$(basename "$(dirname "$albumPath")")
		
    [ $verbose -gt 1 ] && {
    	echo "BASE $BASE"
    	echo "artist $artist"
    	echo "album  $album"
    	echo "track  $track"
    }
    
    if [ $dryrun -ne 0 -o $verbose -gt 1 ]
    then
    	echo processM4a \"$albumPath\" \"$artist\" \"$album\" \"$track\"
    fi

		cd "$albumPath"
		processM4a "$albumPath" "$artist" "$album" "$track"
  done
}

#
# main
#
# Walk the <artist> <album> <track>
# as provided. If nothing specified
# then walk all artists in the directory
#
if [ $m4aFilesOnly -eq 1 ]
then
	ProcessM4aFilesOnly
	exit 0
fi

BASE="$MUSIC"
cd "$BASE"
artist="$1"
album="$2"
track="$3"

if [ "$artist" != "" ]
then
	if [ "$album" = "" ]
	then
		ProcessArtist "$artist"
	else
		ProcessArtistAlbum "$artist" "$album" "$track"
	fi
	set +e
	rmdir "$FIXUP/$artist" > /dev/null 2>&1
else
	for artist in *
	do
		cd "$BASE"	# reset to the root
		[ -d "$artist" ] || {
			echo "$artist: Not a directory"
			continue
		}

		ProcessArtist "$artist"
		rmdir "$FIXUP/$artist" > /dev/null 2>&1
	done
fi

exit 0
