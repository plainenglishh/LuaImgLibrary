local net = require("@lune/net");

local context = {};

function context.http_get(url: string): string
    local req = net.request({
        method = "GET",
        url = url
    });

    assert(req.ok, "Request failed.");

    return req.body;
end

function context.guid(): string
    -- Yoinked from https://uuidgenerator.dev/uuid-in-lua as lune doesnt have a method for generating UUIDs.
    local template = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[x]', function(c)
        local v = math.random(0, 0xf)
        return string.format('%x', v)
    end);
end

return context;