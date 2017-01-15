#!/bin/bash
root_dir=`pwd`

mkdir -p  stage_1
cd stage_1


#if [ -z $procs ] ; then
	procs=5
#fi

export BASE=`pwd`
export LLVM_SRC=${BASE}/llvm
export CLANG_SRC=${LLVM_SRC}/tools/clang
export TOOLS_EXTRA_SRC=${LLVM_SRC}/tools/clang/tools/extra
export COMPILERRT_SRC=${BASE}/llvm/projects/compiler-rt
export POLLY_SRC=${BASE}/llvm/tools/polly
#export LIBCXX_SRC=${BASE}/llvm/tools/libcxx #cxx libs
#export LIBCXXABI_SRC=${BASE}/llvm/projects/libc++abi
export LLD_SRC=${BASE}/llvm/tools/lld

export LLVM_BUILD=${BASE}/build

export CXX=clang++
export CC=clang


export CCACHE_DISABLE=1

mkdir -p ${LLVM_BUILD}
cd ${LLVM_BUILD}
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
