
# tar commands

```sh
# Compress folder into tar zip
tar -zcvf myarchive.tar.gz myfolder/

# View contents of tar zip
tar -tvzf myarchive.tar.gz

# Encrypt tar zip
gpg --symmetric --cipher-algo aes256 myarchive.tar.gz

# Decrypt tar zip
gpg -d myarchive.tar.gz.gpg

```