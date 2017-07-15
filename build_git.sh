#!/bin/bash
#set -x

# This script bootstraps llvm, clang and friends in optimized way
# requires gold linker (for lto) http://llvm.org/docs/GoldPlugin.html
# and ninja https://ninja-build.org/

procs=3 #number of jobs to run at a time
export CCACHE_DISABLE=1 #disable ccache
rootDir=`pwd` #cwd

echo "Latest builds of buildslave http://lab.llvm.org:8011/builders/clang-with-lto-ubuntu"
# relative paths and symlinks don't mix well, hack around
python3 `readlink $0 | sed s@build_git.sh@BB_status.py@`

mkdir -p  stage_1
cd stage_1

export stageBase=`pwd`
export LLVMSrc=${stageBase}/llvm  #llvm
export clangSrc=${LLVMSrc}/tools/clang  #clang
export toolsExtraSrc=${LLVMSrc}/tools/clang/tools/extra #tools
export compilerRTSrc=${LLVMSrc}/projects/compiler-rt #sanitizers
export pollySrc=${LLVMSrc}/tools/polly #polly
export lldSRC=${LLVMSrc}/tools/lld #lld linker
export lldbSRC=${LLVMSrc}/tools/lldb #lldb debugger
export openmpSrc=${LLVMSrc}/tools/openmp #lldb debugger


# build dir
export LLVMBuild=${stageBase}/build
#compilers to use for stage 1
export CXX=clang++
export CC=clang


echo -e "\e[95mCloning/updating repos...\e[39m"


echo -e "\e[95mllvm\e[39m"
if ! test -d ${LLVMSrc}; then
	git clone http://llvm.org/git/llvm.git ${LLVMSrc}
else
	cd ${LLVMSrc}
	git pull
fi

echo -e "\e[95mclang\e[39m"
if ! test -d ${clangSrc}; then
	git clone http://llvm.org/git/clang.git ${clangSrc}
else
	cd ${clangSrc}
	git pull
fi

echo -e "\e[95mclang-tools-extra\e[39m"
if ! test -d ${toolsExtraSrc}; then
	git clone http://llvm.org/git/clang-tools-extra.git ${toolsExtraSrc}
else
	cd ${toolsExtraSrc}
	git pull
fi

echo -e "\e[95mcompiler-rt\e[39m"
if ! test -d ${compilerRTSrc}; then
    git clone http://llvm.org/git/compiler-rt.git ${compilerRTSrc}
else
	cd ${compilerRTSrc}
	git pull
fi

echo -e "\e[95mpolly\e[39m"
if ! test -d ${pollySrc}; then
	git clone http://llvm.org/git/polly.git ${pollySrc}
else
	cd ${pollySrc}
	git pull
fi

echo -e "\e[95mlld\e[39m"
if ! test -d ${lldSRC}; then
	git clone http://llvm.org/git/lld.git ${lldSRC}
else
	cd ${lldSRC}
	git pull
fi

echo -e "\e[95mlldb\e[39m"
if ! test -d ${lldbSRC}; then
	git clone http://llvm.org/git/lldb.git ${lldbSRC}
else
	cd ${lldbSRC}
	git pull
fi


echo -e "\e[95mopenMP\e[39m"
if ! test -d ${openmpSrc}; then
	git clone http://llvm.org/git/openmp.git ${openmpSrc}
else
	cd ${openmpSrc}
	git pull
fi


# start building

mkdir -p ${LLVMBuild}
cd ${LLVMBuild}

cmake ../llvm -G "Ninja" \
	-DCMAKE_BUILD_TYPE=Release \
	-DLLVM_BINUTILS_INCDIR=/usr/include \
	-DCMAKE_C_FLAGS="-march=native -O3 -g0 -DNDEBUG" \
	-DCMAKE_CXX_FLAGS="-march=native -O3 -g0 -DNDEBUG" \
	-DLLVM_PARALLEL_LINK_JOBS=1 \
	-DLLVM_TARGETS_TO_BUILD="X86" \
	-DLLVM_OPTIMIZED_TABLEGEN=1 \
	-DLLVM_BUILD_TOOLS=0 

nice -n 15 ninja-build -l $procs -j $procs clang LLVMgold llvm-ar llvm-ranlib lld || exit
echo -e "\e[95mrunning stage 1 tests\e[39m"
nice -n 15 ninja-build -l $procs -j $procs check-llvm check-clang check-lld || exit
echo -e "\e[95mstage 1 done\e[39m"


# clang compiled with system clang is done
# now, compile clang again with the newly built version
cd ${rootDir}

