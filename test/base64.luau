--!native
--!optimize 2

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local encb = buffer.create(64)
local decb = buffer.create(256)
for i = 0, 63 do
	local b = string.byte(alphabet, i + 1)
	buffer.writeu8(encb, i, b)
	buffer.writeu8(decb, b, i)
end

local function encode(data: buffer): buffer
	local dataLen = buffer.len(data)
	local outLen = math.ceil(buffer.len(data) / 3) * 4

	local out = buffer.create(outLen)
	for i = 0, dataLen // 3 - 1 do
		local x = buffer.readu8(data, i * 3)
		local y = buffer.readu8(data, i * 3 + 1)
		local z = buffer.readu8(data, i * 3 + 2)
		buffer.writeu8(out, i * 4, buffer.readu8(encb, bit32.rshift(x, 2)))
		buffer.writeu8(
			out,
			i * 4 + 1,
			buffer.readu8(encb, bit32.bor(bit32.lshift(bit32.band(x, 0x3), 4), bit32.rshift(y, 4)))
		)
		buffer.writeu8(
			out,
			i * 4 + 2,
			buffer.readu8(encb, bit32.bor(bit32.lshift(bit32.band(y, 0xF), 2), bit32.rshift(z, 6)))
		)
		buffer.writeu8(out, i * 4 + 3, buffer.readu8(encb, bit32.band(z, 0x3F)))
	end

	local trailing = dataLen % 3
	if trailing == 1 then
		local x = buffer.readu8(data, dataLen - 1)
		buffer.writeu8(out, outLen - 4, buffer.readu8(encb, bit32.rshift(x, 2)))
		buffer.writeu8(out, outLen - 3, buffer.readu8(encb, bit32.lshift(bit32.band(x, 0x3), 4)))
		buffer.writeu8(out, outLen - 2, 61)
		buffer.writeu8(out, outLen - 1, 61)
	elseif trailing == 2 then
		local x = buffer.readu8(data, dataLen - 2)
		local y = buffer.readu8(data, dataLen - 1)
		buffer.writeu8(out, outLen - 4, buffer.readu8(encb, bit32.rshift(x, 2)))
		buffer.writeu8(
			out,
			outLen - 3,
			buffer.readu8(encb, bit32.bor(bit32.lshift(bit32.band(x, 0x3), 4), bit32.rshift(y, 4)))
		)
		buffer.writeu8(out, outLen - 2, buffer.readu8(encb, bit32.lshift(bit32.band(y, 0xF), 2)))
		buffer.writeu8(out, outLen - 1, 61)
	end

	return out
end

local function decode(data: buffer): buffer
	local dataLen = buffer.len(data)
	local outLen = 3 * dataLen / 4
	if buffer.readu8(data, dataLen - 2) == 61 then
		outLen -= 2
	elseif buffer.readu8(data, dataLen - 1) == 61 then
		outLen -= 1
	end

	local out = buffer.create(outLen)
	for i = 0, outLen // 3 - 1 do
		local a = buffer.readu8(decb, buffer.readu8(data, i * 4))
		local b = buffer.readu8(decb, buffer.readu8(data, i * 4 + 1))
		local c = buffer.readu8(decb, buffer.readu8(data, i * 4 + 2))
		local d = buffer.readu8(decb, buffer.readu8(data, i * 4 + 3))
		buffer.writeu8(out, i * 3, bit32.bor(bit32.lshift(a, 2), bit32.rshift(b, 4)))
		buffer.writeu8(out, i * 3 + 1, bit32.bor(bit32.lshift(bit32.band(b, 0xF), 4), bit32.rshift(c, 2)))
		buffer.writeu8(out, i * 3 + 2, bit32.bor(bit32.lshift(bit32.band(c, 0x3), 6), d))
	end

	local trailing = outLen % 3
	if trailing == 1 then
		local a = buffer.readu8(decb, buffer.readu8(data, dataLen - 4))
		local b = buffer.readu8(decb, buffer.readu8(data, dataLen - 3))
		buffer.writeu8(out, outLen - 1, bit32.bor(bit32.lshift(a, 2), bit32.rshift(b, 4)))
	elseif trailing == 2 then
		local a = buffer.readu8(decb, buffer.readu8(data, dataLen - 4))
		local b = buffer.readu8(decb, buffer.readu8(data, dataLen - 3))
		local c = buffer.readu8(decb, buffer.readu8(data, dataLen - 2))
		buffer.writeu8(out, outLen - 2, bit32.bor(bit32.lshift(a, 2), bit32.rshift(b, 4)))
		buffer.writeu8(out, outLen - 1, bit32.bor(bit32.lshift(bit32.band(b, 0xF), 4), bit32.rshift(c, 2)))
	end

	return out
end

return {
	encode = encode,
	decode = decode,
}
