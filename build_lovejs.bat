@echo off
mkdir build
mkdir build\release
mkdir build\compat

REM TODO:Make the system work like how it is for the bash shell script
call C:\dev\emsdk\emsdk_env

(
echo Building compatibility version...
cd build\compat
emcmake cmake ../../megasource -G "Unix Makefiles" -DLOVE_JIT=0 -DCMAKE_BUILD_TYPE=Release -DLOVEJS_COMPAT=1 -DCMAKE_POLICY_VERSION_MINIMUM=3.5
emmake make -j 6
copy "love\love.js*" ..\..\src\compat
copy "love\love.wasm" ..\..\src\compat
copy "love\libxlove.a" ..\..\src\compat_ext
copy "love\build_flags.txt" ..\..\src\compat_ext
copy "love\emsdk_version.txt" ..\..\src\compat_ext

cd ..\..

echo Building release version...
cd build\release
emcmake cmake megasource -G "Unix Makefiles" -DLOVE_JIT=0 -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5
emmake make -j 6
copy "love\love.js*" ..\..\src\release
copy "love\love.wasm" ..\..\src\release
copy "love\love.worker.js" ..\..\src\release
copy "love\libxlove.a" ..\..\src\release_ext
copy "love\build_flags.txt" ..\..\src\release_ext
copy "love\emsdk_version.txt" ..\..\src\release_ext
)
