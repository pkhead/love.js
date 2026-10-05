--[[
Lua 5.1/JIT compatibility for Lua 5.2. This file must be `require`'d, at the
earliest, at the start of conf.lua.

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
---@diagnostic disable undefined-global, lowercase-global

local module_root = (...):gsub("%.lua$", "")

-- Lua BitOp compatibility
bit = require(module_root .. ".bitop")
if not package.loaded.bit then
    package.loaded.bit = bit
end

-- Lua 5.2 moves the global unpack into table.unpack.
if unpack == nil then
    unpack = table.unpack
end

-- Lua 5.2 removes setfenv because they redesigned environment overloading. We
-- can emulate setfenv by replacing the _ENV function upvalue using the debug
-- library.
-- TODO: implement getfenv?
if setfenv == nil then
    ---@param f integer|fun(any...):...unknown
    ---@param table table
    ---@return function
    function setfenv(f, table)
        if type(f) == "number" then
            f = debug.getinfo(f, "f").func
        end
        ---@cast f function

        local nm = debug.getupvalue(f, 1)
        if nm ~= "_ENV" then
           error("could not set function env")
        end

        debug.setupvalue(f, 1, table)
        return f
    end
end

-- Lua 5.2 removes newproxy because the __gc and __len metamethods were
-- implemented for tables, rendering the already undocumented and experimental
-- feature useless. We can thus emulate newproxy by returning a table.
if newproxy == nil then
    local vmaj, vmin = string.match(_VERSION, "Lua (%d+)%.(%d+)")
    vmaj = tonumber(vmaj)
    vmin = tonumber(vmin)

    if not (vmaj > 5 or (vmaj == 5 and vmin >= 2)) then
        error("Lua version is <5.2 but with no support for newproxy?")
    end

    local function noop() end

    ---@param proxy boolean|table|userdata
    ---@nodiscard
    function newproxy(proxy)
        if type(proxy) == "userdata" or type(proxy) == "table" then
            return setmetatable({}, getmetatable(proxy))
        end

        local res = {}
        if proxy then
            -- dummy __gc function, because tables are only marked for
            -- finalization on the call for setmetatable. in other words, if the
            -- __gc field is not set at the time of setmetatable, it will never
            -- be called.
            setmetatable(res, { __gc = noop })
            getmetatable(res).__gc = nil
        end
        return res
    end
end
