rm -rf build
mkdir build

odin build src -out:build/program_name -debug
./build/program_name 2> mem_leaks.txt