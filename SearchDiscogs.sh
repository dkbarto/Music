#! /bin/sh
#
# Given an Artist and Album search Discogs for the
# associated Grouping, Genre, and Year.
#
# You must supply your Discogs developer key
#
# https://www.discogs.com/developers/
#

Artist="$1"
Album="$2"

Genre=""
Grouping=""
Year=""

[ -f /Volumes/Music/DISCOGS.token ] && . /Volumes/Music/DISCOGS.token

if [ "$DISCOGS_TOKEN" = "" ]
then
  echo "Failure: the DISCOGS_TOKEN in your environment isn't set"
  echo "Get your TOKEN from Discogs.com for API access"
  exit 1
fi

#
# Extract the token we want. Sort for the most common entry
# across all entries.
#
extract()
{
  what=$1
  grep "$what" $TMP > /dev/null
  if [ $? -ne 0 ]
  then
    echo ""
    return
  fi

  set $(cat $TMP |\
    sed \
      -e 's/], "/]\n"/g' | \
    grep "$what" | \
    grep -v '\[\]' |\
    sed \
      -e 's/\(.*\)"'"$what"'": \(.*\)/\2/' \
      -e 's/:/\n/g' \
      -e 's/\[//' \
      -e 's/\]//' \
      -e 's/"//g' |\
    grep -v '\[\]' |\
      while read line; do \
        words=$(echo "$line" | wc -w); \
        words=$(expr $words '+' 0); \
        [ $words -lt 10 ] && echo "$line" ;\
      done |\
    sort | \
    uniq -c | \
    sort -n | \
    tail -1)
  # shift off the count
  shift
  echo $*
}

#
# Some tags have only one value. This is used for Year
# at the present time. May have future use
#
extractTag()
{
  what=$1
  grep "$what" $TMP > /dev/null
  if [ $? -ne 0 ]
  then
    echo 0
    return
  fi

  set $(cat $TMP |\
    sed \
      -e 's/\",/"\n/g' | \
    grep "$what" |\
    sed -e 's/"//g' -e 's/\(.*\): //' |\
    sort | \
    uniq -c | \
    sort -n | \
    tail -1)
  # shift off the count
  shift
  echo $*
}

askDiscogs()
{
  fixupAlbum=$(echo "$2" | sed -e 's/\([ ]*\)\[\(.*\)\]//' -e 's/\([ ]*\)(\(.*\))//')
  escArtist=$(echo "$1" | sed -e 's/ /%20/g' -e "s/\'/%27/g" -e 's/\!/%21/g')
  escAlbum=$(echo "$fixupAlbum"  | sed -e 's/ /%20/g' -e "s/\'/%27/g" -e 's/\!/%21/g')

  TMP=/tmp/$escArtist%20$escAlbum
  TOKEN=$DISCOGS_TOKEN  
  curl https://api.discogs.com/database/search?q={$escArtist%20$escAlbum}\&token=$TOKEN\&sort_order=desc \
      2>/dev/null \
      > $TMP

  Genre=$(extract genre)
  # if Genre is empty assume lookup failed
  [ "$Genre" = "" ] && return
  Genre=$(extract genre | sed -e 's/\(.*\), \(.*\)/\1/')
  Grouping=$(extract style)
  Year=$(extractTag year)
  
  /bin/rm $TMP
}

#
# main()
#
askDiscogs "$Artist" "$Album"

echo "Genre=$Genre"
echo "Grouping=$Grouping"
echo "Year=$Year"
