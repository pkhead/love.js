--[[
Lua BitOp implementation using either the bit32 module or Lua 5.3+ bitwise
operators.

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
---@diagnostic disable

if bit then return bit end

if require then
  local s, v
  s, v = pcall(require, "bit")
  if s then return v end

  local b32
  s, b32 = pcall(require, "bit32")
  if s then    
    local band = b32.band
    local bor = b32.bor
    local bnot = b32.bnot
    local bxor = b32.bxor
    local lshift = b32.lshift
    local rshift = b32.rshift
    local arshift = b32.arshift
    local lrotate = b32.lrotate
    local rrotate = b32.rrotate
    
    local function asi32(x)
      return band(math.floor(x + 0.5), 0xffffffff)
    end

    local function tobit(x)
      -- sign-extend integer
      local m = 0x80000000
      return bxor(band(x, 0xffffffff), m) - m
    end

    return {
      tobit = tobit,
      tohex = function(x, n)
        if n == 0 then return "" end
        if n == nil then n = 8 end
        
        local t
        if n > 0 then
          t = "x"
        else
          t = "X"
          n = -n
        end
        
        return string.sub(string.format("%."..n..t, asi32(x)), -n)
      end,
      bnot = function(n) return tobit(bnot(n)) end,
      band = function(...)
        if (...) == nil then
          error("invalid number input to bitop", 2)  
        end
        for i=1, select("#", ...) do
          if type(select(i, ...)) ~= "number" then
            error("invalid number input to bitop", 2)
          end
        end

        return tobit(band(...))
      end,
      bor = function(...)
        if (...) == nil then
          error("invalid number input to bitop", 2)  
        end
        for i=1, select("#", ...) do
          if type(select(i, ...)) ~= "number" then
            error("invalid number input to bitop", 2)
          end
        end

        return tobit(bor(...))
      end,
      bxor = function(...)
        if (...) == nil then
          error("invalid number input to bitop", 2)  
        end
        for i=1, select("#", ...) do
          if type(select(i, ...)) ~= "number" then
            error("invalid number input to bitop", 2)
          end
        end

        return tobit(bxor(...))
      end,
      lshift = function(x, n)
        return tobit(lshift(x, band(n, 31)))
      end,
      rshift = function(x, n)
        return tobit(rshift(asi32(x), band(n, 31)))
      end,
      arshift = function(x, n)
        return tobit(arshift(asi32(x), band(n)))
      end,
      rol = function(x, n)
        return tobit(lrotate(asi32(x), band(n)))
      end,
      ror = function(x, n)
        return tobit(rrotate(asi32(x), band(n)))
      end,
      bswap = function(x)
        x = asi32(x)
        local b1, b2, b3, b4 =
          band(x, 255),
          band(rshift(x, 8), 255),
          band(rshift(x, 16), 255),
          band(rshift(x, 24), 255)
          
        return tobit(bor(lshift(b1, 24), lshift(b2, 16), lshift(b3, 8), b4))
      end
    }
  end
end

-- Neither bit or bit32 exists. Could either be an old version of Lua, or 5.4+,
-- which removes the bit32 module in favor of its built-in bitwise operators.
-- Assume the latter. Also load and run it as a dynamically loaded string
-- so that Lua versions older than 5.3 don't generate a syntax error when
-- loading this file.
return (loadstring or load)([[
local U32_MAX = 0xffffffff

local function asi32(x)
  if math.type(x) ~= "integer" then
    return math.tointeger(math.floor(x + 0.5)) & U32_MAX
  else
    return x & U32_MAX
  end
end

local function tobit(x)
  if math.type(x) ~= "integer" then
    x = math.tointeger(math.floor(x + 0.5))
  end

  -- sign-extend integer
  local m = 0x80000000
  return ((x & U32_MAX) ~ m) - m
end

return {
	tobit = tobit,
	tohex = function(x, n)
    if n == 0 then return "" end
    if n == nil then n = 8 end
    
    local t
    if n > 0 then
      t = "x"
    else
      t = "X"
      n = -n
    end
    
    return string.sub(string.format("%."..n..t, asi32(x)), -n)
	end,
	bnot = function(n) return ~tobit(n) end,
	band = function(...)
    local v = ...
    for i=2, select("#", ...) do
      v = v & (select(i, ...))
		end
		return tobit(v)
	end,
	bor = function(...)
		local v = ...
		for i=2, select("#", ...) do
			v = v | (select(i, ...))
		end
		return tobit(v)
	end,
	bxor = function(...)
		local v = ...
		for i=2, select("#", ...) do
			v = v ~ (select(i, ...))
		end
		return tobit(v)
	end,
	lshift = function(x, n)
		return tobit(x << (n & 31))
	end,
	rshift = function(x, n)
		return tobit(asi32(x) >> (n & 31))
	end,
	arshift = function(x, n)
		n = n & 31
    x = asi32(x)
    local m = (x & 0x80000000) >> n
    return tobit( ((x >> n) ~ m) - m )
	end,
	rol = function(x, n)
		n = n & 31
    x = asi32(x)
		return tobit((x << n) | (x >> (32 - n)))
	end,
	ror = function(x, n)
		n = n & 31
    x = asi32(x)
		return tobit((x << (32 - n)) | (x >> n))
	end,
	bswap = function(x)
    x = asi32(x)
		local b1, b2, b3, b4 =
			x & 255,
			(x >> 8) & 255,
			(x >> 16) & 255,
			(x >> 24) & 255
    	
		return tobit((b1 << 24) | (b2 << 16) | (b3 << 8) | b4)
	end
}
]])()
