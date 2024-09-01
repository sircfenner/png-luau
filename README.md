# png-luau

Luau implementation of the PNG file format. Currently only decoding is supported, but encoding may be supported in future.

All valid PNG files should be successfully decoded, with support for all critical chunks, bit depths, color types, interlacing, and transparency chunks.

Extra information:

-   Attempting to decode an invalid PNG file will throw an error
-   All ancillary chunks other than tRNS are currently skipped (other than CRC32 checks) when decoding
-   Images are transformed into 32-bit RGBA pixel data when decoding, regardless of original bit depth and color type
-   Files greater than 1GB in size or yielding greater than 1GB of image data after decompression (equivalent to ~16k x 16k resolution) cannot be decoded as they do not fit in a single Luau buffer

## Installation

This library is built for Roblox, [Lune](https://lune-org.github.io/docs), and standalone Luau.

### Wally

Add `png-luau` to your `wally.toml`:

```toml
png-luau = "sircfenner/png-luau@0.1.0"
```

### NPM & yarn

Add `@sircfenner/png-luau` to your dependencies:

```bash
npm install @sircfenner/png-luau
```

```bash
yarn add @sircfenner/png-luau
```

### Releases

Pre-built versions are available in [GitHub releases](https://github.com/sircfenner/png-luau/releases):

-   `png.rbxm` is a Roblox model file
-   `png.luau` is a single-file version of the library (suitable for standalone Luau)

## Usage

To decode a PNG image, call the `decode` function with a buffer containing the file contents:

```Luau
local PNG = require("@pkg/@sircfenner/png-luau")

local png = PNG.decode(image)
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

## License

This project is available under the MIT license. See [LICENSE](LICENSE) for details.

Some tests are derived from:

-   [pngsuite](http://www.schaik.com/pngsuite/pngsuite.html)
-   [imagetestsuite](https://code.google.com/archive/p/imagetestsuite/wikis/PNGTestSuite.wiki)
-   [javapng](https://github.com/kerner1000/javapng/tree/master)
