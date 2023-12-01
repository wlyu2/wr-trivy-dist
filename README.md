# Introduction

This file documents the steps to install and run `trivy` that supports Wind River Linux.

There are two methods to install and run `trivy` that supports Wind River Linux. One can choose either of the two methods to be able to run `trivy`, though the steps to run `trivy` is different for each method of installation.

The docker image is 

⚠ **WARNING:** This file is written and verified for host running `Ubuntu 20.04 LTS` as the operating system (OS). If the host is running any other distributions of OS, any information provided in this file might not be accurate.

# Method 1: Installing and Runing `trivy` as a Binary on Host

## Prerequisite Packages and Applications on Host

Please install the following packages on local host before attempt at installation.
```
build-essential
git
```

Please install the Go Programming Language following the instructions on the Go offical website: [Download and install - The Go Programming Language](https://go.dev/doc/install).


## Steps to Install

To install on the host, execute the following commands:
```
$ git clone https://github.com/wlyu2/wr-trivy-dist.git
$ cd wr-trivy-dist
$ ./setup.sh install
```

## Steps to Run

The location of the binary is at:
```
{path to wr-trivy-dist repo}/trivy/trivy
```
where `{path to wr-trivy-dist repo}` is the path to the directory that contains the clone of `wr-trivy-dist` repository as described in section [Steps to Install](#steps-to-install).

Command to run `trivy` scan on a Docker image:
```
$ {path to wr-trivy-dist repo}/trivy/trivy image {Docker image reference}
```
where `{Docker image reference}` is a reference to a Docker image listed under the result of executing command `$ docker image list`.

Example command to run `trivy` scan on a Docker image:
```
$ {path to wr-trivy-dist repo}/trivy/trivy image windriver/wrlx-image:latest
```

## Steps to Update Database

To update the CVE database, execute the following commands:
```
$ cd {path to wr-trivy-dist repo}
$ ./setup.sh update_db
```
Note that `{path to wr-trivy-dist repo}` is the path to the directory that contains the clone of `wr-trivy-dist` repository as described in section [Steps to Install](#steps-to-install).

## Changes to the File System

TBD

# Method 2: Installing `trivy` using Docker Image

## Prerequisite Packages and Applications on Host

TBD

## Steps to Install

```
$ git clone https://github.com/wlyu2/wr-trivy-dist.git
$ cd wr-trivy-dist
$ docker build -t wr-trivy .
```

## Steps to Run

```
$ docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock wr-trivy:latest trivy image {Docker image reference on host}
```
⚠ **WARNING:** Access to the host docker images is achieved by binding the socket `/var/run/docker.sock` the Docker daemon listens to a file in the container. This is a huge **security risk** as such binding grants root access on host to the docker containers spawned from this image.

## Steps to Update Database

TBD

## Changes to the File System

TBD

