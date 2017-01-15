#!/bin/bash

# This script bootstraps llvm, clang and friends in optimized way
# requires gold linker (for lto)


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
export lldSRC=${BASE}/llvm/tools/lld #lld linker

# build dir
export LLVMBuild=${stageBase}/build
#compilers to use for stage 1
export CXX=clang++
export CC=clang


#now, clone/update the repos

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

cmake ../llvm -G "Unix Makefiles" \
	-DDISABLE_ASSERTIONS=1 \
	-DENABLE_OPTIMIZED=1 \
	-DCMAKE_BUILD_TYPE=Release \
	-DLLVM_BINUTILS_INCDIR=/usr/include \
	-DDEBUG_SYMBOLS=0 \
	-DCMAKE_C_FLAGS="-march=native -O3 -g0 -DNDEBUG" \
	-DCMAKE_CXX_FLAGS="-march=native -O3 -g0 -DNDEBUG" \
	-DLLVM_PARALLEL_LINK_JOBS=1 \
	-DLLVM_TARGETS_TO_BUILD="X86" \
	-DLLVM_OPTIMIZED_TABLEGEN=1 \
	-DLLVM_BUILD_TOOLS=0 

nice -n 15 make -l $procs -j $procs clang # llvm-ar llvm-ranlib
echo "stage 1 done"

# clang compiled with gcc is done
# stage1 done

cd ${root_dir}

mkdir stage_2
cd stage_2

export clone_root=${root_dir}/stage_1/
export BASE=`pwd`
export LLVM_SRC=${BASE}/llvm
export CLANG_SRC=${LLVM_SRC}/tools/clang
export TOOLS_EXTRA_SRC=${LLVM_SRC}/tools/clang/tools/extra
export COMPILERRT_SRC=${BASE}/llvm/projects/compiler-rt
export POLLY_SRC=${BASE}/llvm/tools/polly
export LLD_SRC=${BASE}/llvm/tools/lld


export LLVM_BUILD=${BASE}/build



export  CXX="${root_dir}/stage_1/build/bin/clang++"
export  CC="${root_dir}/stage_1/build/bin/clang"


mkdir -p ${LLVM_BUILD}
cd ${LLVM_BUILD}
cmake ../llvm -G "Unix Makefiles" \
	-DDISABLE_ASSERTIONS=1 \
	-DENABLE_OPTIMIZED=1 \
	-DCMAKE_BUILD_TYPE=Release \
	-DLLVM_BINUTILS_INCDIR=/usr/include \
	-DDEBUG_SYMBOLS=0 \
	-DCMAKE_C_FLAGS="-march=native -O3  -g0 -DNDEBUG" \
	-DCMAKE_CXX_FLAGS="-march=native -O3  -g0 -DNDEBUG" \
	-DLLVM_PARALLEL_LINK_JOBS=1 \
	-DLLVM_OPTIMIZED_TABLEGEN=1 \
	-DLLVM_TARGETS_TO_BUILD="X86" 

	#-DLLVM_ENABLE_LTO="On" 

#export VERBOSE=1


#nice -n 15 make -l $procs -j $procs all  
#nice -n 15 make -l $procs -j $procs check-all || true

nice -n 15 make -l $procs -j $procs clang  LLVMgold asan ubsan  scan-build llvm-objdump llvm-opt-report compiler-rt lld # lld # llvm-ar llvm-ranlib   
#nice -n 15 make  -l $procs -j $procs check-all
echo "stage 2 done"
