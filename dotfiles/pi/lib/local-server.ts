/**
 * Detecting a local server.
 *
 * Split out and tested because getting this wrong is subtle: `docusaurus serve`
 * binds IPv6 loopback, so a raw TCP connect to 127.0.0.1 reports "nothing
 * running" while the site is up — which then makes a caller start a second
 * server, fail because the port is taken, and time out waiting for it.
 *
 * See tests/unit.test.ts.
 */

import * as net from "node:net";

/**
 * Whether a real HTTP server answers on the port.
 *
 * `fetch` resolves localhost across both address families, and a successful
 * response also proves the server is alive rather than a socket held open by a
 * dead process.
 */
export async function httpResponding(port: number, timeoutMs = 1500): Promise<boolean> {
	try {
		const response = await fetch(`http://localhost:${port}/`, {
			signal: AbortSignal.timeout(timeoutMs),
		});
		return response.ok;
	} catch {
		return false;
	}
}

/** Whether anything holds the port, responding or not. Checks both families. */
export function portBound(port: number, timeoutMs = 700): Promise<boolean> {
	return new Promise((resolve) => {
		let settled = false;
		const done = (bound: boolean) => {
			if (settled) return;
			settled = true;
			resolve(bound);
		};

		for (const host of ["127.0.0.1", "::1"]) {
			const socket = net.connect({ port, host });
			socket.setTimeout(timeoutMs);
			socket.on("connect", () => {
				socket.destroy();
				done(true);
			});
			socket.on("timeout", () => socket.destroy());
			socket.on("error", () => undefined);
		}

		setTimeout(() => done(false), timeoutMs);
	});
}

export async function waitForHttp(port: number, timeoutMs: number): Promise<boolean> {
	const deadline = Date.now() + timeoutMs;
	while (Date.now() < deadline) {
		if (await httpResponding(port)) return true;
		await new Promise((resolve) => setTimeout(resolve, 300));
	}
	return false;
}
