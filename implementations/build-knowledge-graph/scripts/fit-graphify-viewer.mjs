import { readFile, writeFile } from "node:fs/promises";

const htmlPath = process.argv[2];
if (!htmlPath) throw new Error("Graphify HTML path is required");

const source = await readFile(htmlPath, "utf8");
const original = `network.once('stabilizationIterationsDone', () => {
  network.setOptions({ physics: { enabled: false } });
});`;
const fitted = `network.once('stabilizationIterationsDone', () => {
  network.setOptions({ physics: { enabled: false } });
  requestAnimationFrame(() => network.fit({ animation: false }));
});`;

if (!source.includes(original)) {
  throw new Error("Graphify viewer stabilization hook changed");
}

await writeFile(htmlPath, source.replace(original, fitted));
