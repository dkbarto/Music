#! /opt/local/bin/python3
import os, sys, argparse, subprocess

from datetime import datetime

#
# Only process directories created or updated after DATESTR
#
DATESTR   = "2025-04-01"

HERE           = "/Volumes/Music"
MUSICDATA      = f"{HERE}/Music/iTunes/iTunes Media/Music"
NEW_PATH       = f"{HERE}/New Music/New"
UPDATE_PATH    = f"{HERE}/New Music/Updated"

REMOTE_CLOW_MUSIC = "/Volumes/Clow Music"
# scp command uses the user and host for auth. Check your ssh keys
USER = "davidbarto"
HOST = "magrathea"

StartDate = int(datetime.strptime(DATESTR, "%Y-%m-%d").timestamp())

verbose  = 0
dryrun   = False
isNew    = False
isUpdate = False


# --------------
def exclude(what):
  if what == "Ford Prefect":
    return True
  if what == "Hotblack Desiato":
    return True
  if what == "Voice Memos":
    return True
  if what == "YouTube":
    return True
  if what == "Music":
    return True
  if what == "Sleep Music":
    return True

  return False

# --------------
def checkNewOrUpdate(directory):
  global isNew
  global isUpdate

  if verbose > 1:
    base = os.path.basename(directory)
    print(f"checkNewOrUpdate {base}")

  stat       = os.stat(directory)
  dir_date   = int(stat.st_birthtime)
  dir_update = int(stat.st_mtime)

  isNew    = dir_date   > StartDate
  isUpdate = dir_update > StartDate
  if (not isNew and not isUpdate):
#   if (options.dryrun || options.verbose > 0):
#     print(f"too old -- {directory}")
    return False

  # print(f"checkNewOrUpdate: Verbose is {verbose}")

  if (verbose > 1):
#     print(f"StartDate {StartDate}, dir_date {dir_date}, dir_update {dir_update}")
    print(f"isNew {isNew}, isUpdate {isUpdate}")

  return True

# --------------
def link_album(newOrUpdate, albumPath, artist, album):
  path = os.path.join(newOrUpdate, artist)
  try:
    os.makedirs(path, exist_ok=True)
    if verbose > 2:
      print(f"Directory created or already exists: {path}")
  except OSError as e:
    print(f"Error creating directory {path}: {e}")
    sys.exit(2)

  destPath = os.path.join(path, album)
  if os.path.islink(destPath):
    curLink = os.readlink(destPath)
    if curLink == albumPath:
      if verbose > 1:
        print(f"{destPath} already exists")
      return True
    
    print(f"\nFAILED: Check of {destPath}\nLink to  => {curLink}\nExpected => {albumPath}")
    return False
    
  if dryrun or verbose:
    print(f"ln -s '{albumPath}' '{destPath}'")
  
  if not dryrun:
    try:
      os.symlink(albumPath, destPath)
    except FileExistsError:
      print(f"Error: Symlink '{destPath}' already exists.", file=sys.stderr)
      return False
    except OSError:
      print(f"Error creating symlink '{destPath}' for '{albumPath}'", file=sys.stderr)
      return False

  return True

# --------------
def linkNewOrUpdate(albumPath):
  if verbose > 1:
    print(f"linkNewOrUpdate {albumPath}")

  parts = [p for p in albumPath.split('/') if p]

  if len(parts) <= 2:
    if verbose > 1:
      print("Error: Path {albumPath} must have more than 2 components.")
    return

  # Get the last 2 entries
  album     = parts[-1]
  artist    = parts[-2]
  if verbose:
    print(f"Process album '{album}' for artist '{artist}'")

  if exclude(artist) or exclude(album):
    return

  #
  # link the album.
  #
  # All new files are 'updates'
  # so check for isNew to see if it really is new
  #
  newOrUpdate = UPDATE_PATH

  if isNew:
    newOrUpdate = NEW_PATH

  if not link_album(newOrUpdate, albumPath, artist, album):
    print(f"Failed to link {albumPath}")
    sys.exit(1)


#
# should optimize this to not scan a directory full of files
# as we link albums not individual tracks
# --------------
def processDir(directory):
    if not os.path.isdir(directory):
        print(f"Error: '{directory}' is not a valid directory.", file=sys.stderr)
        return False

    if verbose > 1:
      print(f"Processing directory: {directory}")

    try:
      with os.scandir(directory) as entries:
        hasSubDir = False # there is always hope
        for entry in entries:
          if (entry.name.startswith('.')):
            continue
        
          fullPath = os.path.join(directory, entry.name)
          if (entry.is_dir()):
            hasSubDir = True
            processDir(fullPath)

        if not hasSubDir:
          if (checkNewOrUpdate(directory)):
            linkNewOrUpdate(directory)
                  
    except FileNotFoundError:
        print(f"Error: Directory '{directory}' not found.", file=sys.stderr)
    except NotADirectoryError:
        print(f"Error: '{directory}' is not a directory.", file=sys.stderr)
    return True

# --------------
def do_rmdir(path):
  if not os.path.exists(path):
    print(f"Path does not exist: {path}")
    return

  try:
    with os.scandir(path) as entries:
      for entry in entries:
        fullPath = os.path.join(path, entry.name)
        if os.path.islink(fullPath):  # is_dir will return true for the symlink.
          os.remove(fullPath)
        else:
          if (entry.is_dir()):
            do_rmdir(fullPath)
          else:
            os.remove(fullPath)

      os.rmdir(path)
      if verbose > 1:
        print(f"Removed directory: {path}")

  except Exception as e:
    print(f"Error removing root directory {path}: {e}")
    
# --------------
def main():
  global verbose
  global dryrun

  parser = argparse.ArgumentParser(description="Process -d (debug) and -v (verbosity) flags.")
  # parser.set_defaults(dryrun=False, verbose=0)
  # -d as a boolean flag
  parser.add_argument('-d', '--dryrun'
                          , help='show work to be done'
                          , default=False
                          , action="store_true")
  parser.add_argument('-v', '--verbose'
                          , help='set verbose level'
                          , type=int
                          , default=0)
  
  # Filenames: Zero or more positional arguments after options
  parser.add_argument('dirnames', nargs='*', help=f'Optional list of directories to process (default {HERE})')

  args = parser.parse_args()

  dryrun = args.dryrun
  verbose = args.verbose

  if dryrun:
    print('dryrun flag')

  if verbose:
    print('verbose flag', verbose)

  if not dryrun:
    USER = "davidbarto"
    HOST = "magrathea"
    command = f"scp {USER}@{HOST}:\"{REMOTE_CLOW_MUSIC}/ClowMusic.txt\" {HERE}/ClowMusic.txt"

    result = subprocess.run(command, shell=True)
    if result.returncode != 0:
      print(f"Failed to get copy of {remote_host}:{remote_path}: {e}")
      sys.exit(1)
  
  #
  # Always start clean
  #
  do_rmdir(NEW_PATH)
  do_rmdir(UPDATE_PATH)
  # sys.exit(1)

  # Iterate over directories if present
  if not args.dirnames:
    processDir(MUSICDATA)
  else:
    for dirname in args.dirnames:
      processDir(os.path.join(MUSICDATA, dirname))

# --------------
if __name__ == "__main__":
  main()