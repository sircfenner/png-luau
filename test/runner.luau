local fs = require("@lune/fs") :: any
local process = require("@lune/process") :: any
local serde = require("@lune/serde") :: any

local PNG = require("../src")
local base64 = require("./base64")

type TestCase =
	{
		folder: string,
		name: string,
		key: string,
		checkCRC: boolean,
		success: true,
		rgb8: string,
	}
	| {
		folder: string,
		name: string,
		key: string,
		checkCRC: boolean,
		success: false,
		message: string,
	}

local tests = serde.decode("json", fs.readFile("./temp/tests.json")) :: { TestCase }

local passed = {}
local failed = {}
local skipped = {}

local function extractError(message: string): string
	return string.match(message :: any, ":%d+: (.-)$") :: string
end

local function reportPass(id: string)
	table.insert(passed, {
		id = id,
	})
end

local function reportFail(id: string, message: string)
	table.insert(failed, {
		id = id,
		message = message,
	})
end

local function reportSkip(id: string, reason: string)
	table.insert(skipped, {
		id = id,
		reason = reason,
	})
end

for _, test in tests do
	local path = `./test/images/{test.folder}/{test.name}.png`
	local file = buffer.fromstring(fs.readFile(path))

	local success, response = pcall(PNG.decode, file, {
		allowIncorrectCRC = not test.checkCRC,
	})
	if success then
		if not test.success then
			reportFail(test.key, `expected decode error "{test.message}", did not error`)
		else
			local expect = base64.decode(buffer.fromstring(test.rgb8))
			if buffer.tostring(expect) ~= buffer.tostring(response.pixels) then
				reportFail(test.key, "pixel data mismatch")
			else
				reportPass(test.key)
			end
		end
	else
		if test.success then
			reportFail(test.key, `unexpected decode error "{extractError(response :: any)}"`)
		else
			local message = extractError(response :: any)
			if message ~= test.message then
				reportFail(test.key, `expected decode error "{test.message}", got "{message}"`)
			else
				reportPass(test.key)
			end
		end
	end

	-- roundtrip testing
	if success then
		local key = `encode:{test.key}`
		if not test.success then
			reportSkip(key, "decode failed")
		else
			local encodeSuccess, encodeResponse = pcall(PNG.encode, response.pixels, {
				width = response.width,
				height = response.height,
			})
			if not encodeSuccess then
				reportFail(key, `re-encode failed: {encodeResponse}`)
			else
				local decodeSuccess, decodeResponse = pcall(PNG.decode, encodeResponse)
				if not decodeSuccess then
					reportFail(key, `re-decode failed: {decodeResponse}`)
				elseif decodeResponse.width ~= response.width then
					reportFail(key, `roundtrip width mismatch: expected {response.width}, got {decodeResponse.width}`)
				elseif decodeResponse.height ~= response.height then
					reportFail(
						key,
						`roundtrip height mismatch: expected {response.height}, got {decodeResponse.height}`
					)
				elseif buffer.tostring(decodeResponse.pixels) ~= buffer.tostring(response.pixels) then
					reportFail(key, "roundtrip failed: pixel mismatch")
				else
					reportPass(key)
				end
			end
		end
	end
end

print(`{#passed} passed, {#skipped} skipped, {#failed} failed`)

if #failed == 0 and #skipped == 0 then
	process.exit(0)
else
	for _, case in skipped do
		print(`[skipped] {case.id}: {case.reason}`)
	end
	for _, case in failed do
		print(`[failed] {case.id}: {case.message}`)
	end
	process.exit(1)
end
