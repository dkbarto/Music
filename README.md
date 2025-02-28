A collection of scripts to help add and update tags in m4a files.

Uses AtomicParsley,
Uses XLD to convert the original AIFF files to m4a
and setup the required directory structure.

XLD Settings:
  Output Format: Apple Lossless
  Output Directory: /Volumes/Music/Converted
File Naming
  Custom: %a/%T/%n %t
  <Rename>
Batch
  Preserve Directory Structure
  Restrict files to open: wav aiff flac wv ape tta
  Automatically split file with embedded cue sheet
CDDB
  Server: freedb.freedb.org:80
  Path:   /~cddb/cddb.cgi
Metadata
  Embed cover art images into files
  Scale large images when embedding
  Scale longer side
  Load following files in same folder as cover art
    cover.jpg folder.jpg front.jpg
 Set the Compilation flag  automatically
 Preserve unknown metadata if possible

AtomicParsley is used to validate all tags of interest.
You will need to export a key for Discogs.com as a developer
to use the API which fetches the Year, Genre, and Grouping
for the albums.

export DISCOGS_TOKEN="your developer token"

Use at your own risk.
