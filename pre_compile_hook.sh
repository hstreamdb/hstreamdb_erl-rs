#!/usr/bin/env sh
set -e

RS_SRC_DIR='hstreamdb-rust'
REV='b24a3e269c73a7697d76b6ceb00d38f03a6a4228'

mkdir -p rs_src
cd rs_src/
[ -d $RS_SRC_DIR ] || git clone --depth=1 --recurse-submodules https://github.com/hstreamdb/hstreamdb-rust.git
cd $RS_SRC_DIR/
git checkout $REV
echo "Compiling $RS_SRC_DIR: REV = $REV"
cargo build --release
mkdir -p ../../priv
cp target/release/libhstreamdb_erl_nifs.so ../../priv
