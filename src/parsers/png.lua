--!native

local EXPECTED_SIG = "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A";

local http_service = game:GetService("HttpService"); --TODO: Replace with runtime indepdendent functions.

local zlib = require(script.Parent.Parent.packages.zlib);
local BufferReader = require(script.Parent.Parent.util.BufferReader);
local RGBA = require(script.Parent.Parent.util.RGBA);
local Bitmap = require(script.Parent.Parent.util.Bitmap);
local Animation = require(script.Parent.Parent.util.Animation);
local Frame = require(script.Parent.Parent.util.Frame);

local function chunk_name_bit(name: string, position: number)
    return name:sub(position, position):byte() > 96;
end

local chunks = {
    -- Image Header (https://www.w3.org/TR/png-3/#11IHDR) --
    IHDR = {
        read = function(self, chunk): (boolean, string?)
            local reader = BufferReader.new(chunk.data);
        
            self.width = reader:read_uint(4);
            self.height = reader:read_uint(4);
            self.bit_depth = reader:read_uint(1);
            self.colour_type = reader:read_uint(1);
            self.compression_method = reader:read_uint(1);
            self.filter_method = reader:read_uint(1);
            self.interlace_method = reader:read_uint(1);

            if self.colour_type == 0 or self.colour_type == 3 then
                self.pixel_size = 1 * (self.bit_depth/8);

            elseif self.colour_type == 4 then
                self.pixel_size = 2 * (self.bit_depth/8);

            elseif self.colour_type == 2 then
                self.pixel_size = 3 * (self.bit_depth/8);

            elseif self.colour_type == 6 then
                self.pixel_size = 4 * (self.bit_depth/8);
                
            else
                self.pixel_size = 0;
            end

            return true;
        end,
        
        write = function()
            
        end
    },

    -- Palette (https://www.w3.org/TR/png-3/#11PLTE) --
    PLTE = {
        read = function(self, chunk): (boolean, string?)
            if chunk.length % 3 ~= 0 then
                return false, "PLTE chunk should have a length divisible by 3.";
            end
            
            local reader = BufferReader.new(chunk.data);

            self.palette = {};

            for i = 1, chunk.length, 3 do
                table.insert(self.palette, RGBA.new(
                    reader:read_byte(), 
                    reader:read_byte(),
                    reader:read_byte(),
                    1
                ));
            end

            return true;
        end
    },

    -- Image Data (https://www.w3.org/TR/png-3/#11IDAT) --
    IDAT = {
        read = function(self, chunk): (boolean, string?)
            local buf = buffer.tostring(chunk.data);
            self.static_compressed ..= buf;

            if self.animated and self.frame_i == 1 then
                self.frames[1].static_compressed ..= buf;
            end

            return true;
        end,

        write = function()end
    },

    -- Image Trailer (https://www.w3.org/TR/png-3/#11IEND) --
    IEND = {
        read = function(self, chunk): (boolean, string?)
            self.reading = false;
            return true;
        end
    },

    -- Transparency (https://www.w3.org/TR/png-3/#11tRNS) --
    tRNS = {
        read = function(self, chunk): (boolean, string?)
            local reader = BufferReader.new(chunk.data);

            if self.colour_type == 0 then
                self.transparency = reader:read_uint(2);

                return true;
            elseif self.colour_type == 2 then
                self.transparency = {
                    red = reader:read_uint(2),
                    green = reader:read_uint(2),
                    blue = reader:read_uint(2)
                };

                return true;
            elseif self.colour_type == 3 then
                self.transparency = {};

                for i = 1, chunk.length do
                    self.transparency[i] = reader:read_uint(1);
                end

                return true;
            end

            return false, "Invalid colour type.";
        end
    },

    -- Primary chromaticities and white point (https://www.w3.org/TR/png-3/#11cHRM) --
    cHRM = {
        read = function(self, chunk): (boolean, string?)
            if self.cicp then return true end
            local reader = BufferReader.new(chunk.data);

            self.chromaticity = {
                whitepoint_x = reader:read_uint(4) / 100000,
                whitepoint_y = reader:read_uint(4) / 100000,
                red_x = reader:read_uint(4) / 100000,
                red_y = reader:read_uint(4) / 100000,
                green_x = reader:read_uint(4) / 100000,
                green_y = reader:read_uint(4) / 100000,
                blue_x = reader:read_uint(4) / 100000,
                blue_y = reader:read_uint(4) / 100000,
            };

            return true;
        end
    },

    -- Image Gamma (https://www.w3.org/TR/png-3/#11gAMA) -- 
    gAMA = {
        read = function(self, chunk): (boolean, string?)
            if self.cicp then return true end
            local reader = BufferReader.new(chunk.data);

            self.gamma = reader:read_uint(4) / 100000;
            
            return true;
        end
    },

    -- ICC Profile (https://www.w3.org/TR/png-3/#11iCCP) --
    -- not implementing unless demand is high, needs to be ignored if cicp is present --

    -- Significant Bits (https://www.w3.org/TR/png-3/#11sBIT) --
    sBIT = {
        read = function(self, chunk): (boolean, string?)
            local reader = BufferReader.new(chunk.data);

            if self.colour_type == 0 then
                self.significant_bits = reader:read_byte();

                return true;
            elseif self.colour_type == 2 or self.colour_type == 3 then
                self.significant_bits = {
                    red = reader:read_byte(),
                    green = reader:read_byte(),
                    blue = reader:read_byte()
                };

                return true;
            elseif self.colour_type == 4 then
                self.significant_bits = {
                    grayscale = reader:read_byte(), 
                    alpha = reader:read_byte()
                };

                return true;
            elseif self.colour_type == 6 then
                self.significant_bits = {
                    red = reader:read_byte(),
                    green = reader:read_byte(),
                    blue = reader:read_byte(),
                    alpha = reader:read_byte()
                };

                return true;
            end

            return false, "Invalid colour type.";
        end
    },

    -- Standard RGB Colour Space (https://www.w3.org/TR/png-3/#11sRGB) --
    sRGB = {
        read = function(self, chunk): (boolean, string?)
            if self.cicp then return true end
            local reader = BufferReader.new(chunk.data);

            self.rendering_intent = reader:read_byte();

            return true;
        end
    },

    -- Coding-independent code points for video signal type identification (https://www.w3.org/TR/png-3/#11cICP) --
    cICP = {
        read = function(self, chunk): (boolean, string?)
            local reader = BufferReader.new(chunk.data);

            self.cicp = {
                colour_primaries = reader:read_byte(),
                transfer_function = reader:read_byte(),
                matrix_coefficients = reader:read_byte(),
                video_full_range_flag = reader:read_byte()
            };

            return true;
        end
    },

    -- Mastering Display Color Volume (https://www.w3.org/TR/png-3/#11mDCv ) --
    mDCv = {
        read = function(self, chunk): (boolean, string?)
            local reader = BufferReader.new(chunk.data);

            self.mdcv = {
                colour_primaries = reader:read_buffer(12),
                whitepoint_chromacity = reader:read_uint(4),
                max_luminance = reader:read_uint(4),
                min_luminancen = reader:read_uint(4),
            };

            return true;
        end
    },

    -- Content Light Level Information (https://www.w3.org/TR/png-3/#11cLLi) --
    -- not implementing unless demand is high --

    -- Textual data (https://www.w3.org/TR/png-3/#11tEXt) --
    tEXt = {
        read = function(self, chunk): (boolean, string?)
            local reader = BufferReader.new(chunk.data);

            local delim = http_service:GenerateGUID(false);
            local key, value = unpack(
                reader:read_string(chunk.length):gsub("\0", delim, 1):split(delim)
            );

            self.text = self.text or {};
            self.text[key] = value;

            return true;
        end
    },

    -- Compressed Textual data (https://www.w3.org/TR/png-3/#11zTXt) --
    zTXt = {
        read = function(self, chunk): (boolean, string?)
            local reader = BufferReader.new(chunk.data);

            local delim = http_service:GenerateGUID(false);
            local compression_method = reader:read_byte();

            local key, compressed = unpack(
                reader:read_string(chunk.length-1):gsub("\0", delim, 1):split(delim)
            );

            local value;

            if compression_method == 0 then
                value = zlib.Deflate.Decompress(compressed);
            else
                return false, "Unsupported compression method.";
            end

            self.text = self.text or {};
            self.text[key] = value;

            return true;
        end
    },

    -- International textual data (https://www.w3.org/TR/png-3/#11iTXt) --
    -- not implementing unless demand is high --

    -- Background Colour (https://www.w3.org/TR/png-3/#11bKGD) --
    bKGD = {
        read = function(self, chunk): (boolean, string?)
            local reader = BufferReader.new(chunk.data);

            if self.colour_type == 0 or self.colour_type == 4 then
                self.background_colour = reader:read_uint(2);

                return true;
            elseif self.colour_type == 2 or self.colour_type == 6 then
                self.background_colour = {
                    red = reader:read_byte(2),
                    green = reader:read_byte(2),
                    blue = reader:read_byte(2)
                };

                return true;
            elseif self.colour_type == 3 then
                self.background_colour = reader:read_byte()

                return true;
            end

            return false, "Invalid colour type.";
        end
    },

    -- Image Histogram (https://www.w3.org/TR/png-3/#11hIST) --
    hIST = {
        read = function(self, chunk): (boolean, string?)
            local reader = BufferReader.new(chunk.data);

            self.histogram = {};

            for i = 1, chunk.length, 2 do
                self.histogram[i] = reader:read_uint(2)
            end

            return true; 
        end
    },

    -- Physical pixel dimensions (https://www.w3.org/TR/png-3/#11pHYs) --
    pHYs = {
        read = function(self, chunk): (boolean, string?)
            local reader = BufferReader.new(chunk.data);

            self.physical_size = {
                pixels_per_unit_x = reader:read_uint(4),
                pixels_per_unit_y = reader:read_uint(4),
                unit_specifier = reader:read_uint(1)
            }; -- converted from m to studs later.

            return true; 
        end
    },

    -- Suggested palette (https://www.w3.org/TR/png-3/#11sPLT) --
    -- not implementing unless demand is high --

    -- Exif data (https://www.w3.org/TR/png-3/#11eXIf) --
    eXIf = {
        read = function(self, chunk): (boolean, string?)
            local reader = BufferReader.new(chunk.data);

            self.exif_raw = reader:read_buffer(chunk.length); -- if anyone wants to decode this, be my guest.

            return true; 
        end
    },

    -- Image last-modification time (https://www.w3.org/TR/png-3/#11tIME) --
    tIME = {
        read = function(self, chunk): (boolean, string?)
            local reader = BufferReader.new(chunk.data);

            self.timestamp = {
                year = reader:read_uint(2),
                month = reader:read_uint(1),
                day = reader:read_uint(1),
                hour = reader:read_uint(1),
                minute = reader:read_uint(1),
                second = reader:read_uint(1),
            };

            return true; 
        end
    },

    -- Animation Control Chunk (https://www.w3.org/TR/png-3/#acTL-chunk) --
    acTL = {
        read = function(self, chunk): (boolean, string?)
            local reader = BufferReader.new(chunk.data);

            self.animation_control = {
                num_frames = reader:read_uint(4),
                num_plays = reader:read_uint(4),
            };
            self.animated = true;
            self.frames = {};
            self.frame_i = 0;

            return true; 
        end
    },

    -- Frame Control Chunk (https://www.w3.org/TR/png-3/#fcTL-chunk) --
    fcTL = {
        read = function(self, chunk): (boolean, string?)
            local reader = BufferReader.new(chunk.data);

            self.frame_i += 1;

            self.frames[self.frame_i] = {
                control_sequence_number = reader:read_uint(4),
                width = reader:read_uint(4),
                height = reader:read_uint(4),
                x_offset = reader:read_uint(4),
                y_offset = reader:read_uint(4),
                delay_num = reader:read_uint(2),
                delay_den = reader:read_uint(2),
                dispose_op = reader:read_uint(1),
                blend_op = reader:read_uint(1),
                static_compressed = ""
            };

            if self.frames[self.frame_i].delay_den == 0 then
                self.frames[self.frame_i].delay_den = 100;
            end

            return true; 
        end
    },

    -- Frame Data Chunk (https://www.w3.org/TR/png-3/#fDAT-chunk) --
    fdAT = {
        read = function(self, chunk): (boolean, string?)
            local reader = BufferReader.new(chunk.data);

            local frame = self.frames[self.frame_i];
            local _sequence_number = reader:read_uint(4);

            local buf = buffer.tostring(reader:read_buffer(chunk.length-4));
            frame.static_compressed ..= buf;

            return true; 
        end
    },
};

-- im scared of maths so i have outsourced this part completely to MaximumADHD's png decoder.
local Unfilter = (function()
	local Unfilter = {}

	function Unfilter:None(scanline, pixels, bpp, row)
		for i = 1, #scanline do
			pixels[row][i] = scanline[i]
		end
	end

	function Unfilter:Sub(scanline, pixels, bpp, row)
		for i = 1, bpp do
			pixels[row][i] = scanline[i] or 0
		end

		for i = bpp + 1, #scanline do
			local x = scanline[i] or 0
			local a = pixels[row][i - bpp] or 0
			pixels[row][i] = bit32.band(x + a, 0xFF)
		end
	end

	function Unfilter:Up(scanline, pixels, bpp, row)
		if row > 1 then
			local upperRow = pixels[row - 1]

			for i = 1, #scanline do
				local x = scanline[i] or 0
				local b = upperRow[i] or 0
				pixels[row][i] = bit32.band(x + b, 0xFF)
			end
		else
			self:None(scanline, pixels, bpp, row)
		end
	end

	function Unfilter:Average(scanline, pixels, bpp, row)
		if row > 1 then
			for i = 1, bpp do
				local x = scanline[i] or 0
				local b = pixels[row - 1][i] or 0

				b = bit32.rshift(b, 1)
				pixels[row][i] = bit32.band(x + b, 0xFF)
			end

			for i = bpp + 1, #scanline do
				local x = scanline[i] or 0
				local b = pixels[row - 1][i] or 0

				local a = pixels[row][i - bpp] or 0
				local ab = bit32.rshift(a + b, 1)

				pixels[row][i] = bit32.band(x + ab, 0xFF)
			end
		else
			for i = 1, bpp do
				pixels[row][i] = scanline[i] or 0
			end

			for i = bpp + 1, #scanline do
				local x = scanline[i] or 0
				local b = pixels[row - 1][i] or 0

				b = bit32.rshift(b, 1)
				pixels[row][i] = bit32.band(x + b, 0xFF)
			end
		end
	end

	function Unfilter:Paeth(scanline, pixels, bpp, row)
		if row > 1 then
			local pr

			for i = 1, bpp do
				local x = scanline[i] or 0
				local b = pixels[row - 1][i] or 0
				pixels[row][i] = bit32.band(x + b, 0xFF)
			end

			for i = bpp + 1, #scanline do
				local a = pixels[row][i - bpp] or 0
				local b = pixels[row - 1][i] or 0
				local c = pixels[row - 1][i - bpp] or 0

				local x = scanline[i] or 0
				local p = a + b - c

				local pa = math.abs(p - a)
				local pb = math.abs(p - b)
				local pc = math.abs(p - c)

				if pa <= pb and pa <= pc then
					pr = a
				elseif pb <= pc then
					pr = b
				else
					pr = c
				end

				pixels[row][i] = bit32.band(x + pr, 0xFF)
			end
		else
			self:Sub(scanline, pixels, bpp, row)
		end
	end

	return Unfilter	
end)();

local function raw_to_RGBA(raw: buffer, png): RGBA.RGBA?
    local reader = BufferReader.new(raw);

    if png.colour_type == 0 then
        return RGBA.from_color3(
            Color3.fromHSV(
                0,
                0,
                reader:read_uint(png.bit_depth/8)
            ),
            1
        );        
    elseif png.colour_type == 2 then
        return RGBA.from_color3(
            Color3.fromRGB(
                reader:read_uint(png.bit_depth/8),
                reader:read_uint(png.bit_depth/8),
                reader:read_uint(png.bit_depth/8)
            ),
            1
        );
    elseif png.colour_type == 3 then -- Palette Indexed
        local colour = png.palette[reader:read_uint(1)+1];

        return RGBA.from_color3(
            Color3.fromRGB(
                colour.r,
                colour.g,
                colour.b
            ),
            colour.a
        );
    elseif png.colour_type == 4 then
        return RGBA.from_color3(
            Color3.fromHSV(
                0,
                0,
                reader:read_uint(png.bit_depth/8)
            ),
            reader:read_uint(1)/255
        );
    elseif png.colour_type == 6 then
        return RGBA.from_color3(
            Color3.fromRGB(
                reader:read_uint(png.bit_depth/8),
                reader:read_uint(png.bit_depth/8),
                reader:read_uint(png.bit_depth/8)
            ),
            reader:read_uint(1)/255
        );
    end

    return nil;
end

local function compressed_to_bitmap(idx, png, bitmap: Bitmap.Bitmap): (Bitmap.Bitmap, number?, number?)
    --print(to_base64(idx.static_compressed))
    local raw = buffer.fromstring(zlib.Zlib.Decompress(idx.static_compressed) or zlib.Deflate.Decompress(idx.static_compressed));
    local reader = BufferReader.new(raw);

    local bytes = {};
    
    -- Filter that thang
    for line_i = 1, idx.height do
        local filter = reader:read_byte();

        bytes[line_i] = {};

        local scanline = reader:read_bytes(idx.width * png.pixel_size, true);
        
        if filter == 0 then
			Unfilter:None(scanline, bytes, png.pixel_size, line_i);
		elseif filter == 1 then
			Unfilter:Sub(scanline, bytes, png.pixel_size, line_i);
		elseif filter == 2 then
			Unfilter:Up(scanline, bytes, png.pixel_size, line_i);
		elseif filter == 3 then
			Unfilter:Average(scanline, bytes, png.pixel_size, line_i);
		elseif filter == 4 then
			Unfilter:Paeth(scanline, bytes, png.pixel_size, line_i);
		end
    end

    task.wait();
    print("!!!!!!!!!!! new frame !!!!!!!!!!!!")
    if idx.dispose_op == 1 then 
        print("Clear");
        bitmap:clear();
    elseif idx.dispose_op == 2 then
        print("??")
    elseif idx.dispose_op == 0 then
        print("None");
    end

    if idx.blend_op == 1 then 
        print("Over");
    elseif idx.blend_op == 0 then
        print("Source")
    end

    local y = 0;
    for byte_x = 1, #bytes do
        y += 1;
        local x = 0;
        for byte_y = 1, #bytes[byte_x], png.pixel_size do
            x += 1;

            local rawpx = buffer.create(png.pixel_size);

            for i = 0, png.pixel_size-1 do
                buffer.writeu8(rawpx, i, bytes[byte_x][i+byte_y] or 0);
            end
            
            local new = raw_to_RGBA(rawpx, png);
            local colour;

            if idx.blend_op == 1 then
                
                colour = bitmap.data[x+(idx.x_offset or 0)][y+(idx.y_offset or 0)]:clone();
                local r = new.a * new.r + (1-new.a) * colour.r;
                local g = new.a * new.r + (1-new.a) * colour.r;
                local b = new.a * new.r + (1-new.a) * colour.r;
                colour.r = r;
                colour.g = g;
                colour.b = b;
            else
                colour = new;
            end
            
            wait()
            print(x+(idx.x_offset or 0), y+(idx.y_offset or 0))
            colour:print()
            bitmap.data[x+(idx.x_offset or 0)][y+(idx.y_offset or 0)] = colour;
        end
    end

    return bitmap;
end

return {
    decode = function(raw: buffer, trace: boolean?): (boolean, {image: Bitmap.Bitmap?, animation: Animation.Animation?, metadata: {}?}|string)
        local log;
        if trace then
            log = print;
        else
            log = function(...) end;
        end
        
        log("Parsing PNG.");

        local reader = BufferReader.new(raw);

        local sig = reader:read_string(8);
        if sig ~= EXPECTED_SIG then
            return false, "File does not have a PNG signature.";
        end

        local png = {};
        png.type = "static"; --< Static / Animated
        png.chunks = {};
        png.reading = true;
        png.static_compressed = "";
        png.animated = false;
        png.width = 0;
        png.height = 0;
        png.frames = nil;

        --// Decode Chunks //--
        while png.reading do
            local chunk_data = {};

            chunk_data.length = reader:read_uint(4);
            chunk_data.type = reader:read_string(4);

            log(`Parsing a {chunk_data.type} chunk with length {chunk_data.length}.`);

            chunk_data.ancillary = chunk_name_bit(chunk_data.type, 1);
            chunk_data.private = chunk_name_bit(chunk_data.type, 2);
            chunk_data.reserved = chunk_name_bit(chunk_data.type, 3);
            chunk_data.safe_to_copy = chunk_name_bit(chunk_data.type, 4);

            if chunk_data.length > 0 then
                chunk_data.data = reader:read_buffer(chunk_data.length);
            end

            chunk_data.crc = reader:read_uint(4);

            local chunk_handler = chunks[chunk_data.type];

            if chunk_handler then
                local success, err = chunk_handler.read(png, chunk_data);
                if success then
                    table.insert(png.chunks, chunk_data);
                else
                    return false, err;
                end
            end

            log("Chunk parsed.");
        end


        --// Parse Static Image //--
        --local static_decompressed = zlib.Deflate(png.static_compressed);

        local bitmap = compressed_to_bitmap(png, png, Bitmap.new(png.width, png.height));

        local animation;

        if png.animated then 
            animation = Animation.new(png.width, png.height);
            
            for i, v in ipairs(png.frames) do
                local bp = compressed_to_bitmap(v, png, bitmap);
        
                task.wait(); -- stop exhasution on large pngs

                local delay = v.delay_num / v.delay_den;
                animation:add_frame(Frame.new(bp:clone(), delay));
            end
        end

        print(png)

        return true, {
            image = bitmap,
            animation = animation
        };
    end,

    encode = function(pixel_array: {number}): string
        return ""
    end
}