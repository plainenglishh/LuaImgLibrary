local Bitmap = require("./Bitmap");

local Frame = {};
Frame.__index = Frame;

function Frame.new(bitmap: Bitmap.Bitmap, delay: number)
    return setmetatable({
        bitmap = bitmap,
        delay = delay
    }, Frame);
end

export type Frame = typeof(Frame.new(1, 1));

return Frame;