FROM gcr.io/oss-fuzz-base/base-builder-rust
RUN apt-get update && apt-get install -y make autoconf automake libtool
COPY . $SRC/git-rsr-certified
WORKDIR $SRC/git-rsr-certified
COPY .clusterfuzzlite/build.sh $SRC/
