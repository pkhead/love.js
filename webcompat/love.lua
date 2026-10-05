--[[
Fix for love.graphics quirks when running on WebGL. This file must be executed,
at the earliest, at the start of main.lua.

Permission to use, copy, modify, and/or distribute this software for
any purpose with or without fee is hereby granted.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE
FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY
DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT
OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
--]]

-- "normal" (i.e. "rgba8"), for some odd reason, may not be supported. This
-- function intercepts love.graphics.newCanvas to fall back to a different but
-- supported pixel format with equal or higher precision whenever a canvas with
-- the "normal" pixel format is created.
-- (i think srgba8 is exactly equivalent to rgba8?)
local function canvas_format_fix()
    local supported_formats = love.graphics.getCanvasFormats()
    local format_check_list = {
        "rgba8",
        "srgba8",
        "rgba16",
        "rgba16f",
        "rgba32f",

        -- seems to unconditionally be supported, but as it is 16-bit color
        -- the game will look very off. i think.
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
        print("WARNING: Could not find suitable default canvas pixel format. Falling back to rgba4.")
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

    ---@diagnostic disable-next-line
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
end

-- Some WebGL implementations (namely, at the time of writing, D3D11 Firefox)
-- refuses to compile shaders with varyings declared after the main function.
-- This means custom vertex shaders cannot declare new attributes without
-- raising an error (with a potentially obtuse error message).
--
-- To fix this, this function will intercept the LOVE shader processing to hoist
-- varyings defined in user code up to before the LOVE-generated main function.
-- (yes, this is a real function :p)
local function shader_varying_fix()
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
end

if love.system.getOS() == "Web" then
    canvas_format_fix()
    shader_varying_fix()
end
