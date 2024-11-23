rm -rf build
mkdir build

odin run src -out:build/program_name -debug -- $1