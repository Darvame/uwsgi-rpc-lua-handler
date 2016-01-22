local T = {};
local MODIF1 = 173;

local tostring = tostring;
local sub = string.sub;
local byte = string.byte;
local char = string.char;
local meta_index = {};

T._meta = { __index = meta_index; };

T.Error = {
	OK = 0;
	NOT_FULL = 1;
	HANDLER_ERROR = 2;
	BAD_MDF1 = 3;
	BAD_MDF2 = 4;
};

T.New = function(self, handler)
	local rpc = setmetatable({}, self._meta);

	if handler then
		rpc:SetHandler(handler);
	end

	return rpc;
end

meta_index.SetHandler = function(self, handler)

	if type(hanlder) == "function" then
		self._rpc_handler = handler;
	elseif type(handler) == "table" then
		self._rpc_table = handler;
	else
		self._rpc_table = nil;
		self._rpc_handler = nil;
	end
end

local err = T.Error;

local to8 = byte;
local str8 = char;

local to16le = function(str, pos)
	local a1, a2 = byte(str, pos, pos + 1);
	return a1 + a2*0x100;
end

local str16le = function(num)
	local a1 = num % 0x100;
	return char(a1, (num - a1) / 0x100);
end

local function parse(str, index, limit)

	if index >= limit then
		return;
	end

	local off = index + 2 + to16le(str, index);

	return sub(str, index + 2, off - 1), parse(str, off, limit);
end

meta_index.Call = function(self, str, ignore_modif)

	str = tostring(str);

	if (not str or #str < 4) then
		return err.NOT_FULL;
	end

	if not ignore_modif then
		if to8(str, 1) ~= MODIF1 then
			return err.BAD_MDF1;
		end

		if to8(str, 3) ~= 0 then
			return err.BAD_MDF2;
		end
	end

	local pkg_size = to16le(str, 2);

	if (#str - 4 < pkg_size) then
		return err.NOT_FULL;
	end

	local res, ok = self:_rpc_handler(parse(str, 5, pkg_size + 4));

	if not ok then
		return err.HANDLER_ERROR, nil, res;
	end

	return self:_pack_result(res);
end

meta_index._rpc_table = {};

meta_index._rpc_handler = function(self, func, ...)

	local rpc_t = self._rpc_table;

	if not rpc_t[func] then
		return nil, false;
	end

	return rpc_t[func](...), true;
end

-- precalc static
local CONTENT_LENGTH = "CONTENT_LENGTH";

local modif1_b = char(MODIF1);
local modif2_64b = char(5);
local modif2_b = char(0);

local pack64_initial_size = #CONTENT_LENGTH + 4;
local pack64_tail = modif2_64b .. str16le(#CONTENT_LENGTH) .. CONTENT_LENGTH;

meta_index._pack_result = function(self, str)

	str = tostring(str) or "";

	if (#str > 0xffff) then
		local len = tostring(#str);

		return err.OK, (modif1_b .. str16le(#len + pack64_initial_size) .. pack64_tail .. str16le(#len) .. len), str;
	end

	return err.OK, (modif1_b .. str16le(#str) .. modif2_b), str;
end

return T;