export cloneRoot=${rootDir}/stage_1/
mkdir -p stage_2
cd stage_2
export stageBase=`pwd`
export LLVMSrc=${stageBase}/llvm
export clangSrc=${LLVMSrc}/tools/clang
export toolsExtraSrc=${LLVMSrc}/tools/clang/tools/extra
export compilerRTSrc=${stageBase}/llvm/projects/compiler-rt
export pollySrc=${stageBase}/llvm/tools/polly
export lldSRC=${stageBase}/llvm/tools/lld
export lldbSRC=${stageBase}/llvm/tools/lldb
export openmpSrc=${LLVMSrc}/tools/openmp 


export LLVMObjects=${stageBase}/objects # build in here
export LLVMBuild=${stageBase}/build     # make install into here
export LLVMTest=${stageBase}/test       # compile and exec tests here


# we can simply clone from local to local repo, no need to pull everything from the net again

echo -e "\e[95mllvm\e[39m"
if ! test -d ${LLVMSrc}; then
    git clone ${cloneRoot}/llvm ${LLVMSrc}
else
	cd ${LLVMSrc}
	git pull
fi

echo -e "\e[95mclang\e[39m"
if ! test -d ${clangSrc}; then
	git clone ${cloneRoot}/llvm/tools/clang ${clangSrc}
else
	cd ${clangSrc}
	git pull
fi

echo -e "\e[95mclang-tools-extra\e[39m"
if ! test -d ${toolsExtraSrc}; then
	git clone ${cloneRoot}/llvm/tools/clang/tools/extra ${toolsExtraSrc}
else
	cd ${toolsExtraSrc}
	git pull
fi

echo -e "\e[95mcompiler-rt\e[39m"
if ! test -d ${compilerRTSrc}; then
	git clone  ${cloneRoot}/llvm/projects/compiler-rt ${compilerRTSrc}
else
	cd ${compilerRTSrc}
	git pull
fi

echo -e "\e[95mpolly\e[39m"
if ! test -d ${pollySrc}; then
	git clone  ${cloneRoot}/llvm/tools/polly ${pollySrc}
else
	cd ${pollySrc}
	git pull
fi

echo -e "\e[95mlld\e[39m"
if ! test -d ${lldSRC}; then
	git clone  ${cloneRoot}/llvm/tools/lld ${lldSRC}
else
	cd ${lldSRC}
	git pull
fi

echo -e "\e[95mlldb\e[39m"
if ! test -d ${lldbSRC}; then
	git clone  ${cloneRoot}/llvm/tools/lldb ${lldbSRC}
else
	cd ${lldbSRC}
	git pull
fi

echo -e "\e[95mopenMP\e[39m"
if ! test -d ${openmpSrc}; then
	git clone  ${cloneRoot}/llvm/tools/openmp ${openmpSrc}
else
	cd ${openmpSrc}
	git pull
fi

# use new clang++
export CXX="${rootDir}/stage_1/build/bin/clang++"
export CC="${rootDir}/stage_1/build/bin/clang"
mkdir -p ${LLVMObjects}
cd ${LLVMObjects}


cmake ../llvm -G "Ninja" \
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

export TARGETS=" clang LLVMgold asan ubsan scan-build llvm-objdump llvm-opt-report compiler-rt lld llvm-ar llvm-ranlib bugpoint llvm-stress llc llvm-profdata lldb"



