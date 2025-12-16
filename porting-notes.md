# love.js porting notes
- when built with Emscripten 2.0.0, `love.audio.play`, `love.audio.stop`, and `love.audio.pause` result in
  crashes. you must use `Source:play`, `Source:stop`, and `Source:pause`. **note: this is fixed. i think.**
- unpack is replaced with table.unpack in lua 5.2
- for some reason canvas pixel format suppport is weird on this platform.
  [here](#canvas-pixel-format-fix) is a workaround.

## code snippets
### canvas pixel format fix
```lua
local supported_formats = love.graphics.getCanvasFormats()
local format_check_list = {
    "rgba8",
    "srgba8",
    "rgba16",
    "rgba16f",
    "rgba32f",

    -- seems to unconditionally be supported, but as it is 16-bit color
    -- the game will look off. i think.
    "rgba4",
}

local use_format
for _, v in ipairs(format_check_list) do
    if supported_formats[v] then
        use_format = v
        break
    end
end

if use_format == "rgba4" then
    love.window.showMessageBox(
        "Compatibility Warning",
        "Due to compatibility issues with your browser, certain graphical elements may be rendered with only 16-bit color.")
end

local orig_newCanvas = love.graphics.newCanvas
local default_settings = { format = use_format }

local function fix_settings(s)
    if s == nil then
        s = default_settings
    elseif s.format == "normal" or s.format == nil then
        local old_s = s
        s = {}
        for k,v in pairs(old_s) do
            s[k] = v
        end
        s.format = use_format
    end

    return s
end

function love.graphics.newCanvas(w, h, l, s)
    if w == nil then
        w = love.graphics.getWidth()
    end

    if h == nil then
        h = love.graphics.getHeight()
    end

    if type(l) == "number" then
        return orig_newCanvas(w, h, l, fix_settings(s))
    else
        return orig_newCanvas(w, h, fix_settings(l))
    end
end
```

### bit/bit32 compatibility
good enough™ compatibility wrapper. however some lesser-used functionality is
not present.
```lua
if not package.loaded["bit"] then
	local bit32 = package.loaded["bit32"]
	assert(bit32, "lua environment does not have bit/bit32 library!")
	package.loaded["bit"] = bit32
end
```


### vertex shader custom varying fix
some WebGL implementations (namely, Firefox's, at least on Windows) can not
allow varyings to be declared after the main function. this means custom vertex
shaders cannot declare new attributes without throwing a potentially obtuse
error.

to fix this, this code will hoist varyings declared in user code up to before
the LOVE-generated main function when compiling shaders. yes, this is a real
function :p
```lua
local orig_shaderCodeToGLSL = love.graphics._shaderCodeToGLSL
function love.graphics._shaderCodeToGLSL(gles, arg1, arg2)
    local orig_vertexcode, pixelcode = orig_shaderCodeToGLSL(gles, arg1, arg2)
    local vertexcode = orig_vertexcode
    if orig_vertexcode then
        local vlines = {}
        for line in string.gmatch(orig_vertexcode, "[^\r\n]+") do
            vlines[#vlines+1] = line
        end

        local insertion_index = nil
        local is_user_code = false

        for i=1, #vlines do
            local line = vlines[i]

            if string.match(line, "^%s*varying%s.+;%s*$") then
                if is_user_code then
                    assert(insertion_index)
                    local l = table.remove(vlines, i)
                    table.insert(vlines, insertion_index, l)
                elseif not insertion_index then
                    insertion_index = i
                end
            end

            if not is_user_code and (line == "#line 0" or line == "#line 1") then
                is_user_code = true
            end
        end

        vertexcode = table.concat(vlines, "\n")
    end
    
    return vertexcode, pixelcode
end
```