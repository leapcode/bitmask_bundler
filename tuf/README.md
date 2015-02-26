Using the TUF repository updater
================================

Usage example (for stable):

```
$ docker build -t test/tuf .  # build the image, run this inside the Dockerfile directory
$ mkdir bundle.stuff/
$ cd bundle.stuff/
$ cp /some/path/Bitmask-linux{32,64}-0.8.1.tar.bz2 .
$ cp /some/path/tuf_private_key.pem .
$ docker run -t -i --rm -v `pwd`:/code/ test/tuf-stuff -v 0.8.1 -a 32 -k tuf_private_key.pem -R S
$ docker run -t -i --rm -v `pwd`:/code/ test/tuf-stuff -v 0.8.1 -a 64 -k tuf_private_key.pem -R S
```

Usage example (for unstable):

```
$ docker build -t test/tuf .  # build the image, run this inside the Dockerfile directory
$ mkdir bundle.stuff/
$ cd bundle.stuff/
$ cp /some/path/Bitmask-linux{32,64}-0.9.0rc1.tar.bz2 .
$ cp /some/path/tuf_private_key_unstable.pem .
$ docker run -t -i --rm -v `pwd`:/code/ test/tuf-stuff -v 0.9.0rc1 -a 32 -k tuf_private_key_unstable.pem -R U
$ docker run -t -i --rm -v `pwd`:/code/ test/tuf-stuff -v 0.9.0rc1 -a 64 -k tuf_private_key_unstable.pem -R U
```


You'll find the output tuf repo on `./workdir/output/`.
