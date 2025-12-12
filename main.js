document.addEventListener("DOMContentLoaded", () => {
  initCircuit();
  initGlobalListeners();
  initRouter();
});

/* --- Router --- */
function initRouter() {
  // Intercept all clicks on links
  document.addEventListener("click", (e) => {
    const link = e.target.closest("a");
    if (!link) return;

    const href = link.getAttribute("href");
    const url = new URL(link.href);

    // Ignore external links or hash links
    if (url.origin !== window.location.origin || href.startsWith("#")) {
      return;
    }

    // Allow download links or explicit targets
    if (link.getAttribute("target") === "_blank") return;

    e.preventDefault();

    // Clean URL (remove index.html)
    let cleanPath = url.pathname;
    // Ensure clean path (remove index.html)
    if (cleanPath.endsWith("/index.html")) {
      cleanPath = cleanPath.replace("/index.html", "/");
    } else if (cleanPath.endsWith("index.html")) {
      cleanPath = cleanPath.replace("index.html", "");
    }

    // Fix relative path issue for SPA
    // If we are at /pics/ and click "Blog" (../blog/), the browser resolves the URL correctly to /blog/ before we get it.
    // However, the cleanPath logic above assumes we want to push that exact resolved path.

    // Note: if we are at /pics/ and click a link that resolves to /pics/index.html, cleanPath becomes /pics/

    // Construct search/hash if needed
    const cleanUrl = cleanPath + url.search + url.hash;

    window.history.pushState({}, "", cleanUrl);
    handleLocation();
  });

  // Handle browser navigation (back/forward)
  window.addEventListener("popstate", handleLocation);

  // Initial load
  handleLocation(true);
}

async function handleLocation(isInitial = false) {
  const path = window.location.pathname;
  const search = window.location.search;

  // If initial load, just trigger the specific logic for the current page
  // because the HTML is already loaded.
  if (isInitial) {
    runPageScript(path, search);
    return;
  }

  // Determine which file to fetch based on path
  let fetchUrl = path;

  // Normalization logic matching static server behavior
  if (path.endsWith("/")) {
    fetchUrl += "index.html";
  } else if (!path.endsWith(".html")) {
    // e.g. /blog -> /blog/index.html (if server redirects)
    // or /blog -> /blog (if checking file existence).
    // GitHub Pages usually handles /folder as /folder/index.html
    // But if we want to fetch it, we should probably append index.html
    // to be safe, unless we trust the server returns it for the dir.
    // Let's assume appending index.html for directories.
    // But how do we know if it's a directory?
    // Our specific routes:
    // / -> index.html
    // /pics/ -> pics/index.html
    // /blog/ -> blog/index.html
    // /blog/view.html -> blog/view.html

    // Simple router map for our known structure:
    if (path === "/" || path === "/index.html") fetchUrl = "/index.html";
    else if (path.startsWith("/pics")) fetchUrl = "/pics/index.html";
    else if (path.startsWith("/blog") && !path.includes("view.html")) fetchUrl = "/blog/index.html";
    else if (path.includes("view.html")) fetchUrl = "/blog/view.html";
  }

  // Fallback: if we are trying to fetch /pics/blog/ or similar weird paths due to relative link resolution failures in static server context (though URL object resolution should handle it).
  // Actually, the issue in verification might be that "Blog" link in pics/index.html is relative "../blog/"
  // If we are at /pics/, "../blog/" resolves to /blog/.
  // The verification error showed: http://localhost:8000/pics/blog/
  // This suggests the browser resolved it as /pics/blog/ ?
  // No, if href is "../blog/", from /pics/, it should be /blog/.
  // Unless /pics/ is treated as a file without trailing slash?
  // If we are at /pics (no slash), then .. is root.
  // If we are at /pics/ (slash), then .. is root.

  // Let's check strict equality for cleaner routing map
  if (path === "/pics" || path === "/pics/") fetchUrl = "/pics/index.html";
  if (path === "/blog" || path === "/blog/") fetchUrl = "/blog/index.html";

  try {
    const res = await fetch(fetchUrl);
    if (!res.ok) throw new Error(`Failed to load ${fetchUrl}: ${res.status}`);
    const html = await res.text();
    const parser = new DOMParser();
    const doc = parser.parseFromString(html, "text/html");

    // Swap Content
    const newContent = doc.getElementById("content");
    const oldContent = document.getElementById("content");

    if (newContent && oldContent) {
      oldContent.innerHTML = newContent.innerHTML;
      // Also update class on body if needed (e.g., different themes?)
      // Currently all use "crt".
      document.title = doc.title;

      // Re-run visuals
      initDecryptEffect();

      // Run Page Script
      runPageScript(path, search);
    } else {
      console.error("Content wrapper #content not found in fetched page or current page.");
      // Fallback: reload
      window.location.reload();
    }

  } catch (err) {
    console.error("Navigation error:", err);
  }
}

