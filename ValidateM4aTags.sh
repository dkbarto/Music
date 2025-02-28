#! /bin/bash
#
# Validate the M4A tags we know about in the files specified
#          Usage: $0 <Artist> <Album> <Song>
# if no args are present, process across all Artists in the current
# directory recursively for all albums and songs.
#
# Output: /Volumes/Music/Fixup/<files>.sh
# which are processed by PatchArt.sh and ApplyFixes.sh
#

set -e

# TODO
# 1 - need to escape special chars in $Song (like $)
# 2 - Manage file names with multiple spaces. ?? Flag them and do nothing?
# 3 - need to escape ` when echoing Song names
#

MUSICROOT="/Volumes/Music"
MUSIC="$MUSICROOT/Music/iTunes/iTunes Media/Music"
FIXUP="$MUSICROOT/Fixup"
LANG=en_US.UTF-8

mkdir -p "$FIXUP"

verbose=0
overwrite=0

[ "$1" = "-v" ] && verbose=1 && shift
[ "$1" = "-v" ] && verbose=2 && shift

[ "$1" = "-o" ] && overwrite=1 && shift

[ ! -d "$MUSIC/$1" ] && {
  echo "Usage: $0 [-v] [-v] [-o] <Artist> <Album> <Song>"
  exit 1
}

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
	echo "[ \$? -ne 0 ] && {"                              >> "$FIXUP/$Artist/$Album.sh"
	echo "echo rename failed for \"$Artist/$Album/$Song\"" >> "$FIXUP/$Artist/$Album.sh"
	echo "exit 1"                                          >> "$FIXUP/$Artist/$Album.sh"
	echo "}"                                               >> "$FIXUP/$Artist/$Album.sh"
}

doMove()
{
  # sadly using basename farks up too often.
  # base=$(basename "$Song" .m4a)
  #	echo mv \"$base\"-temp-*.m4a \"$Song\" >> "$FIXUP/$Artist/$Album.sh"
  echo "mv *-temp-*.m4a \"$Song\""         >> "$FIXUP/$Artist/$Album.sh"
}

extractTags()
{
  Song="$1"

 	[ $verbose -ge 1 ] && echo "$Artist/$Album/$Song"

  #
  # Avoid sub-shell. The pipe loses the export of variables to the 'parent'
  # and things go poorly after that.
  #
  # AtomicParsley "$Song" --textdata | sed -e 's/"//g' | grep "Atom" | egrep -v -e '----' | while read tag
  # doesn't work.....
  #
  [ $verbose -ge 2 ] && echo "AtomicParsley $Song --textdata"

  set +e
  AtomicParsley "$Song" --textdata | sed -e 's/"//g' | grep "Atom" | egrep -v -e '----' > /tmp/lines
  [ $? -ne 0 ] && {
  	echo "AtomicParsley failed on $Artist/$Album/$Song"
  }
  set -e

  while read tag
  do
    # Atom "©nam" contains: I Gotta Have A Song (Single Version ／ Mono)
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
		[ $verbose -ge 2 ] && echo "Process $2"
    case $2 in
    cpil|pgap|tmpo|©too) continue
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
      [ $verbose -ge 2 ] && {
        echo "File: $Artist/$Album/$Song"
        echo "    Unknown tag $2"
        echo "    $tag"
      }
    esac
  done < /tmp/lines
}

FixupSong()
{
	Song="$1"
	AP_Flags="$2"

  escSong=$(echo $Song | sed -e 's/"/\\\\"/g')
  
  echo "cd \"$MUSIC/$Artist/$Album\""      >> "$FIXUP/$Artist/$Album.sh"
  [ $overwrite -eq 1 ] && {
    echo "echo Processing \"$Artist/$Song\"" >> "$FIXUP/$Artist/$Album.sh"
    AP_Flags="$AP_Flags --overWrite"
  }

	[ "$verbose" -gt 1 ] && echo AtomicParsley \"$Song\" $AP_Flags
  
	echo "AtomicParsley \"$escSong\" $AP_Flags"   >> "$FIXUP/$Artist/$Album.sh"

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
	Song="$1"

	AP_Flags=""

  [ $diskValid -ne 1 ] && {
    AP_Flags="$AP_Flags --disk=1/1"
  }
  [ $totalDiskValid -ne 1 -a $diskValid -eq 1 ] && {
    AP_Flags="$AP_Flags --disk=1/1"
  }
  [ $ARTValid -ne 1 ] && {
    AP_Flags="$AP_Flags --artist=\"$Artist\""
  }
  [ $wrtValid -ne 1 ] && {
    AP_Flags="$AP_Flags --composer=\"$Artist\""
  }
  [ $aARTValid -ne 1 ] && {
    AP_Flags="$AP_Flags --albumArtist=\"$Artist\""
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
    AP_Flags="$AP_Flags --album=\"$Album\""
  }
  [ $covrValid -ne 1 ] && {
    echo "echo \"$Song\": Cover art missing" >> "$FIXUP/$Artist/CantFix-$Album.sh"
  }
  [ $covrValid -eq 1 -a $totalCover -ne 1 ] && {
    echo "echo \"$Song\": TOO MANY cover art entries $totalCover" >> "$FIXUP/$Artist/CantFix-$Album.sh"
  }

	[ $trknValid -ne 1 ] && {
		totalTracks=$(/bin/ls *.m4a | wc -l)
		totalTracks=$((totalTracks + 0))
		tracknum=$(echo "$Song" | sed -e 's/\([0-9]*\)\(.*\)/\1/')
		AP_Flags="$AP_Flags --tracknum=$tracknum/$totalTracks"
	}

	[ $namValid -ne 1 ] && {
	  title=$(echo "$Song" | sed -e 's/\([0-9]*\)//' -e 's/^ //' -e 's/^- //' -e "s/.m4a//")
		if [ "$title" = "" ]
		then
			echo "Title missing: $Artist/$Album/$Song"
			exit 2
		fi
		AP_Flags="$AP_Flags --title \"$title\""
	}

  [ "$AP_Flags" != "" ] && FixupSong "$Song" "$AP_Flags"

	resetTags

	return 0
}

