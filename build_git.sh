#!/bin/bash

# This script bootstraps llvm, clang and friends in optimized way
# requires gold linker (for lto) and ninja

procs=5 #number of jobs to run at a time
export CCACHE_DISABLE=1 #disable ccache
rootDir=`pwd` #cwd

mkdir -p  stage_1
cd stage_1

export stageBase=`pwd`
export LLVMSrc=${stageBase}/llvm  #llvm
export clangSrc=${LLVMSrc}/tools/clang  #clang
export toolsExtraSrc=${LLVMSrc}/tools/clang/tools/extra #tools
export compilerRTSrc=${LLVMSrc}/projects/compiler-rt #sanitizers
export pollySrc=${LLVMSrc}/tools/polly #polly
export lldSRC=${stageBase}/llvm/tools/lld #lld linker

# build dir
export LLVMBuild=${stageBase}/build
#compilers to use for stage 1
export CXX=clang++
export CC=clang


echo "Cloning/updating repos..."


echo llvm
if ! test -d ${LLVMSrc}; then
    git clone http://llvm.org/git/llvm.git ${LLVMSrc}
else
	cd ${LLVMSrc}
	git pull
fi

echo clang
if ! test -d ${clangSrc}; then
    git clone http://llvm.org/git/clang.git ${clangSrc}
else
	cd ${clangSrc}
	git pull
fi

echo clang-tools-extra
if ! test -d ${toolsExtraSrc}; then
    git clone http://llvm.org/git/clang-tools-extra.git ${toolsExtraSrc}
else
	cd ${toolsExtraSrc}
	git pull
fi

echo compiler-rt
if ! test -d ${compilerRTSrc}; then
    git clone http://llvm.org/git/compiler-rt.git ${compilerRTSrc}
else
	cd ${compilerRTSrc}
	git pull
fi

echo polly
if ! test -d ${pollySrc}; then
    git clone http://llvm.org/git/polly.git ${pollySrc}
else
	cd ${pollySrc}
	git pull
fi

echo lld
if ! test -d ${lldSRC}; then
    git clone http://llvm.org/git/lld.git ${lldSRC}
else
	cd ${lldSRC}
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

nice -n 15 ninja-build -l $procs -j $procs clang  llvm-ar llvm-ranlib
echo "stage 1 done"

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

export LLVMBuild=${stageBase}/build


# we can simply clone from local to local repo, no need to pull everything from the net again

echo llvm
if ! test -d ${LLVMSrc}; then
    git clone ${cloneRoot}/llvm ${LLVMSrc}
else
	cd ${LLVMSrc}
	git pull
fi

echo clang
if ! test -d ${clangSrc}; then
    git clone ${cloneRoot}/llvm/tools/clang ${clangSrc}
else
	cd ${clangSrc}
	git pull
fi

echo tools
if ! test -d ${toolsExtraSrc}; then
    git clone ${cloneRoot}/llvm/tools/clang/tools/extra ${toolsExtraSrc}
else
	cd ${toolsExtraSrc}
	git pull
fi

if ! test -d ${compilerRTSrc}; then
    git clone  ${cloneRoot}/llvm/projects/compiler-rt ${compilerRTSrc}
else
	cd ${compilerRTSrc}
	git pull
fi


if ! test -d ${pollySrc}; then
    git clone  ${cloneRoot}/llvm/tools/polly ${pollySrc}
else
	cd ${pollySrc}
	git pull
fi


if ! test -d ${lldSRC}; then
    git clone  ${cloneRoot}/llvm/tools/lld ${lldSRC}
else
	cd ${lldSRC}
	git pull
fi



# use new clang++
export  CXX="${rootDir}/stage_1/build/bin/clang++"
export  CC="${rootDir}/stage_1/build/bin/clang"
mkdir -p ${LLVMBuild}
cd ${LLVMBuild}



cmake ../llvm -G "Ninja" \
	-DCMAKE_BUILD_TYPE=Release \
	-DLLVM_BINUTILS_INCDIR=/usr/include \
	-DCMAKE_C_FLAGS="-march=native -O3  -g0 -DNDEBUG" \
	-DCMAKE_CXX_FLAGS="-march=native -O3  -g0 -DNDEBUG" \
	-DLLVM_PARALLEL_LINK_JOBS=2 \
	-DLLVM_OPTIMIZED_TABLEGEN=1 \
	-DLLVM_TARGETS_TO_BUILD="X86" \
	-DLLVM_ENABLE_LTO="On" \
	-DCMAKE_AR=${root_dir}/stage_1/build/bin/llvm-ar \
	-DCMAKE_RANLIB=${root_dir}/stage_1/build/bin/llvm-ranlib



nice -n 15 make -l $procs -j $procs clang  LLVMgold asan ubsan  scan-build llvm-objdump llvm-opt-report compiler-rt lld llvm-ar llvm-ranlib    #checks all
echo "stage 2 done"
