local Frame = require(script.Parent.Frame);

local Animation = {};
Animation.__index = Animation;

function Animation.new(size_x: number, size_y: number)
    return setmetatable({
        frames = {};
        frame_count = 0,
        size = {
            x = size_x,
            y = size_y
        }
    }, Animation);
end

function Animation:add_frame(frame: Frame.Frame, position: number?)
    self.frame_count += 1;

    table.insert(self.frames, position or self.frame_count, frame);
end

function Animation:get_frame(frame_number: number): Frame.Frame?
    return self.frames[frame_number];
end

function Animation:get_handler(editable_image: EditableImage)
    editable_image.Size = Vector2.new(self.size.x, self.size.y);

    local frames = {};

    for i, v in pairs(self.frames) do
        frames[i] = {
            bp = v.bitmap,
            px_array = v.bitmap:to_px_array(),
            delay = v.delay;
        }
    end
    
    return {
        play = function()
            while task.wait() do
                for i, frame in ipairs(frames) do         
                    print(table.maxn(frame.px_array));           
                    editable_image:WritePixels(
                        Vector2.zero,
                        Vector2.new(frame.bp.size.x, frame.bp.size.y),
                        frame.px_array
                    );

                    print("delay for", frame.delay)
                    task.wait(frame.delay);
                end
            end
        end
    }
end

export type Animation = typeof(Animation.new(1, 1));

return Animation;