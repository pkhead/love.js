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
    shader_varying_fix()
end
