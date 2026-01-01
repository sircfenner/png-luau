# png-luau

PNG encoder/decoder for Luau. For decoding, supports all valid PNG files, bit depths, color types, interlacing, and transparency chunks.

## Installation

This library is built for all Luau runtimes and Roblox projects.

### Wally

Add `png-luau` to your `wally.toml`:

```toml
png-luau = "sircfenner/png-luau@0.2.0"
```

### Releases

Pre-built versions are available in [GitHub releases](https://github.com/sircfenner/png-luau/releases):

-   `png.luau` is a bundled single-file version of the library
-   `png.rbxm` is a Roblox model file

## Decoding

To decode a PNG image, call the `decode` function with a buffer containing the file contents:

```Luau
local PNG = require("@vendor/png-luau")

local png = PNG.decode(file)
```

This returns a table with the following type:

```Luau
{
	width: number,
	height: number,
	pixels: buffer,
	readPixel: (x: number, y: number) -> Color
}
```

The `pixels` buffer contains the decoded pixels in 32-bit RGBA format, top-to-bottom and left-to-right.

The `readPixel` function takes a pixel coordinate starting from (1, 1) in the top-left corner and returns the color information for that pixel.

The type of a `Color` is:

```Luau
{
	r: number,
	g: number,
	b: number,
	a: number,
}
```

Each component of a `Color` is an integer between 0 and 255. The `a` component represents alpha, where 0 is fully transparent and 255 is fully opaque.

The `decode` function takes an optional second parameter, which is a table specifying decoding options. Currently, the only valid option is `allowIncorrectCRC`, a boolean which defaults to false. It exists only for testing purposes and may be removed in future versions.

Known limitations:

-   Attempting to decode an invalid PNG file will throw an error
-   All ancillary chunks other than tRNS are currently skipped (other than CRC32 checks) when decoding
-   Images are transformed into 32-bit RGBA pixel data after decoding, regardless of original bit depth and color type
-   Files greater than 1GB in size or yielding greater than 1GB of image data after decompression (equivalent to ~16k x 16k resolution) cannot be decoded as they do not fit in a single Luau buffer

## Encoding

To encode a PNG image, call the `encode` function with a buffer containing the pixel data in 32-bit RGBA format as well as a table containing `width` and `height`:

```Luau
local PNG = require("@vendor/png-luau")

local file = PNG.encode(pixelBuffer, {
	width = 256,
	height = 128,
})
```

This returns a buffer containing the encoded PNG file.

Known limitations:

-   Pixel data for encoding must be in 32-bit RGBA format as described above
-   Images will be encoded in this same format - there is no support for writing other bit depths or color types yet
-   Encoded images will never be interlaced or use transparency chunks
-   As with encoding, the Luau buffer size cap of 1GB limits the maximum size of image data and encoded files

## License

This project is available under the MIT license. See [LICENSE](LICENSE) for details.

Some tests are derived from:

-   [pngsuite](http://www.schaik.com/pngsuite/pngsuite.html)
-   [imagetestsuite](https://code.google.com/archive/p/imagetestsuite/wikis/PNGTestSuite.wiki)
-   [javapng](https://github.com/kerner1000/javapng/tree/master)
