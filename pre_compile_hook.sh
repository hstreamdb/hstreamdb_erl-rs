#!/usr/bin/env sh
set -e

RS_SRC_DIR='hstreamdb-rust'
REV='8ef1096dded6f95321bcbc0e0af97e4dca5884cd'

mkdir -p rs_src
cd rs_src/
[ -d $RS_SRC_DIR ] || git clone --depth=1 --recurse-submodules https://github.com/hstreamdb/hstreamdb-rust.git
cd $RS_SRC_DIR/
git checkout $REV
echo "Compiling $RS_SRC_DIR: REV = $REV"
cargo build --release
mkdir -p ../../priv
cp target/release/libhstreamdb_erl_nifs.so ../../priv
