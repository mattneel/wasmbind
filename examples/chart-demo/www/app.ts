import { Chart, Candle, loadWasm } from "./generated/bindings.js";

const outputEl = document.getElementById("output") as HTMLPreElement;
const canvas = document.getElementById("chart") as HTMLCanvasElement;
const ctx = canvas.getContext("2d")!;

let wasmInstance: WebAssembly.Instance | null = null;
let chart: Chart | null = null;

function log(message: string): void {
    outputEl.textContent = `${outputEl.textContent ?? ""}${message}\n`;
    outputEl.scrollTop = outputEl.scrollHeight;
    console.log(message);
}

function randomCandle(): Candle {
    const base = Math.random() * 100 + 50;
    const high = base + Math.random() * 5;
    const low = base - Math.random() * 5;
    const close = base + (Math.random() - 0.5) * 10;

    return {
        timestamp: BigInt(Date.now()),
        open: base,
        high,
        low,
        close,
        volume: Math.random() * 100_000,
    };
}

function drawPixels(pixels: Uint8Array): void {
    const imageData = ctx.createImageData(canvas.width, canvas.height);
    for (let i = 0; i < imageData.data.length; i += 4) {
        const srcIndex = i % pixels.length;
        imageData.data[i + 0] = pixels[srcIndex + 0] ?? 0xff;
        imageData.data[i + 1] = pixels[srcIndex + 1] ?? 0x00;
        imageData.data[i + 2] = pixels[srcIndex + 2] ?? 0x00;
        imageData.data[i + 3] = pixels[srcIndex + 3] ?? 0xff;
    }
    ctx.putImageData(imageData, 0, 0);
}

async function ensureWasm(): Promise<WebAssembly.Instance> {
    if (wasmInstance) return wasmInstance;
    wasmInstance = await loadWasm("../zig-out/lib/chart-demo.wasm");
    log("WASM module loaded");
    return wasmInstance;
}

async function handleInit(): Promise<void> {
    if (chart) {
        log("Chart already initialized");
        return;
    }

    const wasm = await ensureWasm();
    chart = new Chart(wasm, 800, 480);
    chart.setTitle("Tiger Style Price Action");
    log(`Chart initialized (${chart.width}x${chart.height})`);
}

function handleAddCandle(): void {
    if (!chart) {
        log("Initialize the chart first");
        return;
    }

    const candle = randomCandle();
    chart.addCandle(candle);
    log(
        `Added candle: open=${candle.open.toFixed(2)} close=${candle.close.toFixed(
            2,
        )}`,
    );
}

function handleAddMany(): void {
    if (!chart) {
        log("Initialize the chart first");
        return;
    }

    const samples = new Float64Array(256);
    for (let i = 0; i < samples.length; i += 1) {
        samples[i] = Math.random() * 100 + 100;
    }

    chart.setSeries(samples);
    log(`Stored ${samples.length} sample points`);
}

function handleRender(): void {
    if (!chart) {
        log("Initialize the chart first");
        return;
    }

    const pixels = chart.render();
    log(`Render returned ${pixels.length} bytes`);
    drawPixels(pixels);
}

function handleDestroy(): void {
    if (!chart) {
        log("Chart is not initialized");
        return;
    }

    chart.destroy();
    chart = null;
    log("Chart destroyed");
}

function wireUi(): void {
    document.getElementById("init")?.addEventListener("click", () => {
        handleInit().catch((err) => {
            console.error(err);
            log(`Init error: ${String(err)}`);
        });
    });
    document.getElementById("addCandle")?.addEventListener("click", handleAddCandle);
    document.getElementById("addMany")?.addEventListener("click", handleAddMany);
    document.getElementById("render")?.addEventListener("click", handleRender);
    document.getElementById("destroy")?.addEventListener("click", handleDestroy);
}

wireUi();

window.addEventListener("beforeunload", () => {
    if (chart) {
        chart.destroy();
        chart = null;
    }
});
