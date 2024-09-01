const sharp = require("sharp");

const stripes = [];
const size = 32;
const step = 4;
for (let i = 0; i < size; i += step) {
    stripes.push({
        input: {
            create: {
                width: step,
                height: size,
                channels: 3,
                background: { h: (360 * i) / size, s: 255, v: 255 },
            },
        },
        top: 0,
        left: i,
    });
}

const makeImage = async (interlaced, paletted, compression) => {
    const name = `c${compression}${interlaced ? "i" : ""}${
        paletted ? "p" : ""
    }`;

    const image = sharp({
        create: {
            width: size,
            height: size,
            channels: 3,
            background: { r: 255, g: 255, b: 255 },
        },
    }).composite([
        ...stripes,
        {
            input: {
                text: {
                    text: name,
                    font: "consolas",
                    dpi: 72,
                },
            },
        },
    ]);

    return image
        .png({
            progressive: interlaced,
            compressionLevel: compression,
            palette: paletted,
        })
        .toFile(`./test/images/bespoke/${name}.png`);
};

const promises = [];

for (let interlace = 0; interlace < 2; interlace++) {
    for (let palette = 0; palette < 2; palette++) {
        for (let compression = 0; compression < 10; compression++) {
            promises.push(
                makeImage(interlace === 1, palette === 1, compression)
            );
        }
    }
}

Promise.all(promises).then(() => {
    console.log("done!");
});
