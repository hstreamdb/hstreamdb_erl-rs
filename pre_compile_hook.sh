#!/bin/sh
set -e

RS_SRC_DIR='hstreamdb-rust'
REV='1c5657de44b0683b59c09f9196ea47ae03d35715'

mkdir -p rs_src
cd rs_src/
[ -d $RS_SRC_DIR ] || git clone --recurse-submodules https://github.com/hstreamdb/hstreamdb-rust.git
cd $RS_SRC_DIR/
git checkout $REV
echo "Compiling $RS_SRC_DIR: REV = $REV"
cargo build --release
mkdir -p ../../priv
cp target/release/libhstreamdb_erl_nifs.so ../../priv
