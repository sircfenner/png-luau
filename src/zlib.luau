--!native
--!optimize 2

local MAX_BITS = 15

-- stylua: ignore
local LIT_LEN = {
	3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131,
	163, 195, 227, 258
}

-- stylua: ignore
local LIT_EXTRA = {
	1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0,
}

-- stylua: ignore
local DIST_OFF = {
	1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049,
	3073, 4097, 6145, 8193, 12289, 16385, 24577
}

-- stylua: ignore
local DIST_EXTRA = {
	0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13
}

-- stylua: ignore
local LEN_ORDER = {
	16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
}

-- stylua: ignore
local FIXED_LIT = {
	8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
	8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
	8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
	8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
	8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
	9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
	9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
	9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
	7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 8, 8, 8, 8, 8, 8, 8, 8
}

local WINDOW_LOOKAHEAD = 258
local WINDOW_SEARCH = 0x8000 - WINDOW_LOOKAHEAD

local MAX_CHAIN_NODES = 50_000
local MAX_CHAIN_SEARCH = 12
local MAX_MATCH_LENGTH = 96
local DEFLATE_BLOCK_SIZE = 0x8000

type HuffmanTable = { number }

local function createHuffmanTable(lengths: { number }): (HuffmanTable, { number }, { number })
	local lengthCount = table.create(MAX_BITS, 0)
	lengthCount[0] = 0
	for _, length in lengths do
		if length > 0 then
			lengthCount[length] = (lengthCount[length] or 0) + 1
		end
	end

	local lastCode = 1
	local nextCode = table.create(MAX_BITS)
	for bits = 1, MAX_BITS do
		lastCode = bit32.lshift(lastCode + lengthCount[bits - 1], 1)
		nextCode[bits] = lastCode
	end

	local mapping = {}
	local codeValues = {}
	local codeLengths = {}
	for i, length in lengths do
		if length > 0 then
			mapping[nextCode[length]] = i - 1
			codeValues[i - 1] = bit32.extract(nextCode[length], 0, length)
			codeLengths[i - 1] = length
			nextCode[length] += 1
		end
	end

	return mapping, codeValues, codeLengths
end

local cachedLitValues = {}
local cachedLitExtraValues = {}
local cachedLitExtraBits = {}
for length = 3, 258 do
	local idx
	for i = #LIT_LEN, 1, -1 do
		if length >= LIT_LEN[i] then
			idx = i
			break
		end
	end
	cachedLitValues[length] = 0x100 + idx
	cachedLitExtraValues[length] = length - LIT_LEN[idx]
	cachedLitExtraBits[length] = LIT_EXTRA[idx - 8] or 0
end

local cachedDistIndices = {}
for distance = 1, 1024 do
	local distIdx
	for i = #DIST_OFF, 1, -1 do
		if distance >= DIST_OFF[i] then
			distIdx = i
			break
		end
	end
	cachedDistIndices[distance] = distIdx
end

local fixedLitTable, fixedLitCodeValues, fixedLitCodeLengths = createHuffmanTable(FIXED_LIT)
local fixedDistTable, fixedDistCodeValues, fixedDistCodeLengths = createHuffmanTable(table.create(32, 5))

local function getStoreSize(blockSize: number)
	return math.ceil(blockSize / DEFLATE_BLOCK_SIZE) * 5 + blockSize
end

local function getDistIdx(distance: number)
	return if distance < 1025
		then cachedDistIndices[distance]
		elseif distance < 1537 then 21
		elseif distance < 2049 then 22
		elseif distance < 3073 then 23
		elseif distance < 4097 then 24
		elseif distance < 6145 then 25
		elseif distance < 8193 then 26
		elseif distance < 12289 then 27
		elseif distance < 16385 then 28
		elseif distance < 24577 then 29
		else 30
end

-- zlib adler32 applies modulo every 5552 cycles to keep s0 and s1 inside the 32-bit limit
-- however, using doubles allows us to wait >8.4m cycles in the worst case
local function adler32(input: buffer, offset: number, length: number): number
	local s0 = 1
	local s1 = 0
	local count = 0
	for i = offset, offset + length - 1 do
		s0 += buffer.readu8(input, i)
		s1 += s0
		count += 1
		if count == 8_400_000 then
			s0 %= 65521
			s1 %= 65521
			count = 0
		end
	end
	return bit32.bor(bit32.lshift(s1 % 65521, 16), s0 % 65521)