function runPageScript(path, search) {
  // Detect page type
  if (path.startsWith("/pics")) {
    loadPics();
  } else if (path.startsWith("/blog")) {
    if (path.includes("view.html") || search.includes("post=")) {
      loadPost();
    } else {
      loadBlogList();
    }
  } else {
    // Home page - nothing special dynamic unless we want to re-init something
  }
}

/* --- Page Logic: Home / General --- */
const circuitCanvas = document.getElementById("circuit");
const circuitCtx = circuitCanvas.getContext("2d");
let primary = getComputedStyle(document.documentElement).getPropertyValue("--primary-color");
let nodes = [];
const nodeCount = 60;
let cursorPos = { x: null, y: null };

function initCircuit() {
  if (!circuitCanvas) return;
  resize();
  window.addEventListener("resize", resize);
  drawCircuit();

  // Color update interval
  setInterval(updateColor, 5000);
}

function initGlobalListeners() {
  // Cursor
  const cursor = document.getElementById("cursor");
  document.addEventListener("mousemove", (e) => {
    if (cursor) {
      cursor.style.left = `${e.clientX}px`;
      cursor.style.top = `${e.clientY}px`;
    }
    cursorPos.x = e.clientX;
    cursorPos.y = e.clientY;

    // HUD Coords
    const hudCoords = document.getElementById("hud-coords");
    if (hudCoords) {
      hudCoords.innerText = `X: ${e.clientX.toString().padStart(4, '0')} Y: ${e.clientY.toString().padStart(4, '0')}`;
    }
  });

  document.addEventListener("click", () => {
    if (cursor) {
      cursor.classList.add("expand");
      setTimeout(() => cursor.classList.remove("expand"), 200);
    }
  });

  // HUD Timer
  const hudTimer = document.getElementById("hud-timer");
  const startTime = Date.now();
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

  // Countdown Timer (Header) - Check existence periodically or on load?
  // It's in header, which might be swapped. So we should check inside the interval.
  // Or re-init it. Let's keep global interval but check element existence.
  startCountdown();

  // Initial Decrypt
  initDecryptEffect();

  // Title Glitch
  const title = document.querySelector(".glitch");
  if (title) {
    setInterval(() => {
      title.classList.add("active");
      setTimeout(() => title.classList.remove("active"), 1000);
    }, 4000);
  }
}

function initNodes() {
  nodes = Array.from({ length: nodeCount }, () => ({
    x: Math.random() * circuitCanvas.width,
    y: Math.random() * circuitCanvas.height,
    vx: (Math.random() - 0.5) * 0.5,
    vy: (Math.random() - 0.5) * 0.5,
  }));
}

function resize() {
  if (!circuitCanvas) return;
  const w = document.documentElement.clientWidth;
  const h = document.documentElement.clientHeight;
  circuitCanvas.width = w;
  circuitCanvas.height = h;
  initNodes();
}

