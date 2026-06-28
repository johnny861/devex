# tar commands

Quick reference for creating, inspecting, extracting, and securing `tar` archives.

## Command syntax

```sh
# Create an archive
 tar [options] -f ARCHIVE.tar FILE_OR_DIRECTORY...

# List archive contents
 tar [options] -f ARCHIVE.tar -t

# Extract an archive
 tar [options] -f ARCHIVE.tar -x
```

Common operation flags:

- `-c` — create a new archive
- `-x` — extract an archive
- `-t` — list archive contents
- `-f FILE` — use archive file; usually required
- `-v` — verbose output
- `-z` — gzip compression, usually `.tar.gz` or `.tgz`
- `-j` — bzip2 compression, usually `.tar.bz2`
- `-J` — xz compression, usually `.tar.xz`
- `-C DIR` — change to directory before extracting or adding files
- `--exclude=PATTERN` — skip matching files or directories
- `--strip-components=N` — remove leading path components when extracting

> Tip: flag order is flexible, but `-f` should be followed by the archive filename.

## Cheat sheet

### Create archives

```sh
# Create an uncompressed tar archive
 tar -cvf myarchive.tar myfolder/

# Create a gzip-compressed archive
 tar -zcvf myarchive.tar.gz myfolder/

# Create a bzip2-compressed archive
 tar -jcvf myarchive.tar.bz2 myfolder/

# Create an xz-compressed archive
 tar -Jcvf myarchive.tar.xz myfolder/

# Archive multiple files and directories
 tar -zcvf project-backup.tar.gz file.txt config.yml src/ docs/

# Archive a folder while excluding common generated directories
 tar -zcvf project.tar.gz myproject/ \
  --exclude='myproject/.git' \
  --exclude='myproject/node_modules' \
  --exclude='myproject/dist'
```

### View and inspect archives

```sh
# View contents of a gzip archive
 tar -tvzf myarchive.tar.gz

# View contents of an uncompressed tar archive
 tar -tvf myarchive.tar

# Search archive contents for a file or folder name
 tar -tvzf myarchive.tar.gz | grep 'filename'
```

### Extract archives

```sh
# Extract a gzip archive into the current directory
 tar -xzvf myarchive.tar.gz

# Extract an uncompressed tar archive into the current directory
 tar -xvf myarchive.tar

# Extract into a specific directory
 mkdir -p extracted
 tar -xzvf myarchive.tar.gz -C extracted/

# Extract one file from an archive
 tar -xzvf myarchive.tar.gz path/inside/archive/file.txt

# Extract and remove the top-level folder from paths
 tar -xzvf myarchive.tar.gz --strip-components=1
```

### Add or update files in an uncompressed archive

```sh
# Add a file to an existing uncompressed .tar archive
 tar -rvf myarchive.tar newfile.txt

# Update files in an uncompressed .tar archive if they are newer
 tar -uvf myarchive.tar changedfile.txt
```

> Note: appending or updating does not work reliably with compressed archives like `.tar.gz`. Extract, change files, and recreate the compressed archive instead.

### Encrypt and decrypt archives with GPG

```sh
# Create a gzip archive first
 tar -zcvf myarchive.tar.gz myfolder/

# Encrypt the archive with a passphrase
 gpg --symmetric --cipher-algo AES256 myarchive.tar.gz

# Decrypt the encrypted archive
 gpg -d myarchive.tar.gz.gpg > myarchive.tar.gz

# Decrypt and extract in one pipeline
 gpg -d myarchive.tar.gz.gpg | tar -xzvf -
```

### Useful one-liners

```sh
# Backup a folder with today's date in the filename
 tar -zcvf "backup-$(date +%Y-%m-%d).tar.gz" myfolder/

# Backup the current directory without including the archive itself
 tar -zcvf ../current-folder-backup.tar.gz .

# Extract any .tar.gz file quietly
 tar -xzf myarchive.tar.gz

# Test that a gzip archive can be read
 tar -tzf myarchive.tar.gz > /dev/null
```
