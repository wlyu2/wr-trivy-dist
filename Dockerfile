FROM ubuntu:22.04

WORKDIR /root

# Install dependency packages.
RUN apt-get -y update
RUN apt-get -y install build-essential
RUN apt-get -y install wget
RUN apt-get -y install git
RUN git config --global user.email ""
RUN git config --global user.name "wr-trivy"

# Install Go.
ADD https://dl.google.com/go/go1.21.4.linux-amd64.tar.gz ./
RUN rm -rf /usr/local/go && tar -C /usr/local -xzf go1.21.4.linux-amd64.tar.gz
ENV PATH=$PATH:/usr/local/go/bin
RUN go version

# Copy Wind River specific patches and wrappers into the image.
ADD patch ./patch/
ADD setup.sh ./
RUN chmod +x setup.sh

# Build the "trivy" database and "trivy" executable for the first time.
RUN bash setup.sh install
RUN ln -s $(pwd)/trivy/trivy /usr/local/bin/trivy