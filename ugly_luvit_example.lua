local rpc = require "uwsgi-rpc-lua-handler";
local uv = require "uv";

local c_again = rpc.Error.MALFORMED;
local c_nfull = rpc.Error.NOT_FULL;
local c_ok = rpc.Error.OK;

local rpc_func = {};
local rpc_handler = rpc:New(rpc_func);

local server = uv.new_tcp();
server:bind("127.0.0.1", 3000);

server:listen(128, function(err)

	assert(not err, err);
	local client = uv.new_tcp();
	local data = "";
	local dtable;
	local dlen;
	local dneed;

	local on_shutdown = function()
		if not client:is_closing() then
			client:close();
		end
	end

	server:accept(client);

	client:read_start(function(err, chunk)

		if err then
			on_shutdown();
			return;
		end

		if not data or not chunk then -- already done or empty
			return;
		end

		local code, header, body;

		if dtable then

			dlen = dlen + #chunk;
			dtable[#dtable + 1] = chunk;

			if dlen < dneed then
					return;
			end

			code, header, body = rpc_handler:Call(table.concat(dtable));
		else

			data = data .. chunk;

			code, header, body = rpc_handler:Call(data);
		end

		if code ~= c_ok then
			if code == c_again then
				return; -- again, wait for next chunk
			end

			if code == c_nfull then
				dtable = {data};
				dlen = #data;
				bneed = header;
				return;
			end

			client:shutdown(on_shutdown);
			return;
		end

		data = nil; -- stop next reading

		client:write(header);
		client:write(body);
		client:shutdown(on_shutdown);

    end);

end);


-- register rpc:
rpc_func.Hello = function()
	return("HI");
end

rpc_func.AAA = function()
	return ("A"):rep(0x10000000);
end

rpc_func.AA = function()
	return ("A"):rep(0x1000);
end

rpc_func.mathSum = function(x, y)
	return tonumber(x) + tonumber(y);
end

rpc_func.mathDiv = function(x, y)
	return tonumber(x) / tonumber(y);
end

rpc_func.printArgs = function(...)
	return table.concat({...}, ", ");
end

uv.run();
