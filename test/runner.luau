local fs = require("@lune/fs") :: any
local process = require("@lune/process") :: any
local serde = require("@lune/serde") :: any

local PNG = require("../src")
local base64 = require("./base64")

type Test = {
	folder: string,
	name: string,
	key: string,
	checkCRC: boolean,
	success: true,
	rgb8: string,
} | {
	folder: string,
	name: string,
	key: string,
	checkCRC: boolean,
	success: false,
	message: string,
}

local tests = serde.decode("json", fs.readFile("./temp/tests.json")) :: { Test }

local passed = {}
local failed = {}

local function extractError(message: string): string
	return string.match(message :: any, ":%d+: (.-)$") :: string
end

local function pass(test: Test)
	table.insert(passed, {
		name = test.name,
	})
end

local function fail(test: Test, message: string)
	table.insert(failed, {
		id = test.key,
		message = message,
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
			fail(test, `expected decode error "{test.message}", did not error`)
		else
			local expect = base64.decode(buffer.fromstring(test.rgb8))
			if buffer.tostring(expect) ~= buffer.tostring(response.pixels) then
				fail(test, "pixel data mismatch")
			else
				pass(test)
			end
		end
	else
		if test.success then
			fail(test, `unexpected decode error "{extractError(response :: any)}"`)
		else
			local message = extractError(response :: any)
			if message ~= test.message then
				fail(test, `expected decode error "{test.message}", got "{message}"`)
			else
				pass(test)
			end
		end
	end
end

print(`{#passed} passed, {#failed} failed`)

if #failed == 0 then
	process.exit(0)
else
	for _, case in failed do
		print(`[failed] {case.id}: {case.message}`)
	end
	process.exit(1)
end
