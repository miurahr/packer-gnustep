packer-gnustep
==============

Install gnustep in a way of
http://wiki.gnustep.org/index.php/GNUstep_under_Ubuntu_Linux
on Ubuntu 14.04.02 LTS (Trusty) and Docker.

Dependency
------------

* Pakcer 0.7.5 and later
* Docker 1.3.3 and later

How to build
--------------------

Simply run

```bash
$ packer build -var 'ncpu=3' gnustep.json
```

Please specify number of CPUs you want to use for compiling, that is concurrency for 'make'