function drawCircuit() {
  if (!circuitCanvas) return;
  circuitCtx.fillStyle = "rgba(10, 10, 10, 0.1)";
  circuitCtx.fillRect(0, 0, circuitCanvas.width, circuitCanvas.height);

  for (const n of nodes) {
    n.x += n.vx;
    n.y += n.vy;
    if (n.x < 0 || n.x > circuitCanvas.width) n.vx *= -1;
    if (n.y < 0 || n.y > circuitCanvas.height) n.vy *= -1;

    circuitCtx.fillStyle = primary;
    if (document.body.classList.contains("special-mode")) {
      drawHeart(circuitCtx, n.x, n.y, 1); // Draw hearts
    } else {
      circuitCtx.beginPath();
      circuitCtx.arc(n.x, n.y, 2, 0, Math.PI * 2);
      circuitCtx.fill();
    }

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

function drawHeart(ctx, x, y, size) {
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(size, size);
  ctx.beginPath();
  ctx.moveTo(0, 0);
  ctx.bezierCurveTo(-5, -5, -10, 0, 0, 10);
  ctx.bezierCurveTo(10, 0, 5, -5, 0, 0);
  ctx.fill();
  ctx.restore();
}

function updateColor() {
  if (document.body.classList.contains("special-mode")) return;

  const hue = 110 + Math.floor(Math.random() * 40);
  primary = `hsl(${hue}, 70%, 50%)`;
  document.documentElement.style.setProperty("--primary-color", primary);
  document.documentElement.style.setProperty(
    "--glow-color",
    `hsla(${hue}, 70%, 50%, 0.75)`,
  );
}

function startCountdown() {
  // Target date: December 19, 2025 09:30:00 London Time (GMT)
  const targetDate = new Date("2025-12-19T09:30:00Z").getTime();

  // Initial check
  checkSurprise(targetDate);

  setInterval(() => {
    const timerElement = document.getElementById("countdown-timer");

    // Continuous check to catch the exact moment
    checkSurprise(targetDate);

    if (!timerElement) return;

    const now = new Date().getTime();
    const distance = targetDate - now;

    if (distance < 0) {
      timerElement.innerHTML = "THE WAIT IS OVER";
      timerElement.classList.add("glitch"); // Add glitch effect to the specific message
      return;
    }

    const days = Math.floor(distance / (1000 * 60 * 60 * 24));
    const hours = Math.floor((distance % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    const minutes = Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60));
    const seconds = Math.floor((distance % (1000 * 60)) / 1000);

    timerElement.innerHTML =
      `${days}:${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  }, 1000);
}

function checkSurprise(targetDate) {
  const now = Date.now();
  if (now >= targetDate) {
    if (!document.body.classList.contains("special-mode")) {
      document.body.classList.add("special-mode");
      // Force color update immediately
      primary = "#ff69b4";
      document.documentElement.style.setProperty("--primary-color", primary);
      document.documentElement.style.setProperty("--glow-color", "rgba(255, 105, 180, 0.75)");
    }
  }
}

/* --- Decrypt Effect --- */
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
      // Check if element is still in DOM
      if (!document.body.contains(this.element)) {
        clearInterval(interval);
        return;
      }

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

function initDecryptEffect(specificElement = null) {
  if (specificElement) {
    new DecryptEffect(specificElement);
  } else {
    document.querySelectorAll(".decrypt-effect").forEach((el) => {
      new DecryptEffect(el);
    });
  }
}

/* --- Page Logic: Pics --- */
async function loadPics() {
  const gallery = document.getElementById("gallery");
  if (!gallery) return;

  // Initialize Modal Listeners since they are part of the pics page structure
  initModal();

  try {
    // Use absolute path for robustness in SPA
    const res = await fetch("/pics/index.json");
    if (!res.ok) throw new Error("index");

    const data = await res.json();
    const folders = Array.isArray(data) ? data : data.albums;
    const baseUrl = data.base_url || "";

    folders.sort((a, b) => {
      const yearA = extractYear(a.name);
      const yearB = extractYear(b.name);
      if (isNaN(yearA) && isNaN(yearB)) return 0;
      if (isNaN(yearA)) return 1;
      if (isNaN(yearB)) return -1;
      return yearB - yearA;
    });

    gallery.innerHTML = ""; // Clear loading/placeholder

    for (const folder of folders) {
      const details = document.createElement("details");
      const summary = document.createElement("summary");
      summary.textContent = folder.name;
      details.appendChild(summary);
      const imagesDiv = document.createElement("div");
      imagesDiv.className = "album-images";
      details.appendChild(imagesDiv);
      gallery.appendChild(details);

      folder.images.forEach((file) => {
        const img = document.createElement("img");
        img.loading = "lazy";
        img.crossOrigin = "anonymous";

        let src = file;
        if (!file.startsWith("http")) {
          if (baseUrl) {
            src = `${baseUrl}/${file}`;
          } else {
            // Fallback for local relative paths
            src = `/pics/${folder.name}/${file}`;
          }
        }

        img.src = src;
        img.alt = file;
        img.addEventListener("click", () => openModal(img.src));
        imagesDiv.appendChild(img);

        // Attach ASCII effect
        attachAsciiEffect(img);
      });
    }
  } catch (err) {
    console.error(err);
    const p = document.createElement("p");
    p.textContent = "Failed to load pictures.";
    if (gallery) gallery.appendChild(p);
  }
}

function extractYear(name) {
  const match = name.match(/-(\d{4})$/);
  return match ? parseInt(match[1], 10) : NaN;
}

// Modal Logic
let modal, modalImg, closeBtn;

function initModal() {
  modal = document.getElementById("modal");
  modalImg = document.getElementById("modal-img");
  closeBtn = document.getElementById("close-modal");

  if (!modal) return;

  closeBtn.addEventListener("click", closeModal);

  modal.addEventListener("click", (e) => {
    if (e.target === modal) {
      closeModal();
    }
  });

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && modal.classList.contains("show")) {
      closeModal();
    }
  });
}

function openModal(src) {
  if (!modalImg) return;
  modalImg.src = src;
  modal.classList.add("show");
  setTimeout(() => {
    modal.classList.add("clear");
  }, 600);
}

function closeModal() {
  if (!modal) return;
  modal.classList.remove("show");
  modal.classList.remove("clear");
  setTimeout(() => {
    if (!modal.classList.contains("show")) {
      modalImg.src = "";
    }
  }, 300);
}

/* --- ASCII Effect --- */
function generateAscii(img, canvas) {
  const ctx = canvas.getContext("2d");
  const width = 100;
  const height = (img.height / img.width) * width;

  canvas.width = width;
  canvas.height = height;

  const tempCanvas = document.createElement('canvas');
  tempCanvas.width = width;
  tempCanvas.height = height;
  const tempCtx = tempCanvas.getContext('2d');
  tempCtx.drawImage(img, 0, 0, width, height);

  const imageData = tempCtx.getImageData(0, 0, width, height);
  const data = imageData.data;
  const chars = "@%#*+=-:. ";

  // Prepare overlay canvas
  canvas.width = img.width;
  canvas.height = img.height;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = "rgba(0, 0, 0, 0.9)";
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = "#00ff41";

  const colWidth = canvas.width / width;
  const rowHeight = canvas.height / height;

  ctx.font = `${colWidth * 1.5}px monospace`;

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

function attachAsciiEffect(imgElement) {
  const wrapper = document.createElement("div");
  wrapper.className = "ascii-container";
  imgElement.parentNode.insertBefore(wrapper, imgElement);
  wrapper.appendChild(imgElement);

  const canvas = document.createElement("canvas");
  canvas.className = "ascii-canvas";
  wrapper.appendChild(canvas);

  if (imgElement.complete) {
    generateAscii(imgElement, canvas);
  } else {
    imgElement.onload = () => generateAscii(imgElement, canvas);
  }
};

/* --- Page Logic: Blog List --- */
async function loadBlogList() {
  const list = document.getElementById("blog-list");
  if (!list) return;

  try {
    const res = await fetch("/blog/posts.json");
    if (!res.ok) throw new Error("Failed to load posts");
    const posts = await res.json();

    list.innerHTML = "";

    posts.forEach(post => {
      const li = document.createElement("li");
      // Use clean URL link, e.g., view.html?post=...
      // The router will handle navigation.
      li.innerHTML = `
              <span class="date">[${post.date}]</span>
              <a href="view.html?post=${post.file}">${post.title}</a>
            `;
      list.appendChild(li);
    });
  } catch (err) {
    list.innerHTML = "<li>Error loading transmission log. Connection failed.</li>";
    console.error(err);
  }
}

/* --- Page Logic: Blog Post View --- */
async function loadPost() {
  const params = new URLSearchParams(window.location.search);
  const postFile = params.get("post");

  const titleEl = document.getElementById("post-title");
  const metaEl = document.getElementById("post-meta");
  const contentEl = document.getElementById("post-content");

  if (!postFile) {
    if (titleEl) titleEl.innerText = "Error: No post specified";
    return;
  }

  try {
    const res = await fetch(`/blog/posts/${postFile}`);
    if (!res.ok) throw new Error("Post not found");
    const text = await res.text();

    const titleMatch = text.match(/^title:\s*(.*)$/m);
    const dateMatch = text.match(/^date:\s*(.*)$/m);
    const tagsMatch = text.match(/^tags:\s*(.*)$/m);

    const title = titleMatch ? titleMatch[1] : "Untitled";
    const date = dateMatch ? dateMatch[1] : "Unknown Date";
    const tags = tagsMatch ? tagsMatch[1] : "";

    document.title = `${title} - Aahan Aggarwal`;
    if (titleEl) {
      titleEl.innerHTML = `<span class="glitch">${title}</span>`;
      initDecryptEffect(titleEl);
    }

    if (metaEl) {
      metaEl.innerHTML = `<span>Date: ${date}</span> | <span>Tags: [${tags}]</span>`;
    }

    if (contentEl) {
      contentEl.innerHTML = parseMarkdown(text);
    }

  } catch (err) {
    if (titleEl) titleEl.innerText = "Error: Post not found";
    console.error(err);
  }
}

function parseMarkdown(text) {
  // Remove frontmatter
  text = text.replace(/^---\n[\s\S]*?\n---\n/, '');
  text = text.replace(/^# (.*$)/gim, '<h1>$1</h1>');
  text = text.replace(/^## (.*$)/gim, '<h2>$1</h2>');
  text = text.replace(/^### (.*$)/gim, '<h3>$1</h3>');
  text = text.replace(/^> (.*$)/gim, '<blockquote>$1</blockquote>');
  text = text.replace(/\*\*(.*)\*\*/gim, '<b>$1</b>');
  text = text.replace(/\*(.*)\*/gim, '<i>$1</i>');
  text = text.replace(/\[([^\]]+)\]\(([^)]+)\)/gim, '<a href="$2">$1</a>');
  text = text.replace(/```([\s\S]*?)```/gim, '<pre><code>$1</code></pre>');
  text = text.replace(/`([^`]+)`/gim, '<code>$1</code>');
  text = text.replace(/^\s*-\s(.*)/gim, '<ul><li>$1</li></ul>');
  text = text.replace(/<\/ul>\s*<ul>/gim, '');
  text = text.replace(/\n\n/gim, '</p><p>');
  if (!text.trim().startsWith('<')) {
    text = '<p>' + text + '</p>';
  }
  text = text.replace(/\n/gim, '<br />');
  text = text.replace(/<p><\/p>/gim, '');

  return text.trim();
};
