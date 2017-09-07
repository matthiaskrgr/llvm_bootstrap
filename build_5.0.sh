#!/bin/bash
VERSION="5.0.0"
RC=""

#get archives
wget -c "http://releases.llvm.org/${VERSION}/llvm-${VERSION}.src.tar.xz"
wget -c "http://releases.llvm.org/${VERSION}/cfe-${VERSION}.src.tar.xz"
wget -c "http://releases.llvm.org/${VERSION}/compiler-rt-${VERSION}.src.tar.xz"
wget -c "http://releases.llvm.org/${VERSION}/lld-${VERSION}.src.tar.xz"
wget -c "http://releases.llvm.org/${VERSION}/polly-${VERSION}.src.tar.xz"
wget -c "http://releases.llvm.org/${VERSION}/clang-tools-extra-${VERSION}.src.tar.xz"
wget -c "http://releases.llvm.org/${VERSION}/lldb-${VERSION}.src.tar.xz"

# This script bootstraps llvm, clang and friends in optimized way
# requires gold linker (for lto) http://llvm.org/docs/GoldPlugin.html 
# and ninja https://ninja-build.org/

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

cd ${rootDir}
echo llvm
if ! test -d ${LLVMSrc}; then
	mkdir ${LLVMSrc}
	tar xvfJ llvm-${VERSION}.src.tar.xz   -C ${LLVMSrc}  --strip-components=1
else
	cd ${LLVMSrc}
	echo "llvm: nothing to do"
fi
cd ${rootDir}

echo clang
if ! test -d ${clangSrc}; then
	mkdir ${clangSrc}
	tar xvfJ cfe-${VERSION}.src.tar.xz   -C ${clangSrc}  --strip-components=1
else
	cd ${clangSrc}
	echo "clang: nothing to do"
fi
cd ${rootDir}


echo clang-tools-extra
if ! test -d ${toolsExtraSrc}; then
	mkdir ${toolsExtraSrc}
	tar xvfJ clang-tools-extra-${VERSION}.src.tar.xz   -C ${toolsExtraSrc}  --strip-components=1
else
	cd ${toolsExtraSrc}
	echo "clang tools extra: nothing to do"
fi
cd ${rootDir}


echo compiler-rt
if ! test -d ${compilerRTSrc}; then
    mkdir ${compilerRTSrc}
    tar xvfJ compiler-rt-${VERSION}.src.tar.xz   -C ${compilerRTSrc}  --strip-components=1
else
	cd ${compilerRTSrc}
	echo "compiler-rt: nothing to do"
fi
cd ${rootDir}



echo polly
if ! test -d ${pollySrc}; then
	mkdir ${pollySrc}
	tar xvfJ polly-${VERSION}.src.tar.xz -C ${pollySrc} --strip-components=1
else
	cd ${pollySrc}
	echo "polly: nothing to do"
fi
cd ${rootDir}

echo lld
if ! test -d ${lldSRC}; then
	mkdir ${lldSRC}
	tar xvfJ lld-${VERSION}.src.tar.xz -C ${lldSRC} --strip-components=1
else
	cd ${lldSRC}
	echo "lld: nothing to do"
fi

cd ${rootDir}/stage_1/


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


echo -e "\e[95mbuilding stage 1\e[39m"
nice -n 15 ninja-build -l $procs -j $procs clang LLVMgold llvm-ar llvm-ranlib lld || exit
echo -e "\e[95mrunning stage 1 tests\e[39m"
nice -n 15 ninja-build -l $procs -j $procs check-llvm check-clang check-lld || exit
echo -e "\e[95mstage 1 done\e[39m"

exit

# clang compiled with system clang is done
# now, compile clang again with the newly built version
cd ${rootDir}

export cloneRoot=${rootDir}/stage_1/
mkdir -p stage_2
cd stage_2

# instead of extracting all the tars again, we can simply copy "llvm" dir into stage2
export stageBase=`pwd`
cd ${stageBase}
echo "copying files"
cp --reflink=auto -r ${LLVMSrc} ./

export LLVMSrc=${stageBase}/llvm
export clangSrc=${LLVMSrc}/tools/clang
export toolsExtraSrc=${LLVMSrc}/tools/clang/tools/extra
export compilerRTSrc=${stageBase}/llvm/projects/compiler-rt
export pollySrc=${stageBase}/llvm/tools/polly
export lldSRC=${stageBase}/llvm/tools/lld

export LLVMObjects=${stageBase}/objects # build in here
export LLVMBuild=${stageBase}/build     # make install into here


# use new clang++
export CXX="${rootDir}/stage_1/build/bin/clang++"
export CC="${rootDir}/stage_1/build/bin/clang"
mkdir -p ${LLVMObjects}
cd ${LLVMBuild}


cmake ../llvm -G "Ninja" \
	-DCMAKE_BUILD_TYPE=Release \
	-DLLVM_BINUTILS_INCDIR=/usr/include \
	-DCMAKE_C_FLAGS="-march=native -O3  -g0 -DNDEBUG" \
	-DCMAKE_CXX_FLAGS="-march=native -O3  -g0 -DNDEBUG" \
	-DLLVM_PARALLEL_LINK_JOBS=2 \
	-DLLVM_OPTIMIZED_TABLEGEN=1 \
	-DLLVM_TARGETS_TO_BUILD="X86" \
	-DLLVM_ENABLE_LTO="Full" \
	-DCMAKE_AR="${rootDir}/stage_1/build/bin/llvm-ar" \
	-DCMAKE_RANLIB="${rootDir}/stage_1/build/bin/llvm-ranlib" \
	-DLLVM_USE_LINKER="${rootDir}/stage_1/build/bin/ld.lld" \
    -DCMAKE_INSTALL_PREFIX="${LLVMBuild}" \
    -DLLVM_LIBDIR_SUFFIX=64 \

echo "building stage 2"
nice -n 15 ninja-build -l $procs -j $procs all || exit
#echo "clearning install dir"
#rm -r "${LLVMBuild}"
echo "installing stage 2"
nice -n 15 ninja-build -l $procs -j $procs install || exit
echo -e  "Installing done"
echo "stage 2 done"


echo "stage 3 tests"
mkdir -p stage_3_tests
cd stage_3_tests
export stageBase=`pwd`
cd ${stageBase}
echo "copying files"
cp --reflink=auto -r ${LLVMSrc} ./

export LLVMSrc=${stageBase}/llvm
export clangSrc=${LLVMSrc}/tools/clang
export toolsExtraSrc=${LLVMSrc}/tools/clang/tools/extra
export compilerRTSrc=${stageBase}/llvm/projects/compiler-rt
export pollySrc=${stageBase}/llvm/tools/polly
export lldSRC=${stageBase}/llvm/tools/lld

export LLVMBuild=${stageBase}/build




# use new clang++
export CXX="${rootDir}/stage_2/build/bin/clang++"
export CC="${rootDir}/stage_2/build/bin/clang"
mkdir -p ${LLVMBuild}
cd ${LLVMBuild}


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
    

nice -n 15 ninja-build -l $procs -j $procs check-all  || exit
echo -e "\e[95mstage 3 testing done, tests passed\e[39m"