processM4a()
{
	Artist="$1"
  Album="$2"
  Song="$3"

  extractTags "$Song"
  BuildAPFlags "$Song"
  return 0
}

#
# Process specific Album by specified Artist
# optionally just a single song
#
ProcessArtistAlbum()
{
  Artist="$1"
	Album="$2"
	Song="$3"
	
  cd "$MUSIC/$Artist"

  if [ $? -ne 0 ]
  then
    echo "No such artist: $Artist"
    exit 1
  fi

  cd "$Album"
  if [ $? -ne 0 ]
  then
    echo "No such Album: $Artist/$Album"
    exit 1
  fi

  resetTags
  /bin/rm -rf "$FIXUP/$Artist"
  mkdir -p "$FIXUP/$Artist"

  #
	# Fetch Discogs information
	# Copied into ProcessConverted.sh
	#
	Discogs=/tmp/data."$Artist"."$Album"
	/Volumes/Music/SearchDiscogs.sh "$Artist" "$Album" > "$Discogs"

	Year=$(grep     Year     /tmp/data."$Artist"."$Album" | sed -e 's/Year=//')
	Genre=$(grep    Genre    /tmp/data."$Artist"."$Album" | sed -e 's/Genre=//')
	Grouping=$(grep Grouping /tmp/data."$Artist"."$Album" | sed -e 's/Grouping=//')

  if [ "$Genre" = "" -o "$Grouping" = "" -o "$Year" = "" ]
  then 
    echo "$Artist/$Album: Missing something, check $Discogs"
    echo "Failed to find Genre:    $Genre"
    echo "Failed to find Grouping: $Grouping"
    echo "Failed to find Year:     $Year"
    # ProcessConverted.sh will exit 22
    echo "echo \"$Artist/$Album: Year $Year; Group $Grouping; Genre $Genre\"" >> "$FIXUP/$Artist/Year-Group-Genre-$Album.sh"
    return
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

	[ $verbose -ge 1 ] && echo "ProcessArtistAlbum: $Song -> Year $Year; Group \"$Grouping\"; Genre \"$Genre\""

  #
  # End of copied information.
  #

  if [ "$Song" != "" ]
  then
  	if [ ! -f "$Song" ]
  	then
  		echo  "No such song \"$Song\" for $Artist"
  	else
    	processM4a "$Artist" "$Album" "$Song"
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

		for Song in *.m4a
		do
			processM4a "$Artist" "$Album" "$Song"
		done
  fi

  if [ -f "$FIXUP/$Artist/$Album.sh" -a -s "$FIXUP/$Artist/$Album.sh" ]
  then
 	  echo "exit 0" >> "$FIXUP/$Artist/$Album.sh"
 	else
 	  /bin/rm -f "$FIXUP/$Artist/$Album.sh"
 	fi
 	
 	# avoid banging on the server too fast (sigh)
 	sleep 2
}

#
# Process all albums by Artist
#
ProcessArtist()
{
	Artist="$1"
  cd "$MUSIC/$Artist"
  if [ $? -ne 0 ]
  then
    echo "No such artist: $Artist"
    return 1
  fi

  for Album in *
  do
  	[ $verbose -eq 1 ] && echo "$Artist/$Album"
  	ProcessArtistAlbum "$Artist" "$Album" ""
  done
}

#
# main
#
# Walk the <Artist> <Album> <Song>
# as provided. If nothing specified
# then walk all artists in the directory
#
cd "$MUSIC"
Artist="$1"
Album="$2"
Song="$3"

if [ "$Artist" != "" ]
then
	if [ "$Album" = "" ]
	then
		ProcessArtist "$Artist"
	else
		ProcessArtistAlbum "$Artist" "$Album" "$Song"
	fi
	set +e
	rmdir "$FIXUP/$Artist" > /dev/null 2>&1
else
	for Artist in *
	do
		cd "$MUSIC"	# reset to the root
		[ -d "$Artist" ] || {
			echo "$Artist: Not a directory"
			continue
		}

		ProcessArtist "$Artist"
		set +e
		rmdir "$FIXUP/$Artist" > /dev/null 2>&1
		set -e
	done
fi

exit 0
