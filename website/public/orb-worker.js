let canvas, ctx, W, H, cx, cy, R;
let time = 0;
let animId = 0;
const TAU = Math.PI * 2;

// Outer colors
const outerColors = [
  Array.from({ length: 101 }, (_, i) => `rgba(0, 113, 227, ${i / 100})`),
  Array.from({ length: 101 }, (_, i) => `rgba(6, 182, 212, ${i / 100})`)
];
const shellBins = [
  Array.from({ length: 101 }, () => []),
  Array.from({ length: 101 }, () => [])
];

const shells = [
  { base: 1.35, spread: 0.08, ribs: 26, points: 260, offset: 0, alpha: 0.74, size: 2.2, speed: 1.35, spin: 0.42, rgb: [0, 113, 227] },
  { base: 1.3, spread: 0.064, ribs: 18, points: 230, offset: 1.34, alpha: 0.56, size: 1.7, speed: 0.95, spin: -0.24, rgb: [6, 182, 212] }
];

function resize(width, height) {
  canvas.width = width;
  canvas.height = height;
  W = width;
  H = height;
  cx = W / 2;
  cy = H / 2;
  R = Math.min(W, H) * 0.314;
}

function loopDisplacement(a, t, wobble, drift, rippleScale) {
  const safeWobble = Math.max(wobble, 0.0001);
  const macro = Math.sin(a * 2.08 + t * 0.86 + drift) * wobble +
                Math.sin(a * 3.46 - t * 0.64 - drift * 0.48) * wobble * 0.52 +
                Math.cos(a * 5.52 + t * 0.36 - drift * 0.25) * wobble * 0.24;
  const macroNorm = macro / safeWobble;
  const carrier = Math.sin(a * 8.7 - t * 1.2 + drift * 1.3 + macroNorm * 0.95);
  const nested = Math.sin(a * 17.8 + t * 1.92 + carrier * 2.4 - drift * 0.7);
  const envelope = 0.54 + 0.46 * Math.pow(Math.abs(Math.sin(a * 1.12 - t * 0.34 + drift * 0.45)), 0.82);
  return macro + (carrier * wobble * rippleScale + nested * wobble * rippleScale * 0.46) * envelope;
}