end

local function inflate(input: buffer, output: buffer): number
	local header0 = buffer.readu8(input, 0)
	local header1 = buffer.readu8(input, 1)
	assert(bit32.extract(header0, 0, 4) == 8, "invalid zlib comp method")
	assert(bit32.extract(header0, 4, 4) <= 7, "invalid zlib window size")
	assert(bit32.extract(header1, 5, 1) == 0, "preset dictionary is not allowed")
	assert(bit32.bor(bit32.lshift(header0, 8), header1) % 31 == 0, "zlib header sum mismatch")

	local readOffset = 2
	local readOffsetBit = 0

	local function readBit()
		local bit = bit32.extract(buffer.readu8(input, readOffset), readOffsetBit)
		readOffsetBit += 1
		if readOffsetBit == 8 then
			readOffsetBit = 0
			readOffset += 1
		end
		return bit
	end

	local function readBits(n: number)
		local bits = buffer.readbits(input, readOffset * 8 + readOffsetBit, n)
		readOffsetBit += n
		readOffset += bit32.rshift(readOffsetBit, 3)
		readOffsetBit = bit32.band(readOffsetBit, 0b111)
		return bits
	end

	local function readHuffmanTable(huffmanTable: HuffmanTable): number
		local code = 2 + readBit()
		while not huffmanTable[code] do
			code = 2 * code + readBit()
		end
		return huffmanTable[code]
	end

	local writeOffset = 0

	repeat
		local bfinal = readBit()
		local btype = readBits(2)
		assert(btype ~= 0b11, "reserved btype")

		if btype == 0b00 then
			if readOffsetBit > 0 then
				readOffset += 1
				readOffsetBit = 0
			end
			local len = buffer.readu16(input, readOffset)
			assert(bit32.bxor(len, buffer.readu16(input, readOffset + 2)) == 0xFFFF, "len ~= nlen")
			readOffset += 4
			buffer.copy(output, writeOffset, input, readOffset, len)
			writeOffset += len
			readOffset += len
		else
			local litTable = fixedLitTable
			local distTable = fixedDistTable

			if btype == 0b10 then
				local litsCount = readBits(5) + 257
				local distsCount = readBits(5) + 1
				local codesCount = readBits(4) + 4

				local codeLengths = table.create(19, 0)
				for i = 1, codesCount do
					codeLengths[LEN_ORDER[i] + 1] = readBits(3)
				end
				local codeLengthsTable = createHuffmanTable(codeLengths)

				local litLengths = table.create(litsCount)
				local litLength
				repeat
					local code = readHuffmanTable(codeLengthsTable)
					local repeatCount = 1
					if code <= 15 then
						litLength = code
					elseif code == 16 then
						repeatCount = readBits(2) + 3
					elseif code == 17 then
						litLength = 0
						repeatCount = readBits(3) + 3
					elseif code == 18 then
						litLength = 0
						repeatCount = readBits(7) + 11
					end
					for _ = 1, repeatCount do
						table.insert(litLengths, litLength)
					end
				until #litLengths >= litsCount
				litTable = createHuffmanTable(litLengths)

				local distLengths = table.create(distsCount)
				local distLength
				repeat
					local code = readHuffmanTable(codeLengthsTable)
					local repeatCount = 1
					if code <= 15 then
						distLength = code
					elseif code == 16 then
						repeatCount = readBits(2) + 3
					elseif code == 17 then
						distLength = 0
						repeatCount = readBits(3) + 3
					elseif code == 18 then
						distLength = 0
						repeatCount = readBits(7) + 11
					end
					for _ = 1, repeatCount do
						table.insert(distLengths, distLength)
					end
				until #distLengths >= distsCount
				distTable = createHuffmanTable(distLengths)
			end

			repeat
				local v = readHuffmanTable(litTable)
				if v < 0x100 then
					buffer.writeu8(output, writeOffset, v)
					writeOffset += 1
				elseif v > 0x100 then
					local len = LIT_LEN[v - 0x100]
					if v > 0x10C then
						len += readBits(LIT_EXTRA[v - 0x108])
					elseif v > 0x108 then
						len += readBit()
					end

					local d = readHuffmanTable(distTable)
					local dist = DIST_OFF[d + 1]
					if d > 5 then
						dist += readBits(DIST_EXTRA[d])
					elseif d > 3 then
						dist += readBit()
					end

					if len <= dist then
						buffer.copy(output, writeOffset, output, writeOffset - dist, len)
						writeOffset += len
					else
						repeat
							local size = math.min(len, dist)
							buffer.copy(output, writeOffset, output, writeOffset - dist, size)
							writeOffset += size
							len -= size
							dist += size
						until len == 0
					end
				end
			until v == 0x100
		end
	until bfinal == 0b1

	if readOffsetBit > 0 then
		readOffsetBit = 0
		readOffset += 1
	end

	assert(
		adler32(output, 0, buffer.len(output)) == bit32.byteswap(buffer.readu32(input, readOffset)),
		"adler-32 checksum mismatch"
	)

	return writeOffset
