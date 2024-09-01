export type PNG = {
	width: number,
	height: number,
	pixels: buffer,
	readPixel: (x: number, y: number) -> Color,
}

export type Chunk = {
	type: string,
	offset: number,
	length: number,
}

export type Color = {
	r: number,
	g: number,
	b: number,
	a: number,
}

return {}
