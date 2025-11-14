The following changes were made to megasource/love in order to build it with
Emscripten 4.0.19 and WebAssembly exceptions support. You can use the Unix patch
utility (or git apply) to apply these changes when building from source.

(i'm too lazy to fork both megasource and love to maintain these changes.)

## megasource/CMakeLists.txt
```patch
diff --git a/CMakeLists.txt b/CMakeLists.txt
--- a/CMakeLists.txt
+++ b/CMakeLists.txt
@@ -164,6 +164,14 @@ if(MSVC)
 	set(MEGA_MSVC_DLLS ${CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS})
 endif()
 
+if (EMSCRIPTEN)
+	if (NOT LOVEJS_COMPAT)
+		add_definitions("-pthread -s PTHREAD_POOL_SIZE=8")
+	endif()
+
+	add_definitions("-fwasm-exceptions -s WASM_LEGACY_EXCEPTIONS=0")
+endif()
+
 
 set(MEGA_ZLIB_VER "1.2.12")
 set(MEGA_LUA51_VER "5.1.5")
```

### love/CMakeLists.txt
```patch
diff --git a/CMakeLists.txt b/CMakeLists.txt
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
@@ -1798,9 +1794,12 @@ if(EMSCRIPTEN)
 		"-s EXPORT_NAME=\"'Love'\""	
 		"-s WASM=1"
 		"-s FULL_ES2=1"	
-		"-s DISABLE_EXCEPTION_CATCHING=0" # Might be worth building a whitelist for EXCEPTION_CATCHING_WHITELIST
+		"-fwasm-exceptions"
+		"-s WASM_LEGACY_EXCEPTIONS=0"
 		"-s ALLOW_MEMORY_GROWTH=1" # for dynamic resizing of memory, should not have a performance impact as using WASM
 		"-s FORCE_FILESYSTEM=1" # to fix Module.addDependency not existing
+		"-s EXPORTED_FUNCTIONS=_malloc,_main"
+		"-s EXPORTED_RUNTIME_METHODS=HEAPU8"
 		"-lidbfs.js" # to fix the ReferenceError: IDBFS is not defined
        "-lwebsocket.js" # websocket API
 	)
@@ -1808,7 +1808,7 @@ if(EMSCRIPTEN)
 	if(NOT LOVEJS_COMPAT)
 		set(EMSCRIPTEN_ARGS
 			${EMSCRIPTEN_ARGS}
-			"-s USE_PTHREADS=1"
+			"-pthread"
 			"-s PTHREAD_POOL_SIZE=8"	
 		)
 	endif()
```

### love/src/common/Exception.cpp
```patch
diff --git a/src/common/Exception.cpp b/src/common/Exception.cpp
--- a/src/common/Exception.cpp
+++ b/src/common/Exception.cpp
@@ -61,12 +61,6 @@ Exception::Exception(const char *fmt, ...)
 		delete[] buffer;
 	}
 	message = std::string(buffer);
-  
-	#if LOVE_EMSCRIPTEN
-		// TODO: replace with a nice console.error call (ie figure out how to pass multi-line string to it properly)
-		std::cout << message << std::endl;
-		emscripten_run_script("alert('An error occurred before the game window could be initialised. Please check the console!')");
-	#endif
 
 	delete[] buffer;
 }
```