function traceLoop(radius, t, wobble, drift, detail, rippleScale = 0.2) {
  ctx.beginPath();
  for (let i = 0; i <= detail; i++) {
    const p = i / detail;
    const a = p * TAU;
    const distortion = loopDisplacement(a, t, wobble, drift, rippleScale);
    const rr = radius + distortion;
    const x = cx + Math.cos(a) * rr;
    const y = cy + Math.sin(a) * rr;
    if (i === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  }
  ctx.closePath();
}

function outerRadius(a, phase, base, spread) {
  const slow = Math.sin(a * 2.04 + phase) * spread;
  const mid = Math.sin(a * 3.66 - phase * 1.24) * spread * 0.56;
  const carrier = Math.sin(a * 9.4 + phase * 2.3 + slow / Math.max(spread, 0.0001) * 0.6);
  const nested = Math.sin(a * 18.4 - phase * 3.1 + carrier * 2.7) * spread * 0.18;
  const envelope = 0.5 + 0.5 * Math.pow(Math.abs(Math.sin(a * 1.08 - phase * 0.46)), 0.84);
  return base + slow + mid + (carrier * spread * 0.3 + nested) * envelope;
}

function drawOuterShell(t) {
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  // Removed filter blur to improve performance massively with no visual difference
  // ctx.filter = 'blur(0.08px)';

  for (let sIdx = 0; sIdx < shells.length; sIdx++) {
    const shell = shells[sIdx];
    const colors = outerColors[sIdx];
    const bins = shellBins[sIdx];
    const shellSpinT = t * shell.spin;
    
    for (let b = 0; b <= 100; b++) bins[b].length = 0;

    for (let rib = 0; rib < shell.ribs; rib++) {
      const ribNorm = shell.ribs <= 1 ? 0.5 : rib / (shell.ribs - 1);
      const ribCenter = 1 - Math.pow(Math.abs(ribNorm - 0.5) * 2, 1.45);
      const ribPhase = t * shell.speed + rib * 0.165 + shell.offset;
      const ribRadiusShift = (ribNorm - 0.5) * R * 0.02;
      
      const size = shell.size * (0.74 + ribCenter * 0.66);
      const halfSize = size / 2;
      const ribAlphaBase = shell.alpha * ribCenter;
      const alphaShimmerRib = rib * 0.11;
      
      const sBase = shell.base * R;
      const sSpread = shell.spread * R;

      for (let i = 0; i < shell.points; i++) {
        const p = i / shell.points;
        const a = p * TAU + shellSpinT + rib * 0.006;
        const rr = outerRadius(a, ribPhase, sBase + ribRadiusShift, sSpread);
        const x = cx + Math.cos(a) * rr;
        const y = cy + Math.sin(a) * rr;
        
        const lobe = Math.pow(Math.abs(Math.sin(a * 1.14 - t * 0.76 + shell.offset * 0.5)), 1.48);
        const shimmer = 0.72 + 0.28 * Math.sin(a * 7.2 + t * 3.35 + alphaShimmerRib);
        const travel = 0.7 + 0.3 * Math.sin(a * 2.1 - t * 2.4 + shell.offset);
        
        const alphaVal = (0.18 + ribAlphaBase * (0.54 + 0.46 * lobe)) * shimmer * travel;
        let alphaBin = Math.round(alphaVal * 100);
        if (alphaBin < 0) alphaBin = 0;
        if (alphaBin > 100) alphaBin = 100;
        
        if (alphaBin > 0) {
          bins[alphaBin].push(x - halfSize, y - halfSize, size);
        }
      }
    }
    
    for (let b = 1; b <= 100; b++) {
      const rects = bins[b];
      if (rects.length > 0) {
        ctx.fillStyle = colors[b];
        for (let j = 0; j < rects.length; j += 3) {
          ctx.fillRect(rects[j], rects[j + 1], rects[j + 2], rects[j + 2]);
        }
      }
    }
  }

  ctx.globalCompositeOperation = 'source-over';
  ctx.restore();
}

function drawAtmosphere(t) {
  ctx.save()
  const halo = ctx.createRadialGradient(cx, cy, R * 0.2, cx, cy, R * 1.58)
  halo.addColorStop(0, 'rgba(6, 182, 212, 0.2)')
  halo.addColorStop(0.55, 'rgba(0, 113, 227, 0.18)')
  halo.addColorStop(1, 'rgba(3, 14, 44, 0)')
  ctx.fillStyle = halo
  ctx.beginPath()
  ctx.arc(cx, cy, R * 1.6, 0, TAU)
  ctx.fill()
  ctx.restore()

  ctx.save()
  traceLoop(R * 0.968, t * 0.31, R * 0.02, 1.3, 360, 0.1)
  ctx.clip()

  const body = ctx.createRadialGradient(cx - R * 0.2, cy - R * 0.21, R * 0.05, cx, cy, R * 1.05)
  body.addColorStop(0, 'rgba(7, 31, 74, 0.08)')
  body.addColorStop(0.4, 'rgba(5, 26, 74, 0.24)')
  body.addColorStop(1, 'rgba(2, 18, 58, 0.86)')
  ctx.fillStyle = body
  ctx.fillRect(cx - R * 1.26, cy - R * 1.26, R * 2.52, R * 2.52)

  ctx.globalCompositeOperation = 'lighter'
  ctx.filter = 'blur(22px)'
  const hotspot = ctx.createRadialGradient(cx - R * 0.28, cy - R * 0.17, 0, cx - R * 0.28, cy - R * 0.17, R * 0.66)
  hotspot.addColorStop(0, 'rgba(140, 240, 255, 0.18)')
  hotspot.addColorStop(0.32, 'rgba(6, 182, 212, 0.09)')
  hotspot.addColorStop(1, 'rgba(6, 182, 212, 0)')
  ctx.fillStyle = hotspot
  ctx.beginPath()
  ctx.arc(cx - R * 0.28, cy - R * 0.17, R * 0.66, 0, TAU)
  ctx.fill()

  const rimMist = ctx.createRadialGradient(cx + R * 0.16, cy + R * 0.32, 0, cx + R * 0.16, cy + R * 0.32, R * 0.76)
  rimMist.addColorStop(0, 'rgba(34, 197, 255, 0.1)')
  rimMist.addColorStop(1, 'rgba(34, 197, 255, 0)')
  ctx.fillStyle = rimMist
  ctx.beginPath()
  ctx.arc(cx + R * 0.16, cy + R * 0.32, R * 0.76, 0, TAU)
  ctx.fill()

  const softCore = ctx.createRadialGradient(cx - R * 0.03, cy + R * 0.02, 0, cx - R * 0.03, cy + R * 0.02, R * 0.55)
  softCore.addColorStop(0, 'rgba(0, 113, 227, 0.07)')
  softCore.addColorStop(1, 'rgba(0, 113, 227, 0)')
  ctx.fillStyle = softCore
  ctx.beginPath()
  ctx.arc(cx - R * 0.03, cy + R * 0.02, R * 0.55, 0, TAU)
  ctx.fill()

  ctx.globalCompositeOperation = 'source-over'
  ctx.filter = 'blur(0px)'
  const centerVoid = ctx.createRadialGradient(cx, cy, 0, cx, cy, R * 0.72)
  centerVoid.addColorStop(0, 'rgba(2, 16, 50, 0.78)')
  centerVoid.addColorStop(0.58, 'rgba(2, 16, 50, 0.38)')
  centerVoid.addColorStop(1, 'rgba(2, 16, 50, 0)')
  ctx.fillStyle = centerVoid
  ctx.beginPath()
  ctx.arc(cx, cy, R * 0.72, 0, TAU)
  ctx.fill()

  ctx.filter = 'none'
  ctx.globalCompositeOperation = 'source-over'
  ctx.restore()
}

function drawRings(t) {
  const pulse = 0.92 + 0.08 * Math.sin(t * 1.25)
  ctx.lineCap = 'round'
  ctx.lineJoin = 'round'

  ctx.save()
  ctx.filter = 'blur(30px)'
  traceLoop(R * 0.982, t * 0.52, R * 0.008, 0.2, 440, 0.08)
  ctx.strokeStyle = `rgba(0, 113, 227, ${0.18 * pulse})`
  ctx.lineWidth = R * 0.22
  ctx.stroke()
  ctx.restore()

  ctx.save()
  ctx.filter = 'blur(11px)'
  traceLoop(R * 0.982, t * 0.52, R * 0.008, 0.2, 440, 0.08)
  ctx.strokeStyle = `rgba(6, 182, 212, ${0.22 * pulse})`
  ctx.lineWidth = R * 0.07
  ctx.stroke()
  ctx.restore()

  const mainGrad = ctx.createLinearGradient(cx - R, cy - R * 0.85, cx + R, cy + R)
  mainGrad.addColorStop(0, `rgba(255, 255, 255, ${0.97 * pulse})`)
  mainGrad.addColorStop(0.3, `rgba(254, 254, 255, ${0.96 * pulse})`)
  mainGrad.addColorStop(0.66, `rgba(251, 253, 255, ${0.94 * pulse})`)
  mainGrad.addColorStop(1, `rgba(247, 251, 255, ${0.93 * pulse})`)
  traceLoop(R * 0.982, t * 0.52, R * 0.0065, 0.2, 440, 0.08)
  ctx.save()
  ctx.globalAlpha = 0.9
  ctx.strokeStyle = mainGrad
  ctx.lineWidth = R * 0.0155
  ctx.stroke()
  ctx.restore()

  const secondBlurGrad = ctx.createLinearGradient(cx - R * 1.15, cy + R * 0.6, cx + R * 1.15, cy - R * 0.7)
  secondBlurGrad.addColorStop(0, `rgba(0, 113, 227, ${0.42 * pulse})`)
  secondBlurGrad.addColorStop(0.45, `rgba(6, 182, 212, ${0.38 * pulse})`)
  secondBlurGrad.addColorStop(1, `rgba(52, 211, 153, ${0.28 * pulse})`)
  ctx.save()
  ctx.filter = 'blur(7px)'
  traceLoop(R * 1.016, -t * 0.64, R * 0.049, 2.1, 500, 0.38)
  ctx.strokeStyle = secondBlurGrad
  ctx.lineWidth = R * 0.04
  ctx.stroke()
  ctx.restore()

  const secondCoreGrad = ctx.createLinearGradient(cx - R * 1.15, cy + R * 0.6, cx + R * 1.15, cy - R * 0.7)
  secondCoreGrad.addColorStop(0, `rgba(255, 255, 255, ${0.52 * pulse})`)
  secondCoreGrad.addColorStop(0.45, `rgba(6, 182, 212, ${0.52 * pulse})`)
  secondCoreGrad.addColorStop(1, `rgba(52, 211, 153, ${0.44 * pulse})`)
  traceLoop(R * 1.016, -t * 0.64, R * 0.049, 2.1, 500, 0.38)
  ctx.strokeStyle = secondCoreGrad
  ctx.lineWidth = R * 0.0105
  ctx.stroke()

  const hotA = t * 0.42 + 2.24
  const hotB = t * 0.42 + 5.14
  const hx1 = cx + Math.cos(hotA) * (R * 0.985)
  const hy1 = cy + Math.sin(hotA) * (R * 0.985)
  const hx2 = cx + Math.cos(hotB) * (R * 0.985)
  const hy2 = cy + Math.sin(hotB) * (R * 0.985)

  ctx.save()
  ctx.filter = 'blur(15px)'
  const glow1 = ctx.createRadialGradient(hx1, hy1, 0, hx1, hy1, R * 0.26)
  glow1.addColorStop(0, 'rgba(255, 255, 255, 0.48)')
  glow1.addColorStop(0.35, 'rgba(6, 182, 212, 0.2)')
  glow1.addColorStop(1, 'transparent')
  ctx.fillStyle = glow1
  ctx.beginPath()
  ctx.arc(hx1, hy1, R * 0.26, 0, TAU)
  ctx.fill()

  const glow2 = ctx.createRadialGradient(hx2, hy2, 0, hx2, hy2, R * 0.2)
  glow2.addColorStop(0, 'rgba(52, 211, 153, 0.36)')
  glow2.addColorStop(1, 'transparent')
  ctx.fillStyle = glow2
  ctx.beginPath()
  ctx.arc(hx2, hy2, R * 0.2, 0, TAU)
  ctx.fill()
  ctx.restore()
}

function drawInnerVoid(t) {
  ctx.save()
  const driftX = Math.sin(t * 0.63) * R * 0.032
  const driftY = Math.cos(t * 0.47) * R * 0.026

  const traceBlob = (baseR, wobble, drift, ripple, squashX, squashY, offsetX, offsetY, detail = 360) => {
    ctx.beginPath()
    for (let i = 0; i <= detail; i++) {
      const p = i / detail
      const a = p * TAU
      const disp = loopDisplacement(a, t * 0.88, wobble, drift, ripple)
      const rr = baseR + disp
      const sx = 1 + squashX * Math.sin(a * 1.35 - t * 0.37 + drift)
      const sy = 1 + squashY * Math.cos(a * 1.72 + t * 0.42 - drift * 0.5)
      const x = cx + offsetX + Math.cos(a) * rr * sx
      const y = cy + offsetY + Math.sin(a) * rr * sy
      if (i === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    }
    ctx.closePath()
  }

  traceBlob(R * 0.79, R * 0.078, 0.9, 0.72, 0.14, -0.12, driftX, driftY, 420)
  const darkOuter = ctx.createRadialGradient(cx - R * 0.12 + driftX, cy + R * 0.06 + driftY, R * 0.08, cx + driftX, cy + driftY, R * 0.92)
  darkOuter.addColorStop(0, 'rgba(2, 16, 50, 0.68)')
  darkOuter.addColorStop(0.58, 'rgba(2, 16, 50, 0.34)')
  darkOuter.addColorStop(1, 'rgba(2, 16, 50, 0)')
  ctx.fillStyle = darkOuter
  ctx.fill()

  traceBlob(R * 0.56, R * 0.062, 2.4, 0.78, -0.16, 0.12, -driftX * 0.8, -driftY * 0.6, 380)
  const cavity = ctx.createRadialGradient(cx + R * 0.03 - driftX * 0.6, cy - R * 0.05 - driftY * 0.3, 0, cx - driftX * 0.2, cy - driftY * 0.15, R * 0.66)
  cavity.addColorStop(0, 'rgba(2, 16, 50, 0.56)')
  cavity.addColorStop(1, 'rgba(2, 16, 50, 0)')
  ctx.fillStyle = cavity
  ctx.fill()

  traceBlob(R * 0.37, R * 0.048, 4.1, 0.82, 0.2, -0.18, R * 0.06, -R * 0.03, 320)
  const pocket = ctx.createRadialGradient(cx + R * 0.08, cy - R * 0.08, 0, cx + R * 0.08, cy - R * 0.08, R * 0.45)
  pocket.addColorStop(0, 'rgba(2, 16, 50, 0.44)')
  pocket.addColorStop(1, 'rgba(2, 16, 50, 0)')
  ctx.fillStyle = pocket
  ctx.fill()

  ctx.globalCompositeOperation = 'lighter'
  ctx.filter = 'blur(10px)'
  traceBlob(R * 0.62, R * 0.022, 1.2, 0.5, 0.08, -0.05, driftX * 0.3, driftY * 0.3, 360)
  ctx.strokeStyle = 'rgba(6, 182, 212, 0.1)'
  ctx.lineWidth = R * 0.038
  ctx.stroke()

  traceBlob(R * 0.46, R * 0.02, 3.1, 0.55, -0.09, 0.07, -R * 0.05, R * 0.03, 340)
  ctx.strokeStyle = 'rgba(0, 113, 227, 0.08)'
  ctx.lineWidth = R * 0.03
  ctx.stroke()

  ctx.filter = 'blur(16px)'
  const energy = ctx.createRadialGradient(
    cx - R * 0.15 + driftX * 0.5,
    cy - R * 0.11 + driftY * 0.4,
    0,
    cx - R * 0.15 + driftX * 0.5,
    cy - R * 0.11 + driftY * 0.4,
    R * 0.3,
  )
  energy.addColorStop(0, 'rgba(6, 182, 212, 0.08)')
  energy.addColorStop(1, 'rgba(6, 182, 212, 0)')
  ctx.fillStyle = energy
  ctx.beginPath()
  ctx.arc(cx - R * 0.15 + driftX * 0.5, cy - R * 0.11 + driftY * 0.4, R * 0.3, 0, TAU)
  ctx.fill()
  ctx.restore()
}

function frame() {
  time += 0.0066;
  const breathe = 1 + 0.018 * Math.sin(time * 0.9);
  ctx.clearRect(0, 0, W, H);
  ctx.save();
  ctx.translate(cx, cy);
  ctx.scale(breathe, breathe);
  ctx.translate(-cx, -cy);

  const glowPulse = 0.7 + 0.3 * Math.sin(time * 1.1);
  ctx.globalAlpha = glowPulse;
  drawAtmosphere(time);
  ctx.globalAlpha = 1;
  drawOuterShell(time);
  drawRings(time);
  drawInnerVoid(time);
  ctx.restore();
  
  animId = requestAnimationFrame(frame);
}

self.onmessage = function(e) {
  const msg = e.data;
  if (msg.type === 'init') {
    canvas = msg.canvas;
    ctx = canvas.getContext('2d');
    resize(msg.width, msg.height);
    if (!animId) animId = requestAnimationFrame(frame);
  } else if (msg.type === 'resize') {
    resize(msg.width, msg.height);
  } else if (msg.type === 'stop') {
    if (animId) cancelAnimationFrame(animId);
    animId = 0;
  } else if (msg.type === 'start') {
    if (!animId) animId = requestAnimationFrame(frame);
  }
};
