
local util = require("../util/util");

local RGBA = {};
RGBA.__index = RGBA;

function RGBA.new(r: number, g: number, b: number, a: number)
    return setmetatable({
        r = r or 0,
        g = g or 0,
        b = b or 0,
        a = a or 1
    }, RGBA);
end

function RGBA:clone()
    return RGBA.new(self.r, self.g, self.b, self.a);
end

function RGBA.from_color3(colour: Color3, a: number)
    return RGBA.new(colour.R, colour.G, colour.B, a);
end

function RGBA:to_color3()
    return Color3.new(self.r, self.g, self.b)
end

function RGBA:as_array()
    return {self.r, self.g, self.b, self.a};
end

function RGBA:print()
    print("R:", math.round(self.r * 255), "G:", math.round(self.g * 255), "B:", math.round(self.b * 255), "A:", math.round(self.a * 255))
end

export type RGBA = typeof(RGBA.new(1, 1, 1, 1));

return RGBA;