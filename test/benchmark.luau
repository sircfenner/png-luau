local fs = require("@lune/fs") :: any

local PNG = require("../src")

local files = {}

for _, subDirName in fs.readDir("./test/images") do
	local imageDirPath = `./test/images/{subDirName}`
	for _, imageFileName in fs.readDir(imageDirPath) do
		local imagePath = `{imageDirPath}/{imageFileName}`
		table.insert(files, {
			name = imageFileName,
			buffer = buffer.fromstring(fs.readFile(imagePath)),
		})
	end
end

local t0 = os.clock()
for _, file in files do
	pcall(PNG.decode, file.buffer)
end
local t1 = os.clock()

print(string.format("benchmark ran in %0.1f ms", 1000 * (t1 - t0)))
