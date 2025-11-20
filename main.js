const circuitCanvas = document.getElementById("circuit");
const circuitCtx = circuitCanvas.getContext("2d");
let primary = getComputedStyle(
  document.documentElement,
).getPropertyValue("--primary-color");

let nodes = [];
const nodeCount = 60;
let cursorPos = { x: null, y: null };

function initNodes() {
  nodes = Array.from({ length: nodeCount }, () => ({
    x: Math.random() * circuitCanvas.width,
    y: Math.random() * circuitCanvas.height,
    vx: (Math.random() - 0.5) * 0.5,
    vy: (Math.random() - 0.5) * 0.5,
  }));
}

function resize() {
  const w = document.documentElement.clientWidth;
  const h = document.documentElement.clientHeight;
  circuitCanvas.width = w;
  circuitCanvas.height = h;
  initNodes();
}

window.addEventListener("resize", resize);
resize();

window.addEventListener("mousemove", (e) => {
  cursorPos.x = e.clientX;
  cursorPos.y = e.clientY;
});

function drawCircuit() {
  circuitCtx.fillStyle = "rgba(10, 10, 10, 0.1)";
  circuitCtx.fillRect(0, 0, circuitCanvas.width, circuitCanvas.height);

  for (const n of nodes) {
    n.x += n.vx;
    n.y += n.vy;
    if (n.x < 0 || n.x > circuitCanvas.width) n.vx *= -1;
    if (n.y < 0 || n.y > circuitCanvas.height) n.vy *= -1;

    circuitCtx.fillStyle = primary;
    circuitCtx.beginPath();
    circuitCtx.arc(n.x, n.y, 2, 0, Math.PI * 2);
    circuitCtx.fill();

    for (const m of nodes) {
      if (n === m) continue;
      const dx = n.x - m.x;
      const dy = n.y - m.y;
      const dist = Math.hypot(dx, dy);
      if (dist < 60) {
        circuitCtx.strokeStyle = primary;
        circuitCtx.globalAlpha = 0.2;
        circuitCtx.beginPath();
        circuitCtx.moveTo(n.x, n.y);
        circuitCtx.lineTo(m.x, m.y);
        circuitCtx.stroke();
        circuitCtx.globalAlpha = 1;
      }
    }

    if (cursorPos.x !== null) {
      const dx = n.x - cursorPos.x;
      const dy = n.y - cursorPos.y;
      const dist = Math.hypot(dx, dy);
      if (dist < 120) {
        circuitCtx.strokeStyle = primary;
        circuitCtx.globalAlpha = 0.4;
        circuitCtx.beginPath();
        circuitCtx.moveTo(n.x, n.y);
        circuitCtx.lineTo(cursorPos.x, cursorPos.y);
        circuitCtx.stroke();
        circuitCtx.globalAlpha = 1;
      }
    }
  }

  requestAnimationFrame(drawCircuit);
}

drawCircuit();

const cursor = document.getElementById("cursor");
document.addEventListener("mousemove", (e) => {
  cursor.style.left = `${e.clientX}px`;
  cursor.style.top = `${e.clientY}px`;
});

document.addEventListener("click", () => {
  cursor.classList.add("expand");
  setTimeout(() => cursor.classList.remove("expand"), 200);
});

const title = document.querySelector(".glitch");
setInterval(() => {
  title.classList.add("active");
  setTimeout(() => title.classList.remove("active"), 1000);
}, 4000);

