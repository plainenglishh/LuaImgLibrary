--!nocheck
local ctx = require("./runtime.lua");

local util = {};

function util.deep_copy(obj)
    if type(obj) ~= "table" then
        return obj;
    end

    local new = setmetatable({}, getmetatable(obj));

    for i, v in pairs(obj) do
        new[util.deep_copy(i)] = util.deep_copy(v);
    end
    
    return new;
end

util.http_get = ctx.http_get;
util.guid = ctx.guid;

return util;