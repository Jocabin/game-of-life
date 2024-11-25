rm -rf build
mkdir build

odin run src -out:build/gol -debug -- $1