function updateColor() {
  const hue = 110 + Math.floor(Math.random() * 40);
  primary = `hsl(${hue}, 70%, 50%)`;
  document.documentElement.style.setProperty("--primary-color", primary);
  document.documentElement.style.setProperty(
    "--glow-color",
    `hsla(${hue}, 70%, 50%, 0.75)`,
  );
}
setInterval(updateColor, 5000);
// Timer Logic
(function () {
  const timerElement = document.getElementById("countdown-timer");
  if (!timerElement) return;

  // Target date: December 19, 2025 09:30:00 London Time
  // London in December is GMT (UTC+0)
  const targetDate = new Date("2025-12-19T09:30:00Z").getTime();

  function updateTimer() {
    const now = new Date().getTime();
    const distance = targetDate - now;

    if (distance < 0) {
      timerElement.innerHTML = "0:00:00:00";
      return;
    }

    const days = Math.floor(distance / (1000 * 60 * 60 * 24));
    const hours = Math.floor((distance % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    const minutes = Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60));
    const seconds = Math.floor((distance % (1000 * 60)) / 1000);

    // Format with colons: DDD:HH:MM:SS
    // Ensure 2 digits for hours, minutes, seconds. Days can be variable length.
    timerElement.innerHTML =
      `${days}:${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  }

  setInterval(updateTimer, 1000);
  updateTimer(); // Initial call
})();

// --- Decrypt Effect ---
class DecryptEffect {
  constructor(element) {
    this.element = element;
    this.originalText = element.innerText;
    this.chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()_+";
    this.duration = 1500;
    this.frame = 0;
    this.totalFrames = 30;
    if (this.originalText.trim() !== "") {
      this.animate();
    }
  }

  animate() {
    let iterations = 0;
    const interval = setInterval(() => {
      this.element.innerText = this.originalText
        .split("")
        .map((letter, index) => {
          if (index < iterations) {
            return this.originalText[index];
          }
          return this.chars[Math.floor(Math.random() * this.chars.length)];
        })
        .join("");

      if (iterations >= this.originalText.length) {
        clearInterval(interval);
      }

      iterations += 1 / 4; // Speed control
    }, 70);
  }
}

document.querySelectorAll(".decrypt-effect").forEach((el) => {
  // Wait a bit for the typing animation to finish or run in parallel?
  // Let's run it immediately but maybe we should remove the typed-text class if we use this?
  // Actually, the user asked for decrypting effect ON LOAD.
  // The existing 'typed-text' is CSS animation. Let's override or coexist.
  // For now, let's just run it.
  new DecryptEffect(el);
});

// --- HUD Logic ---
const hudCoords = document.getElementById("hud-coords");
const hudTimer = document.getElementById("hud-timer");
const startTime = Date.now();

document.addEventListener("mousemove", (e) => {
  if (hudCoords) {
    hudCoords.innerText = `X: ${e.clientX.toString().padStart(4, '0')} Y: ${e.clientY.toString().padStart(4, '0')}`;
  }
});

setInterval(() => {
  if (hudTimer) {
    const elapsed = Date.now() - startTime;
    const date = new Date(elapsed);
    const h = date.getUTCHours().toString().padStart(2, '0');
    const m = date.getUTCMinutes().toString().padStart(2, '0');
    const s = date.getUTCSeconds().toString().padStart(2, '0');
    hudTimer.innerText = `SESSION: ${h}:${m}:${s}`;
  }
}, 1000);

// --- ASCII Art Logic ---
function generateAscii(img, canvas) {
  const ctx = canvas.getContext("2d");
  const width = 100; // Low res for ASCII
  const height = (img.height / img.width) * width;

  canvas.width = width;
  canvas.height = height;

  // Draw image to small canvas to get pixel data
  const tempCanvas = document.createElement('canvas');
  tempCanvas.width = width;
  tempCanvas.height = height;
  const tempCtx = tempCanvas.getContext('2d');
  tempCtx.drawImage(img, 0, 0, width, height);

  const imageData = tempCtx.getImageData(0, 0, width, height);
  const data = imageData.data;
  const chars = "@%#*+=-:. ";

  ctx.fillStyle = "#000";
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.font = "10px monospace";
  ctx.fillStyle = "#00ff41"; // Primary color

  // We need to scale the text rendering to fit the original image size
  // But here we are drawing on a small canvas. 
  // Wait, we want the ASCII to overlay the ORIGINAL image.
  // So the canvas should be the size of the original image.

  canvas.width = img.width;
  canvas.height = img.height;
  // Clear again
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = "rgba(0, 0, 0, 0.9)";
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = "#00ff41";

  const colWidth = canvas.width / width;
  const rowHeight = canvas.height / height;

  ctx.font = `${colWidth * 1.5}px monospace`; // Adjust font size

  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const offset = (y * width + x) * 4;
      const r = data[offset];
      const g = data[offset + 1];
      const b = data[offset + 2];
      const avg = (r + g + b) / 3;
      const charIndex = Math.floor((avg / 255) * (chars.length - 1));
      const char = chars[charIndex];

      ctx.fillText(char, x * colWidth, y * rowHeight + rowHeight);
    }
  }
}

// Expose for use in pics/index.html
window.attachAsciiEffect = function (imgElement) {
  const wrapper = document.createElement("div");
  wrapper.className = "ascii-container";

  // Insert wrapper before img
  imgElement.parentNode.insertBefore(wrapper, imgElement);
  // Move img into wrapper
  wrapper.appendChild(imgElement);

  const canvas = document.createElement("canvas");
  canvas.className = "ascii-canvas";
  wrapper.appendChild(canvas);

  // Generate when image loads or if already loaded
  if (imgElement.complete) {
    generateAscii(imgElement, canvas);
  } else {
    imgElement.onload = () => generateAscii(imgElement, canvas);
  }
};

// --- Markdown Parser ---
window.parseMarkdown = function (text) {
  // Remove frontmatter
  text = text.replace(/^---\n[\s\S]*?\n---\n/, '');

  // Headers
  text = text.replace(/^# (.*$)/gim, '<h1>$1</h1>');
  text = text.replace(/^## (.*$)/gim, '<h2>$1</h2>');
  text = text.replace(/^### (.*$)/gim, '<h3>$1</h3>');

  // Blockquotes
  text = text.replace(/^> (.*$)/gim, '<blockquote>$1</blockquote>');

  // Bold
  text = text.replace(/\*\*(.*)\*\*/gim, '<b>$1</b>');

  // Italic
  text = text.replace(/\*(.*)\*/gim, '<i>$1</i>');

  // Links
  text = text.replace(/\[([^\]]+)\]\(([^)]+)\)/gim, '<a href="$2">$1</a>');

  // Code Block
  text = text.replace(/```([\s\S]*?)```/gim, '<pre><code>$1</code></pre>');

  // Inline Code
  text = text.replace(/`([^`]+)`/gim, '<code>$1</code>');

  // Lists (unordered)
  text = text.replace(/^\s*-\s(.*)/gim, '<ul><li>$1</li></ul>');
  // Fix nested uls (hacky but works for simple lists)
  text = text.replace(/<\/ul>\s*<ul>/gim, '');

  // Paragraphs (double newline)
  text = text.replace(/\n\n/gim, '</p><p>');

  // Wrap in p if not starting with a tag
  // This is a very basic parser, might need refinement
  if (!text.trim().startsWith('<')) {
    text = '<p>' + text + '</p>';
  }

  // Line breaks
  text = text.replace(/\n/gim, '<br />');

  // Clean up empty p tags
  text = text.replace(/<p><\/p>/gim, '');

  return text.trim();
};