end

local function deflate(input: buffer): (buffer, number)
	-- upper bound: all data as uncompressed blocks + 6 zlib bytes
	local inputSize = buffer.len(input)
	local output = buffer.create(getStoreSize(inputSize) + 6)

	-- flevel (1 = fast), dict (0 = false), checks, window (7 = 32k), method (8 = deflate)
	buffer.writeu16(output, 0, 0b01_0_11110_0111_1000)

	local writeOffset = 2
	local writeOffsetBits = 0

	local function writeBits(n: number, width: number)
		buffer.writebits(output, writeOffset * 8 + writeOffsetBits, width, n)
		writeOffsetBits += width
		writeOffset += bit32.rshift(writeOffsetBits, 3)
		writeOffsetBits = bit32.band(writeOffsetBits, 0b111)
	end

	-- https://graphics.stanford.edu/~seander/bithacks.html
	local function writeHuffmanBits(n: number, w: number)
		n = bit32.bor(bit32.band(bit32.rshift(n, 1), 0x55555555), bit32.band(bit32.lshift(n, 1), 0xAAAAAAAA))
		n = bit32.bor(bit32.band(bit32.rshift(n, 2), 0x33333333), bit32.band(bit32.lshift(n, 2), 0xCCCCCCCC))
		n = bit32.bor(bit32.band(bit32.rshift(n, 4), 0x0F0F0F0F), bit32.band(bit32.lshift(n, 4), 0xF0F0F0F0))
		n = bit32.bor(bit32.band(bit32.rshift(n, 8), 0x00FF00FF), bit32.band(bit32.lshift(n, 8), 0xFF00FF00))
		n = bit32.bor(bit32.rshift(n, 16), bit32.lshift(n, 16))
		n = bit32.band(bit32.rshift(n, 32 - w), bit32.lshift(1, w) - 1)
		writeBits(n, w)
	end

	local function writeLitOrLen(value: number)
		writeHuffmanBits(fixedLitCodeValues[value], fixedLitCodeLengths[value])
	end

	local function writeBackRef(distance: number, length: number)
		writeLitOrLen(cachedLitValues[length])
		if length > 10 then
			writeBits(cachedLitExtraValues[length], cachedLitExtraBits[length])
		end
		local distIdx = getDistIdx(distance)
		writeHuffmanBits(fixedDistCodeValues[distIdx - 1], fixedDistCodeLengths[distIdx - 1])
		if distIdx > 3 then
			writeBits(distance - DIST_OFF[distIdx], DIST_EXTRA[distIdx - 1])
		end
	end

	local function getLitOrLenSize(value: number)
		return fixedLitCodeLengths[value]
	end

	local function getBackRefSize(distance: number, length: number)
		local distIdx = getDistIdx(distance)
		return getLitOrLenSize(cachedLitValues[length])
			+ cachedLitExtraBits[length]
			+ fixedDistCodeLengths[distIdx - 1]
			+ (DIST_EXTRA[distIdx - 1] or 0)
	end

	local offsets = {}
	local nexts = {}
	local heads = {}
	local nodeCount = 0

	local function insertNode(offset: number, nextIndex: number)
		nodeCount += 1
		offsets[nodeCount] = offset
		nexts[nodeCount] = nextIndex
		return nodeCount
	end

	local function clearTables()
		table.clear(offsets)
		table.clear(nexts)
		table.clear(heads)
		nodeCount = 0
	end

	for startReadOffset = 0, inputSize - 1, DEFLATE_BLOCK_SIZE do
		local huffmanSizeBits = 0

		local nextBlockReadOffset = math.min(inputSize, startReadOffset + DEFLATE_BLOCK_SIZE)
		local readOffset = startReadOffset

		local tokens: { vector } = {}
		while readOffset < nextBlockReadOffset - 3 do
			local hash = bit32.band(buffer.readu32(input, readOffset), 0xFFFFFF)
			local newNodeIndex = insertNode(readOffset, heads[hash] or 0)
			heads[hash] = newNodeIndex

			local bestLength = 0
			local bestOffset = -1

			local chainCount = 0
			local nodeIndex = nexts[newNodeIndex]
			while
				nodeIndex
				and (offsets[nodeIndex] or -math.huge) >= readOffset - WINDOW_SEARCH
				and chainCount < MAX_CHAIN_SEARCH
				and bestLength < MAX_MATCH_LENGTH
			do
				local searchLength = 3
				local searchOffset = offsets[nodeIndex]

				local exit = false
				local limit = math.min(nextBlockReadOffset, readOffset + WINDOW_LOOKAHEAD)
				if
					readOffset + bestLength < limit
					and buffer.readu8(input, searchOffset + bestLength)
						~= buffer.readu8(input, readOffset + bestLength)
				then
					exit = true -- pre-check the next byte after longest (early exit)
				end

				while
					not exit
					and searchLength < WINDOW_LOOKAHEAD
					and readOffset + searchLength < nextBlockReadOffset
					and buffer.readu8(input, searchOffset + searchLength)
						== buffer.readu8(input, readOffset + searchLength)
				do
					searchLength += 1
				end
				if searchLength > bestLength then
					bestLength = searchLength
					bestOffset = searchOffset
					if bestLength >= WINDOW_LOOKAHEAD then
						break
					end
				end
				nodeIndex = nexts[nodeIndex]
				chainCount += 1
			end

			if bestLength == 0 then
				local b = buffer.readu8(input, readOffset)
				huffmanSizeBits += getLitOrLenSize(b)
				table.insert(tokens, vector.create(0, b))
				readOffset += 1
			else
				huffmanSizeBits += getBackRefSize(readOffset - bestOffset, bestLength)
				table.insert(tokens, vector.create(1, readOffset - bestOffset, bestLength))
				for newOffset = readOffset + 1, math.min(readOffset + bestLength - 1, nextBlockReadOffset - 4) do
					local newHash = bit32.band(buffer.readu32(input, newOffset), 0xFFFFFF)
					heads[newHash] = insertNode(newOffset, heads[newHash] or 0)
				end
				readOffset += bestLength
			end
		end

		while readOffset < nextBlockReadOffset do
			local b = buffer.readu8(input, readOffset)
			huffmanSizeBits += getLitOrLenSize(b)
			table.insert(tokens, vector.create(0, b))
			readOffset += 1
		end

		huffmanSizeBits += getLitOrLenSize(0x100)
		table.insert(tokens, vector.create(0, 0x100))

		if nextBlockReadOffset == inputSize then
			writeBits(0b1, 1)
		else
			writeBits(0b0, 1)
		end

		local blockLength = nextBlockReadOffset - startReadOffset
		local fixedHuffmanSize = math.ceil(huffmanSizeBits / 8) + 1 -- bfinal/btype overhead
		if fixedHuffmanSize < getStoreSize(blockLength) then
			writeBits(0b01, 2)
			for _, token in tokens do
				if token.x == 0 then
					writeLitOrLen(token.y)
				else
					writeBackRef(token.y, token.z)
				end
			end
		else
			writeBits(0b00, 2)
			if writeOffsetBits > 0 then
				writeOffset += 1
				writeOffsetBits = 0
			end
			buffer.writeu16(output, writeOffset, blockLength)
			buffer.writeu16(output, writeOffset + 2, bit32.bxor(0xFFFF, blockLength))
			buffer.copy(output, writeOffset + 4, input, startReadOffset, blockLength)
			writeOffset += 4 + blockLength
		end

		if nodeCount > MAX_CHAIN_NODES then
			clearTables()
		end
	end

	if writeOffsetBits > 0 then
		writeOffset += 1
	end

	local checksum = adler32(input, 0, buffer.len(input))
	buffer.writeu32(output, writeOffset, bit32.byteswap(checksum))

	return output, writeOffset + 4
end

return {
	inflate = inflate,
	deflate = deflate,
}
