#!/bin/sh
set -e

RS_SRC_DIR='hstreamdb-rust'

mkdir -p rs_src
cd rs_src/
[ -d $RS_SRC_DIR ] || git clone --recurse-submodules https://github.com/hstreamdb/hstreamdb-rust.git
cd $RS_SRC_DIR/
cargo build --release
mkdir -p ../../priv
cp target/release/libhstreamdb_erl_nifs.so ../../priv