nice -n 15 ninja-build -l $procs -j $procs ${TARGETS} || exit
echo -e "\e[95mCompiling done.\e[39m"
echo -e "\e[95mInstalling...\e[39m"
rm -rf ${LLVMBuild}
mkdir -p ${LLVMBuild}
cp ${LLVMObjects}/bin  --force  --recursive --reflink=auto --target-directory ${LLVMBuild}
mkdir ${LLVMBuild}/lib/
cp ${LLVMObjects}/lib/clang  --force  --recursive --reflink=auto --target-directory ${LLVMBuild}/lib/
# @TODO less hacky way to do this:
cp ${LLVMObjects}/libexec/* --force  --recursive --reflink=auto --target-directory ${LLVMBuild}/bin/
cp `find . | grep "\.so"` --force  --recursive --reflink=auto --target-directory ${LLVMBuild}/lib/

echo -e  "\e[95mInstalling done.\e[39m"
# building this will take ages with lto, also take care having automatic core dumps disabled before running
# to do this, find your /etc/systemd/coredump.conf
# and add
#
# [Coredump]
# Storage=none
#

# stage 2 is done.
# we can run tests now (stage 3)

cd ${rootDir}

export cloneRoot=${rootDir}/stage_2/
mkdir -p stage_3_tests
cd stage_3_tests
export stageBase=`pwd`
export LLVMSrc=${stageBase}/llvm
export clangSrc=${LLVMSrc}/tools/clang
export toolsExtraSrc=${LLVMSrc}/tools/clang/tools/extra
export compilerRTSrc=${stageBase}/llvm/projects/compiler-rt
export pollySrc=${stageBase}/llvm/tools/polly
export lldSRC=${stageBase}/llvm/tools/lld
export lldbSRC=${stageBase}/llvm/tools/lldb
export debuginfoTestsSrc=${LLVMSrc}/tools/clang/test/debuginfo-tests #clang debuginfo tests 
export openmpSrc=${LLVMSrc}/tools/openmp 


export LLVMObjects=${stageBase}/objects # build in here


echo -e "\e[95mllvm\e[39m"
if ! test -d ${LLVMSrc}; then
    git clone ${cloneRoot}/llvm ${LLVMSrc}
else
	cd ${LLVMSrc}
	git pull
fi

echo -e "\e[95mclang\e[39m"
if ! test -d ${clangSrc}; then
	git clone ${cloneRoot}/llvm/tools/clang ${clangSrc}
else
	cd ${clangSrc}
	git pull
fi

echo -e "\e[95mclang-tools-extra\e[39m"
if ! test -d ${toolsExtraSrc}; then
	git clone ${cloneRoot}/llvm/tools/clang/tools/extra ${toolsExtraSrc}
else
	cd ${toolsExtraSrc}
	git pull
fi

echo -e "\e[95mcompiler-rt\e[39m"
if ! test -d ${compilerRTSrc}; then
	git clone  ${cloneRoot}/llvm/projects/compiler-rt ${compilerRTSrc}
else
	cd ${compilerRTSrc}
	git pull
fi

echo -e "\e[95mpolly\e[39m"
if ! test -d ${pollySrc}; then
	git clone  ${cloneRoot}/llvm/tools/polly ${pollySrc}
else
	cd ${pollySrc}
	git pull
fi

echo -e "\e[95mlld\e[39m"
if ! test -d ${lldSRC}; then
	git clone  ${cloneRoot}/llvm/tools/lld ${lldSRC}
else
	cd ${lldSRC}
	git pull
fi

echo -e "\e[95mlldb\e[39m"
if ! test -d ${lldbSRC}; then
	git clone  ${cloneRoot}/llvm/tools/lldb ${lldbSRC}
else
	cd ${lldbSRC}
	git pull
fi

echo -e "\e[95mdebuginfo-tests\e[39m"
if ! test -d ${debuginfoTestsSrc}; then
	git clone http://llvm.org/git/debuginfo-tests.git ${debuginfoTestsSrc}
else
	cd ${debuginfoTestsSrc}
	git pull
fi

echo -e "\e[95mopenMP\e[39m"
if ! test -d ${openmpSrc}; then
	git clone  ${cloneRoot}/llvm/tools/openmp ${openmpSrc}
else
	cd ${openmpSrc}
	git pull
fi

# use optimized stage 2 clang++
export CXX="${rootDir}/stage_2/build/bin/clang++"
export CC="${rootDir}/stage_2/build/bin/clang"
mkdir -p ${LLVMObjects}
cd ${LLVMObjects}

echo -e "\e[95mConfiguring tests\e[39m"
cmake ../llvm -G "Ninja" \
	-DCMAKE_BUILD_TYPE=Release \
	-DLLVM_BINUTILS_INCDIR=/usr/include \
	-DCMAKE_C_FLAGS="-O3  -g0" \
	-DCMAKE_CXX_FLAGS="-O3  -g0" \
	-DLLVM_PARALLEL_LINK_JOBS=2 \
	-DLLVM_OPTIMIZED_TABLEGEN=1 \
	-DLLVM_ENABLE_LTO="Full" \
	-DCMAKE_AR="${rootDir}/stage_2/build/bin/llvm-ar" \
	-DCMAKE_RANLIB="${rootDir}/stage_2/build/bin/llvm-ranlib" \
	-DLLVM_USE_LINKER="${rootDir}/stage_2/build/bin/ld.lld" \
	-DLLVM_ENABLE_EXPENSIVE_CHECKS=1 \

echo -e "\e[95mBuilding and running tests.\e[39m"


# build and run tests now
# export  ASAN_OPTIONS=detect_odr_violation=0
nice -n 15 ninja-build -l $procs -j $procs check-all  || exit
echo -e "\e[95mstage 3 testing done, tests run\e[39m"
