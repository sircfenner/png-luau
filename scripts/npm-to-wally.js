#!/usr/bin/env node

// from: https://github.com/sircfenner/StudioComponents/blob/main/scripts/npm-to-wally.js

const fs = require("fs").promises;
const path = require("path");
const process = require("process");

const extractPackageNameWhenScoped = (packageName) =>
    packageName.startsWith("@")
        ? packageName.substring(packageName.indexOf("/") + 1)
        : packageName;

const readPackageConfig = async (packagePath) => {
    const packageContent = await fs.readFile(packagePath).catch((err) => {
        console.error(
            `unable to read package.json at '${packagePath}': ${err}`
        );
        return null;
    });

    if (packageContent !== null) {
        try {
            const packageData = JSON.parse(packageContent);
            return packageData;
        } catch (error) {
            console.error(
                `unable to parse package.json at '${packagePath}': ${err}`
            );
        }
    }

    return null;
};

const main = async (
    packageJsonPath,
    wallyOutputPath,
    wallyRojoConfigPath,
    rojoConfigPath
) => {
    const packageData = await readPackageConfig(packageJsonPath);

    const {
        name: scopedName,
        version,
        license,
        dependencies = [],
        description,
    } = packageData;

    const tomlLines = ["[package]", `name = "${scopedName.substring(1)}"`];

    if (description) {
        tomlLines.push(`description = "${description}"`);
    }

    tomlLines.push(
        `version = "${version}"`,
        'registry = "https://github.com/UpliftGames/wally-index"',
        'realm = "shared"',
        `license = "${license}"`,
        "",
        "[dependencies]"
    );

    const rojoConfig = {
        name: "WallyPackage",
        tree: {
            $className: "Folder",
            Package: {
                $path: "src",
            },
        },
    };

    for (const [dependencyName, specifiedVersion] of Object.entries(
        dependencies
    )) {
        const name = extractPackageNameWhenScoped(dependencyName);
        rojoConfig.tree[name] = {
            $path: `${dependencyName}.luau`,
        };

        const wallyPackageName = name.indexOf("-") !== -1 ? `"${name}"` : name;
        if (specifiedVersion == "workspace:^") {
            error("workspace version not supported");
        } else {
            tomlLines.push(
                `${wallyPackageName} = "jsdotlua/${name}@${specifiedVersion}"`
            );
        }
    }

    tomlLines.push("");

    const wallyRojoConfig = {
        name: scopedName.substring(scopedName.indexOf("/") + 1),
        tree: {
            $path: "src",
        },
    };

    await Promise.all([
        fs.writeFile(wallyOutputPath, tomlLines.join("\n")).catch((err) => {
            console.error(
                `unable to write wally config at '${wallyOutputPath}': ${err}`
            );
        }),
        fs
            .writeFile(rojoConfigPath, JSON.stringify(rojoConfig, null, 2))
            .catch((err) => {
                console.error(
                    `unable to write rojo config at '${rojoConfigPath}': ${err}`
                );
            }),
        fs
            .writeFile(
                wallyRojoConfigPath,
                JSON.stringify(wallyRojoConfig, null, 2)
            )
            .catch((err) => {
                console.error(
                    `unable to write rojo config for wally at '${wallyRojoConfigPath}': ${err}`
                );
            }),
    ]);
};

const run = async (packageJson, wallyToml, wallyRojoConfig, rojoConfig) => {
    const cwd = process.cwd();
    await main(
        path.join(cwd, packageJson),
        path.join(cwd, wallyToml),
        path.join(cwd, wallyRojoConfig),
        path.join(cwd, rojoConfig)
    );
};

const [, , packageJson, wallyToml, wallyRojoConfig, rojoConfig] = process.argv;
run(packageJson, wallyToml, wallyRojoConfig, rojoConfig);
