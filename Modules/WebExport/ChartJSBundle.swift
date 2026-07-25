import Foundation

/// Embedded Chart.js library for self-contained HTML reports
/// Using a minimal CDN reference since embedding 200KB+ inline is impractical
struct ChartJSBundle {
    /// Minimal inline chart implementation for truly offline reports
    static let inlineChartJS: String = """
    // Minimal chart renderer using Canvas API (no external dependencies)
    class SimpleChart {
        constructor(ctx, config) {
            this.ctx = ctx.getContext('2d');
            this.canvas = ctx;
            this.config = config;
            this.render();
        }

        render() {
            const { type, data, options } = this.config;
            const ctx = this.ctx;
            const w = this.canvas.width;
            const h = this.canvas.height;
            const padding = 50;

            ctx.clearRect(0, 0, w, h);

            if (type === 'line') {
                this.renderLine(data, padding, w, h);
            }
        }

        renderLine(data, padding, w, h) {
            const ctx = this.ctx;
            const dataset = data.datasets[0];
            const values = dataset.data;
            const labels = data.labels;

            if (!values || values.length === 0) return;

            const min = Math.min(...values) * 0.95;
            const max = Math.max(...values) * 1.05;
            const range = max - min || 1;

            const plotW = w - padding * 2;
            const plotH = h - padding * 2;

            // Grid
            ctx.strokeStyle = '#e0e0e0';
            ctx.lineWidth = 0.5;
            for (let i = 0; i <= 4; i++) {
                const y = padding + (plotH / 4) * i;
                ctx.beginPath();
                ctx.moveTo(padding, y);
                ctx.lineTo(w - padding, y);
                ctx.stroke();

                const val = max - (range / 4) * i;
                ctx.fillStyle = '#999';
                ctx.font = '11px -apple-system, sans-serif';
                ctx.textAlign = 'right';
                ctx.fillText(val.toFixed(1), padding - 8, y + 4);
            }

            // X labels
            const step = Math.max(1, Math.floor(labels.length / 6));
            ctx.textAlign = 'center';
            for (let i = 0; i < labels.length; i += step) {
                const x = padding + (plotW / (values.length - 1)) * i;
                ctx.fillText(labels[i], x, h - padding + 20);
            }

            // Line
            ctx.strokeStyle = dataset.borderColor || '#007AFF';
            ctx.lineWidth = 2;
            ctx.lineJoin = 'round';
            ctx.beginPath();

            for (let i = 0; i < values.length; i++) {
                const x = padding + (plotW / (values.length - 1)) * i;
                const y = padding + plotH - ((values[i] - min) / range) * plotH;
                if (i === 0) ctx.moveTo(x, y);
                else ctx.lineTo(x, y);
            }
            ctx.stroke();

            // Fill
            const lastX = padding + plotW;
            const bottomY = padding + plotH;
            ctx.lineTo(lastX, bottomY);
            ctx.lineTo(padding, bottomY);
            ctx.closePath();
            ctx.fillStyle = (dataset.backgroundColor || 'rgba(0,122,255,0.1)');
            ctx.fill();
        }
    }

    // Chart.js compatibility shim
    window.Chart = SimpleChart;
    """
}
