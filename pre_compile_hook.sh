#!/bin/sh
set -e

RS_SRC_DIR='hstreamdb-rust'
REV='bfc8f6fe348b6ff8a18910835747a1a29afd2c31'

mkdir -p rs_src
cd rs_src/
[ -d $RS_SRC_DIR ] || git clone --recurse-submodules https://github.com/hstreamdb/hstreamdb-rust.git
cd $RS_SRC_DIR/
git checkout $REV
echo "Compiling $RS_SRC_DIR: REV = $REV"
cargo build --release
mkdir -p ../../priv
cp target/release/libhstreamdb_erl_nifs.so ../../priv
