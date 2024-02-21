--!native

local function hex(data)
    local out = "";
    for i = 1, #data do
        local char = string.sub(data, i, i)
        out ..= (string.format("%02x", string.byte(char)) .. " ")
    end
    return out;
end


local BufferReader = {};
BufferReader.__index = BufferReader;

function BufferReader.new(buf: buffer)
    local self = setmetatable({
        buf = buf,
        cursor = 0
    }, BufferReader);

    return self;
end

function BufferReader:read_byte(): number
    local r = buffer.readu8(self.buf, self.cursor);
    self.cursor += 1;
    return r;
end

function BufferReader:read_bytes(bytes: number, as_array: boolean): {number}
    local values = {}

    for i = 1, bytes do
        values[i] = self:read_byte()
    end

    if as_array then
        return values;
    end

    return unpack(values)
end

function BufferReader:read_uint(bytes: number): number
    local r = buffer["readu"..tostring(bytes*8)](self.buf, self.cursor);

    self.cursor += bytes;
    if bytes == 1 then
        return r;
    end
    return bit32.byteswap(r);
end

function BufferReader:read_iint(bytes: number): number
    local r = buffer["readi"..tostring(bytes*8)](self.buf, self.cursor);
    self.cursor += bytes;
    if bytes == 1 then
        return r;
    end
    return bit32.byteswap(r);
end

function BufferReader:read_string(bytes: number): string
    local r = buffer.readstring(self.buf, self.cursor, bytes);
    self.cursor += bytes;
    return r;
end

function BufferReader:read_buffer(bytes: number): buffer
    local r = buffer.create(bytes);
    buffer.copy(r, 0, self.buf, self.cursor, bytes);
    self.cursor += bytes;
    return r;
end

return BufferReader;