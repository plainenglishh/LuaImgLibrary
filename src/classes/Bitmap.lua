--!native

local RGBA = require("../classes/RGBA");
local util = require("../util/util");

local Bitmap = {};
Bitmap.__index = Bitmap;

function Bitmap.new(size_x: number, size_y: number)
    local self = setmetatable({
        data = {};
        size = {
            x = size_x,
            y = size_y
        }
    }, Bitmap);

    self:clear();

    return self;
end

function Bitmap:clone()
    local new = Bitmap.new(self.size.x, self.size.y);
    new.data = util.deep_copy(self.data);
    return new;
end

function Bitmap:clear()
    for x = 1, self.size.x do
        self.data[x] = {};
        for y = 1, self.size.y do
            self.data[x][y] = RGBA.new(0, 0, 0, 0);
        end
    end
end

function Bitmap:read_pixel(x: number, y: number): RGBA.RGBA?
    if x > self.size.x or y > self.size.y then
        error("Attempt to read out of bounds pixel.", 2);
    end
    
    local px = self.data[x+1][y+1];
    
    if px then
        return px :: RGBA.RGBA;
    end

    return;
end

function Bitmap:write_pixel(x: number, y: number, px: RGBA.RGBA)
    if x > self.size.x or y > self.size.y then
        error("Attempt to read out of bounds pixel.", 2);
    end
    
    self.data[x+1][y+1] = px;
end

function Bitmap:to_px_array(): {number}
    local out = {};
    
    local i = 1;
    for y = 1, self.size.y do
        for x = 1, self.size.x do
            local px = self.data[x][y];
            out[i] = px.r;
            out[i+1] = px.g;
            out[i+2] = px.b;
            out[i+3] = px.a;
            i+=4;
        end
    end

    return out;
end

function Bitmap:apply_to(editable_image: EditableImage)
    editable_image.Size = Vector2.new(self.size.x, self.size.y);

    local arr = self:to_px_array();
    
    editable_image:WritePixels(
        Vector2.zero,
        Vector2.new(self.size.x, self.size.y),
        arr
    );
end

export type Bitmap = typeof(Bitmap.new(1, 1));

return Bitmap;