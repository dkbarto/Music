#! /bin/sh
#
# Extract the art from song X
# Apply resulting art to all other songs
#
# To be run from the Fixup directory
#
warnonly=0

MUSICROOT="/Volumes/Music"
MUSIC="$MUSICROOT/Music/iTunes/iTunes Media/Music"

#
# Setup in Fixup Directory
#
cd "$MUSICROOT/Fixup"

FIXUP_ROOT=$(pwd)

if [ "$1" = "-w" ]
then
  warnonly=1
  shift
fi

Fixup()
{
  Artist="$1"
  CantFix="$2"

  Album=$(echo "$CantFix" | sed -e 's/CantFix-//' -e 's/\.sh$//')
  
  cd "$MUSIC/$Artist/$Album"
  if [ $? -ne 0 ]
  then
    echo "No such album: $MUSIC/$Artist/$Album"
    return 0
  fi
  
  #
  # Find first song with art
  #
  BaseSong=""
  TMP="/tmp/$Artist/$Album"
  /bin/rm -rf "$TMP"
  mkdir -p "$TMP"

  [ $? -ne 0 ] && {
    echo "Failed to create temp directory: $TMP"
    return 1
  }
  
  #
  # Loop over all songs in the directory
  # find if one has art
  #
  for Song in *
  do
    AtomicParsley "$Song" --extractPixToPath "$TMP/art" > /dev/null 2>&1
    res=$?
    artwork="$TMP"/art_artwork_1.png
    [ -f "$TMP"/art_artwork_1.jpg ] && artwork="$TMP"/art_artwork_1.jpg
    if [ $res -eq 0 -a -f "$artwork" ]
    then
      BaseSong="$Song"
      break
    fi
  done

  artwork="$TMP"/art_artwork_1.png
  [ -f "$TMP"/art_artwork_1.jpg ] && artwork="$TMP"/art_artwork_1.jpg

  if [ "$BaseSong" = "" -o ! -f "$artwork" ]
  then
    echo "$Artist/$Album: No song has any art"
    return 1
  fi

  #
  # Loop over all songs listed as having problems
  # add art to those without it
  #
  cat "$FIXUP_ROOT/$Artist/$CantFix" | grep 'Cover art missing' |\
        sed -e 's/echo "//' -e 's/": Cover art missing//' | while read Song
  do
    #
    # CantFix also includes the Genre, Group, and Year faults
    # Not all songs are missing their art so only some need updates.
    # Running this is idempotent. If we run it twice on the same
    # song it won't add art to it a second time.
    #
    [ ! -f "$Song" ] && continue

    AtomicParsley "$Song" --textdata | grep "Atom" | grep 'covr' > /dev/null
    [ $? -eq 0 ] && continue

    echo "Update art for $Artist/$Album/$Song"
    AtomicParsley "$Song" --artwork "$artwork" --overWrite > /dev/null 2>&1
  done
  return 0
}

#
# main()
#
for CantFixMaster in */CantFix*
do
  cd "$FIXUP_ROOT"
  
  Artist=$(echo $CantFixMaster | sed -e 's|/CantFix\(.*\)||')

  [ "$Artist" = '*' ] && exit 0

  cd "$Artist"
  for f in CantFix-*
  do
    Fixup "$Artist" "$f"
    if [ $? -ne 0 ]
    then
      [ $warnonly -eq 0 ] && exit 1
    else
      /bin/rm "$FIXUP_ROOT/$CantFixMaster" || {
        echo "remove $FIXUP_ROOT/$CantFixMaster failed"
        pwd
      }
    fi
  done
done

exit 0