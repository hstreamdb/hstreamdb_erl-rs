#!/usr/bin/env sh
set -e

RS_SRC_DIR='hstreamdb-rust'
REV='40e65e5b59f7464df7c44dda7625b7c713bc59f0'

mkdir -p rs_src
cd rs_src/
[ -d $RS_SRC_DIR ] || git clone --depth=1 --recurse-submodules https://github.com/hstreamdb/hstreamdb-rust.git
cd $RS_SRC_DIR/
git checkout $REV
echo "Compiling $RS_SRC_DIR: REV = $REV"
cargo build --release
mkdir -p ../../priv
cp target/release/libhstreamdb_erl_nifs.so ../../priv
