import Foundation

/// HTML/CSS/JS template for the web export report
struct ReportTemplate {

    static let css: String = """
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        background: #f5f5f7;
        color: #1d1d1f;
        padding: 20px;
        max-width: 1200px;
        margin: 0 auto;
    }
    .header {
        text-align: center;
        padding: 40px 20px;
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        border-radius: 20px;
        color: white;
        margin-bottom: 24px;
    }
    .header h1 { font-size: 28px; margin-bottom: 8px; }
    .header .date { opacity: 0.8; font-size: 14px; }
    .score-hero {
        background: linear-gradient(160deg, #1a1a2e 0%, #16213e 40%, #0f3460 100%);
        border-radius: 24px;
        margin-bottom: 24px;
        overflow: hidden;
        position: relative;
    }
    .score-hero::before {
        content: '';
        position: absolute;
        top: -50%;
        left: -50%;
        width: 200%;
        height: 200%;
        background: radial-gradient(circle at 60% 40%, rgba(102, 126, 234, 0.15) 0%, transparent 60%);
        pointer-events: none;
    }
    .score-hero-inner {
        position: relative;
        padding: 48px 20px 40px;
        display: flex;
        flex-direction: column;
        align-items: center;
    }
    .score-label-top {
        font-size: 11px;
        font-weight: 700;
        letter-spacing: 2.5px;
        color: rgba(255, 255, 255, 0.5);
        margin-bottom: 24px;
    }
    .score-ring-large {
        width: 220px;
        height: 220px;
        position: relative;
        margin-bottom: 24px;
    }
    .score-ring-large svg {
        width: 100%;
        height: 100%;
        transform: rotate(-90deg);
    }
    .score-ring-progress {
        animation: scoreReveal 1.5s ease-out forwards;
    }
    @keyframes scoreReveal {
        from { stroke-dashoffset: 565.5; }
    }
    .score-number {
        position: absolute;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        font-size: 64px;
        font-weight: 800;
        color: white;
        letter-spacing: -2px;
        line-height: 1;
    }
    .score-grade-badge {
        display: inline-block;
        padding: 8px 24px;
        border-radius: 100px;
        font-size: 14px;
        font-weight: 600;
        letter-spacing: 0.3px;
        backdrop-filter: blur(10px);
    }
    .card {
        background: white;
        border-radius: 16px;
        padding: 20px;
        margin-bottom: 16px;
        box-shadow: 0 2px 12px rgba(0,0,0,0.06);
    }
    .card h2 { font-size: 18px; margin-bottom: 12px; }
    .card h3 { font-size: 15px; margin-bottom: 8px; color: #555; }
    .categories {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
        gap: 16px;
        margin-bottom: 24px;
    }
    .category-card {
        background: white;
        border-radius: 16px;
        padding: 20px;
        box-shadow: 0 2px 12px rgba(0,0,0,0.06);
    }
    .category-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 12px;
    }
    .category-score {
        font-size: 24px;
        font-weight: 700;
    }
    .insight-card {
        background: white;
        border-radius: 16px;
        padding: 16px;
        margin-bottom: 12px;
        box-shadow: 0 2px 12px rgba(0,0,0,0.06);
        border-left: 4px solid;
    }
    .insight-card.critical { border-left-color: #ff3b30; }
    .insight-card.warning { border-left-color: #ff9500; }
    .insight-card.info { border-left-color: #007aff; }
    .insight-title { font-weight: 600; margin-bottom: 6px; }
    .insight-summary { font-size: 13px; color: #666; margin-bottom: 8px; }
    .insight-recommendation {
        font-size: 13px;
        background: #fff9e6;
        padding: 10px;
        border-radius: 8px;
    }
    .badge {
        display: inline-block;
        padding: 2px 8px;
        border-radius: 10px;
        font-size: 11px;
        font-weight: 600;
    }
    .badge.critical { background: #ffe5e5; color: #ff3b30; }
    .badge.warning { background: #fff3e0; color: #ff9500; }
    .badge.info { background: #e3f2fd; color: #007aff; }
    .badge.improving { background: #e8f5e9; color: #34c759; }
    .badge.stable { background: #f5f5f5; color: #8e8e93; }
    .badge.declining { background: #ffe5e5; color: #ff3b30; }
    .chart-container {
        position: relative;
        height: 250px;
        margin: 16px 0;
    }
    .chart-container canvas {
        width: 100% !important;
        height: 100% !important;
    }
    .stats-grid {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 12px;
        margin-top: 12px;
    }
    .stat-item { text-align: center; }
    .stat-value { font-size: 18px; font-weight: 600; }
    .stat-label { font-size: 12px; color: #999; }
    .footer {
        text-align: center;
        padding: 20px;
        font-size: 12px;
        color: #999;
    }
    @media (prefers-color-scheme: dark) {
        body { background: #1c1c1e; color: #f5f5f7; }
        .card, .category-card, .insight-card { background: #2c2c2e; }
        .insight-recommendation { background: #3a3a3c; }
        .insight-summary { color: #aaa; }
        .card h3, .stat-label { color: #999; }
    }
    @media (max-width: 480px) {
        .score-ring-large { width: 180px; height: 180px; }
        .score-number { font-size: 52px; }
        .score-hero-inner { padding: 36px 16px 32px; }
    }
    """

    static func html(title: String, date: String, body: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(title)</title>
            <style>\(css)</style>
        </head>
        <body>
            <div class="header">
                <h1>\(title)</h1>
                <div class="date">Generated: \(date)</div>
            </div>
            \(body)
            <div class="footer">
                Generated by Laso &middot; All data processed on-device &middot; No cloud storage
            </div>
            <script>
            \(ChartJSBundle.inlineChartJS)
            </script>
        </body>
        </html>
        """
    }
}
