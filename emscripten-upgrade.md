The following changes were made to megasource/love in order to build it with
Emscripten 4.0.19. You can use the unix patch utility (or git apply) to apply
these changes when building from source.

(i'm too lazy to fork both megasource and love to maintain these changes.)

## megasource/CMakeLists.txt
```patch
diff --git a/CMakeLists.txt b/CMakeLists.txt
index 6c37f79a..d36d1508 100755
--- a/CMakeLists.txt
+++ b/CMakeLists.txt
@@ -164,6 +164,10 @@ if(MSVC)
 	set(MEGA_MSVC_DLLS ${CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS})
 endif()
 
+if (EMSCRIPTEN AND NOT LOVEJS_COMPAT)
+	add_definitions("-pthread -s PTHREAD_POOL_SIZE=8")
+endif()
+
 
 set(MEGA_ZLIB_VER "1.2.12")
 set(MEGA_LUA51_VER "5.1.5")
```

### love/CMakeLists.txt
```patch
diff --git a/CMakeLists.txt b/CMakeLists.txt
index 59a37992..5f1de5d6 100644
--- a/CMakeLists.txt
+++ b/CMakeLists.txt
@@ -1783,11 +1783,7 @@ endif()
 #
 if(EMSCRIPTEN)
     # add_definitions is for other libraries
-	if(LOVEJS_COMPAT)
-		add_definitions("-s USE_SDL=2 -s FULL_ES2=1 -s INVOKE_RUN=0 --post-js ${CMAKE_CURRENT_SOURCE_DIR}/src/scripts/EmscriptenPersistence.js")
-	else()
-		add_definitions("-s USE_PTHREADS=1 -s PTHREAD_POOL_SIZE=8 -s USE_SDL=2 -s FULL_ES2=1 -s INVOKE_RUN=0 --post-js ${CMAKE_CURRENT_SOURCE_DIR}/src/scripts/EmscriptenPersistence.js")
-	endif()
+	add_definitions("-s USE_SDL=2 -s FULL_ES2=1 -s INVOKE_RUN=0 --post-js ${CMAKE_CURRENT_SOURCE_DIR}/src/scripts/EmscriptenPersistence.js")
 
 	add_executable(${LOVE_EXE_NAME} src/love.cpp)	
 	set(EMSCRIPTEN_ARGS	
@@ -1801,6 +1797,8 @@ if(EMSCRIPTEN)
 		"-s DISABLE_EXCEPTION_CATCHING=0" # Might be worth building a whitelist for EXCEPTION_CATCHING_WHITELIST
 		"-s ALLOW_MEMORY_GROWTH=1" # for dynamic resizing of memory, should not have a performance impact as using WASM
 		"-s FORCE_FILESYSTEM=1" # to fix Module.addDependency not existing
+		"-s EXPORTED_FUNCTIONS=_malloc,_main"
+		"-s EXPORTED_RUNTIME_METHODS=HEAPU8"
 		"-lidbfs.js" # to fix the ReferenceError: IDBFS is not defined
         "-lwebsocket.js" # websocket API
 	)
@@ -1808,7 +1806,7 @@ if(EMSCRIPTEN)
 	if(NOT LOVEJS_COMPAT)
 		set(EMSCRIPTEN_ARGS
 			${EMSCRIPTEN_ARGS}
-			"-s USE_PTHREADS=1"
+			"-pthread"
 			"-s PTHREAD_POOL_SIZE=8"	
 		)
 	endif()
```