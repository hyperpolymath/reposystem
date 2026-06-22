FROM gcr.io/oss-fuzz-base/base-builder-rust
# pkg-config + libssl-dev: the crate links reqwest -> openssl-sys, which needs
# them to locate OpenSSL during the fuzzer build.
RUN apt-get update && apt-get install -y make autoconf automake libtool pkg-config libssl-dev
COPY . $SRC/reposystem
WORKDIR $SRC/reposystem
COPY .clusterfuzzlite/build.sh $SRC/
