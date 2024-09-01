const fs = require("fs");
const path = require("path");
const sharp = require("sharp");

const errors = require("./errors.json");

const imagesPath = "./test/images";
const outputPath = "./temp/tests.json";

(async () => {
    const output = [];

    for (const subDirName of fs.readdirSync(imagesPath)) {
        const imageDirPath = path.join(imagesPath, subDirName);

        for (const imageFileName of fs.readdirSync(imageDirPath)) {
            const imagePath = path.join(imageDirPath, imageFileName);
            const imageName = path.parse(imagePath).name;
            const imageKey = `${subDirName}-${imageName}`;

            const entry = {
                folder: subDirName,
                name: imageName,
                key: imageKey,
            };

            if (imageKey in errors) {
                const err = errors[imageKey];
                if (typeof err === "string") {
                    entry.message = err;
                    entry.checkCRC = false; // by default, don't check CRC of broken files
                } else {
                    entry.message = err.message;
                    entry.checkCRC = err.checkCRC; // e.g. skip check when file has other errors
                }
                entry.success = false;
            } else {
                const image = sharp(imagePath, { failOn: "none" })
                    .ensureAlpha()
                    .toColorspace("rgb8");
                entry.rgb8 = (
                    await image.raw({ depth: "uchar" }).toBuffer()
                ).toString("base64");
                entry.success = true;
                entry.checkCRC = true; // by default, check CRC of files that should pass
            }

            output.push(entry);
        }
    }

    output.sort((a, b) => a.key.localeCompare(b.key));

    fs.writeFileSync(outputPath, JSON.stringify(output, null, 2));
})();
