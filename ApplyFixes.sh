#! /bin/sh
export PATH=$PATH:/Volumes/Music

#
# Use this to run the scripts generated
# by fixing up missing tags from ValidateM4aTags.sh
#

ProcessDir()
{
  cd "$1"
  [ $? -ne 0 ] && {
    echo "Failed to cd into $1"
    return 1
  }

  for f in *.sh
  do
    echo -----
    echo $f
    bash "$f"
    if [ $? -ne 0 ]
    then
      echo "Failed: $f"
      return 1
    fi
    echo
  done
  cd ..
  return 0
}

if [ "$1" != "" ]
then
  ProcessDir "$1" || exit 1
else
  for d in *
  do
    ProcessDir "$d" || exit 1
  done
fi

echo
echo      Process Art
echo

PatchArt.sh || exit 1

exit 0