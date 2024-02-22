local http_service = game:GetService("HttpService");

local context = {};

function context.http_get(url: string): string
    return http_service:GetAsync(url);
end

function context.guid(): string
    return http_service:GenerateGUID(false);
end

return context;