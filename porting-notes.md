# love.js porting notes
- `love.audio.play`, `love.audio.stop`, and `love.audio.pause` result in
  crashes. you must use `Source:play`, `Source:stop`, and `Source:pause`.
- unpack is replaced with table.unpack in lua 5.2
- since rgba8 on canvases is not supported for whatever reason, "normal" pixel
  format falls back to rgba4. obviously undesirable. however, srgba8 is
  supported and seems to work exactly as rgba8 would have. thus, [here](#canvas-pixel-format-fix) is a
  workaround.

## code snippets
### canvas pixel format fix
```lua
local orig_newCanvas = love.graphics.newCanvas
local default_settings = { format = "srgba8" }

local function fix_settings(s)
	if s == nil then
		s = default_settings
	elseif s.format == "normal" or s.format == nil then
		local old_s = s
		s = {}
		for k,v in pairs(old_s) do
			s[k] = v
		end
		s.format = "srgba8"
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
```lua
if not package.loaded["bit"] then
	local bit32 = package.loaded["bit32"]
	assert(bit32, "lua environment does not have bit/bit32 library!")
	package.loaded["bit"] = bit32
end
```