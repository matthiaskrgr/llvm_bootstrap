#!/bin/bash
#set -x

procs=6 #number of jobs to run at a time
export CCACHE_DISABLE=1 #disable ccache
rootDir=`pwd` #cwd

mkdir -p  stage_1
cd stage_1

export stageBase=`pwd`



# build dir
export LLVMBuild=${stageBase}/build
#compilers to use for stage 1
export CXX=clang++
export CC=clang


echo -e "\e[95mCloning/updating repo...\e[39m"

repoSrcStr="llvm-project-20170507"

if ! test -d ${repoSrcStr}; then
	git clone https://github.com/llvm-project/llvm-project-20170507 ${repoSrcStr}
else
	cd ${repoSrcStr}
	git pull
fi

# start building

mkdir -p ${LLVMBuild}
cd ${LLVMBuild}


cmake ../llvm-project-20170507/llvm -G "Ninja" \
	-DCMAKE_BUILD_TYPE=Release \
	-DLLVM_BINUTILS_INCDIR=/usr/include \
	-DCMAKE_C_FLAGS="-march=native -O3" \
	-DCMAKE_CXX_FLAGS="-march=native   -D_GLIBCXX_DEBUG  -O3" \
	-DLLVM_PARALLEL_LINK_JOBS=1 \
	-DLLVM_TARGETS_TO_BUILD="X86" \
	-DLLVM_OPTIMIZED_TABLEGEN=1 \
	-DLLVM_BUILD_TOOLS=0 \
	-DLLVM_ENABLE_EXPENSIVE_CHECKS=1  \
    -DLLVM_ENABLE_ASSERTIONS=1 \
	-DLLVM_ENABLE_PROJECTS="llvm;clang;lld" \
	-DLLVM_USE_SANITIZER="Address;Undefined" \
	-DLLVM_LIT_ARGS="--timeout 300 -sv" 

echo -e "\e[95mbuilding stage 1\e[39m"

#nice -n 15 ninja -l $procs -j $procs Polly || exit
echo -e "\e[95mrunning stage 1 tests\e[39m"
nice -n 15 ninja -l $procs -j $procs  check-lld  || exit
echo -e "\e[95mstage 1 done\e[39m"



# clang compiled with system clang is done
# now, compile clang again with the newly built version
cd ${rootDir}

export cloneRoot=${rootDir}/stage_1/${repoSrcStr}
mkdir -p stage_2
cd stage_2
export stageBase=`pwd`

export LLVMObjects=${stageBase}/objects # build in here
export LLVMBuild=${stageBase}/build     # make install into here
export LLVMTest=${stageBase}/test       # compile and exec tests here


# we can simply clone from local to local repo, no need to pull everything from the net again

if ! test -d ${repoSrcStr}; then
    git clone ${cloneRoot} ${repoSrcStr}
else
	cd ${repoSrcStr}
	git pull
fi


# use new clang++
export CXX="${rootDir}/stage_1/build/bin/clang++"
export CC="${rootDir}/stage_1/build/bin/clang"
mkdir -p ${LLVMObjects}
cd ${LLVMObjects}


cmake ../${repoSrcStr}/llvm -G "Ninja" \
	-DCMAKE_BUILD_TYPE=Release \
	-DLLVM_BINUTILS_INCDIR=/usr/include \
	-DCMAKE_C_FLAGS="-march=native -O3  -g0 -DNDEBUG" \
	-DCMAKE_CXX_FLAGS="-march=native -O3  -g0 -DNDEBUG" \
	-DLLVM_PARALLEL_LINK_JOBS=3 \
	-DLLVM_OPTIMIZED_TABLEGEN=1 \
	-DLLVM_TARGETS_TO_BUILD="X86" \
	-DLLVM_ENABLE_LTO="Full" \
	-DCMAKE_AR="${rootDir}/stage_1/build/bin/llvm-ar" \
	-DCMAKE_RANLIB="${rootDir}/stage_1/build/bin/llvm-ranlib" \
	-DLLVM_USE_LINKER="${rootDir}/stage_1/build/bin/ld.lld"  \
    -DCMAKE_INSTALL_PREFIX="${stageBase}/build/" \
    -DLLVM_LIBDIR_SUFFIX="" \
   	-DLLVM_ENABLE_PROJECTS="all"




export stage2_install_dir=${LLVMBuild}


echo -e "\e[95mBuilding stage 2\e[39m"
nice -n 15 ninja -l $procs -j $procs all || exit

echo -e "\e[95mCompiling done.\e[39m"
echo -e "\e[95mInstalling...\e[39m"
rm -rf ${LLVMBuild}
nice -n 15 ninja -l $procs -j $procs install || exit

echo -e  "\e[95mInstalling done.\e[39m"
# building this will take ages with lto, also take care having automatic core dumps disabled before running
# to do this, find your /etc/systemd/coredump.conf
# and add
#
# [Coredump]
# Storage=none
#

# see  https://wiki.archlinux.org/index.php/Core_dump for more details

# stage 2 is done.
# we can run tests now (stage 3)

# stage 3 has additional debug options and verification enabled

cd ${rootDir}

export cloneRoot=${rootDir}/stage_2/${repoSrcStr}
mkdir -p stage_3_tests
cd stage_3_tests
export stageBase=`pwd`

export LLVMSrc=${stageBase}/${repoSrcStr}

export LLVMObjects=${stageBase}/objects # build in here



echo -e "\e[95mllvm\e[39m"
if ! test -d ${LLVMSrc}; then
    git clone ${cloneRoot} ${repoSrcStr}
else
	cd ${LLVMSrc}
	git pull
fi



# use optimized stage 2 clang++
export CXX="${rootDir}/stage_2/build/bin/clang++"
export CC="${rootDir}/stage_2/build/bin/clang"
mkdir -p ${LLVMObjects}
cd ${LLVMObjects}

echo -e "\e[95mConfiguring tests\e[39m"
cmake ../${repoSrcStr}/llvm -G "Ninja" \
	-DCMAKE_BUILD_TYPE=Release \
	-DLLVM_BINUTILS_INCDIR=/usr/include \
	-DCMAKE_C_FLAGS="-O3 -D_GLIBCXX_DEBUG -g0" \
	-DCMAKE_CXX_FLAGS="-O3  -D_GLIBCXX_DEBUG -g0" \
	-DLLVM_PARALLEL_LINK_JOBS=2 \
	-DLLVM_OPTIMIZED_TABLEGEN=1 \
	-DLLVM_ENABLE_LTO="Full" \
	-DCMAKE_AR="${rootDir}/stage_2/build/bin/llvm-ar" \
	-DCMAKE_RANLIB="${rootDir}/stage_2/build/bin/llvm-ranlib" \
	-DLLVM_USE_LINKER="${rootDir}/stage_2/build/bin/ld.lld" \
	-DLLVM_ENABLE_EXPENSIVE_CHECKS=1  \
    -DLLDB_TEST_C_COMPILER="${rootDir}/stage_3_tests/objects/bin/clang" \
    -DLLDB_TEST_CXX_COMPILER="${rootDir}/stage_3_tests/objects/bin/clang++" \
    -DLLVM_ENABLE_ASSERTIONS=1 \
   	-DLLVM_ENABLE_PROJECTS="all" \
   	-DLLVM_LIT_ARGS="--timeout 300 -sv" 


echo -e "\e[95mBuilding and running stage 3 tests.\e[39m"


# build and run tests now
# export  ASAN_OPTIONS=detect_odr_violation=0
nice -n 15 ninja -l $procs -j $procs check-all  || exit
echo -e "\e[95mstage 3 testing done, tests passed\e[39m"
