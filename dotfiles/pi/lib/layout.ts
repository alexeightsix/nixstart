/** Dependency-free text layout helpers shared by rendered extensions. */

/** Format labels into fixed-width columns with an explicit readable gap. */
export function formatColumns(items: string[], width: number, columns: number, gap = "  "): string[] {
	const rows: string[] = [];
	for (let index = 0; index < items.length; index += columns) {
		rows.push(
			items
				.slice(index, index + columns)
				.map((item) => item.padEnd(width))
				.join(gap)
				.trimEnd(),
		);
	}
	return rows;
}
