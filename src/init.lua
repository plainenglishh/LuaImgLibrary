local http_service = game:GetService("HttpService");

local parsers = require(script.parsers);

local URL_A = "http://localhost:8000/ezgif-1-486cd991ac-ezgif.com-resize.png";
--local URL_A = "https://s1.ezgif.com/tmp/ezgif-1-b77d10435c.png"
--local URL_B = "https://upload.wikimedia.org/wikipedia/commons/1/14/Animated_PNG_example_bouncing_beach_ball.png";

local rawa = buffer.fromstring(http_service:GetAsync(URL_A));
print(buffer.len(rawa))

local starta = os.clock();
local _, out = parsers.png.decode(rawa, true);

local image = out.image;

print(`Decoded {image.size.x}x{image.size.y}px PNG in:`, (os.clock()-starta) * 1000, "ms")

local editable_image = Instance.new("EditableImage", workspace:WaitForChild("SpawnLocation"):WaitForChild("Decal"));

out.image:apply_to(editable_image);

if out.animation then
    out.animation:get_handler(editable_image).play();
end
return {};