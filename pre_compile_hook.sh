#!/usr/bin/env sh
set -e

RS_SRC_DIR='hstreamdb-rust'
REV='a8fb7794a1bd2a78b2e3f5d2be09ff38f1f63a50'

mkdir -p rs_src
cd rs_src/
[ -d $RS_SRC_DIR ] || git clone --recurse-submodules https://github.com/hstreamdb/hstreamdb-rust.git
cd $RS_SRC_DIR/
git checkout $REV
echo "Compiling $RS_SRC_DIR: REV = $REV"
cargo build --release
mkdir -p ../../priv
cp target/release/libhstreamdb_erl_nifs.so ../../priv
