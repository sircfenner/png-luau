export type PNG = {
	width: number,
	height: number,
	pixels: buffer,
	readPixel: (x: number, y: number) -> (number, number, number, number),
}

export type Chunk = {
	type: string,
	offset: number,
	length: number,
}

export type IHDRChunk = {
	width: number,
	height: number,
	bitDepth: number,
	colorType: number,
	interlaced: boolean,
}

type PaletteColor = {
	r: number,
	g: number,
	b: number,
	a: number,
}

export type PLTEChunk = {
	colors: { PaletteColor },
}

export type tRNSChunk = {
	gray: number,
	red: number,
	green: number,
	blue: number,
}

return {}
