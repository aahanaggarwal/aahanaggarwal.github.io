document.addEventListener("DOMContentLoaded", () => {
  window.HAS_SPA_ROUTER = true;

  // Initialize critical components immediately
  initCircuit();
  initGlobalListeners();
  initRouter();

  // Initialize Wasm (Graph) asynchronously
  initWasm().catch(err => console.error("Wasm init failed:", err));
});

function initRouter() {
  document.addEventListener("click", (e) => {
    const link = e.target.closest("a");
    if (!link) return;

    const href = link.getAttribute("href");
    const url = new URL(link.href);

    if (url.origin !== window.location.origin || href.startsWith("#")) {
      return;
    }
    if (link.getAttribute("target") === "_blank") return;

    e.preventDefault();

    let cleanPath = url.pathname;
    if (cleanPath.endsWith("/index.html")) {
      cleanPath = cleanPath.replace("/index.html", "/");
    } else if (cleanPath.endsWith("index.html")) {
      cleanPath = cleanPath.replace("index.html", "");
    }

    const cleanUrl = cleanPath + url.search + url.hash;

    window.history.pushState({}, "", cleanUrl);
    handleLocation();
  });

  window.addEventListener("popstate", handleLocation);

  handleLocation(true);
}

async function handleLocation(isInitial = false) {
  const path = window.location.pathname;
  const search = window.location.search;

  if (isInitial) {
    runPageScript(path, search);
    return;
  }
  let fetchUrl = path;

  if (path.endsWith("/")) {
    fetchUrl += "index.html";
  } else if (!path.endsWith(".html")) {
    if (path === "/" || path === "/index.html") fetchUrl = "/index.html";
    else if (path.startsWith("/pics")) fetchUrl = "/pics/index.html";
    else if (path.startsWith("/blog") && !path.includes("view.html")) fetchUrl = "/blog/index.html";
    else if (path.includes("view.html")) fetchUrl = "/blog/view.html";
  }

  if (path === "/pics" || path === "/pics/") fetchUrl = "/pics/index.html";
  if (path === "/blog" || path === "/blog/") fetchUrl = "/blog/index.html";
  if (path === "/pics" || path === "/pics/") fetchUrl = "/pics/index.html";
  if (path === "/blog" || path === "/blog/") fetchUrl = "/blog/index.html";
  if (path === "/graph" || path === "/graph/") fetchUrl = "/graph/index.html";
  if (path === "/sand" || path === "/sand/") fetchUrl = "/sand/index.html";
  if (path === "/pong" || path === "/pong/") fetchUrl = "/pong/index.html";

  let preFetchPromise = null;
  if (path.includes("view.html")) {
    const params = new URLSearchParams(search);
    const postFile = params.get("post");
    if (postFile) {
      preFetchPromise = fetch(`/blog/posts/${postFile}`)
        .then(res => {
          if (!res.ok) throw new Error("Post not found");
          return res.text();
        })
        .catch(err => {
          console.error("Pre-fetch failed:", err);
          return null;
        });
      window._preFetchedPost = preFetchPromise;
    }
  }

  try {
    const res = await fetch(fetchUrl);
    if (!res.ok) throw new Error(`Failed to load ${fetchUrl}: ${res.status}`);
    const html = await res.text();
    const parser = new DOMParser();
    const doc = parser.parseFromString(html, "text/html");

    const newContent = doc.getElementById("content");
    const oldContent = document.getElementById("content");

    if (newContent && oldContent) {
      oldContent.className = newContent.className;
      oldContent.setAttribute("style", newContent.getAttribute("style") || "");
      oldContent.innerHTML = newContent.innerHTML;
      document.title = doc.title;

      initDecryptEffect();

      updateHudTimer();
      updateCountdown();

      runPageScript(path, search);
    } else {
      console.error("Content wrapper #content not found in fetched page or current page.");
      window.location.reload();
    }

  } catch (err) {
    console.error("Navigation error:", err);
  }
}

function runPageScript(path, search) {
  if (path.startsWith("/pics")) {
    loadPics();
  } else if (path.startsWith("/blog")) {
    if (path.includes("view.html") || search.includes("post=")) {
      loadPost();
    } else {
      loadBlogList();
    }
  } else if (path.startsWith("/graph")) {
    loadGraph();
  } else if (path.startsWith("/pong")) {
    import('./pong/main.js').then(module => {
      module.run();
    });
  } else if (path.startsWith("/sand")) {
    import('./sand/main.js').then(module => {
      module.run();
    });
  } else {
  }
}

import initWasm, { plot_equation } from '/graph/pkg/graph_wasm.js';
const startTime = Date.now();
const targetDate = new Date("2026-04-02T09:30:00Z").getTime();
const circuitCanvas = document.getElementById("circuit");
const circuitCtx = circuitCanvas.getContext("2d");
let primary = getComputedStyle(document.documentElement).getPropertyValue("--primary-color");
let nodes = [];
const nodeCount = 60;
let cursorPos = { x: null, y: null };

function updateHudTimer() {
  const hudTimer = document.getElementById("hud-timer");
  if (hudTimer) {
    const elapsed = Date.now() - startTime;
    const date = new Date(elapsed);
    const h = date.getUTCHours().toString().padStart(2, '0');
    const m = date.getUTCMinutes().toString().padStart(2, '0');
    const s = date.getUTCSeconds().toString().padStart(2, '0');
    hudTimer.innerText = `SESSION: ${h}:${m}:${s}`;
  }
}

function updateCountdown() {
  const timerElement = document.getElementById("countdown-timer");

  checkSurprise(targetDate);

  if (!timerElement) return;

  const now = new Date().getTime();
  const distance = targetDate - now;

  if (distance < 0) {
    timerElement.innerHTML = "THE WAIT IS OVER";
    timerElement.classList.add("glitch");
    return;
  }

  const days = Math.floor(distance / (1000 * 60 * 60 * 24));
  const hours = Math.floor((distance % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
  const minutes = Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60));
  const seconds = Math.floor((distance % (1000 * 60)) / 1000);

  timerElement.innerHTML =
    `${days}:${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
}

function initCircuit() {
  if (!circuitCanvas) return;
  resize();
  window.addEventListener("resize", resize);
  drawCircuit();

  setInterval(updateColor, 5000);
}

function initGlobalListeners() {
  const cursor = document.getElementById("cursor");
  document.addEventListener("mousemove", (e) => {
    if (cursor) {
      cursor.style.transform = `translate3d(${e.clientX}px, ${e.clientY}px, 0)`;
      cursor.style.top = '';
      cursor.style.left = '';
    }
    cursorPos.x = e.clientX;
    cursorPos.y = e.clientY;

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


  updateHudTimer();
  setInterval(updateHudTimer, 1000);

  startCountdown();
  initDecryptEffect();

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
      drawHeart(circuitCtx, n.x, n.y, 1);
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
  checkSurprise(targetDate);

  updateCountdown();
  setInterval(updateCountdown, 1000);
}

function checkSurprise(targetDate) {
  const now = Date.now();
  const endDate = new Date("2025-12-28T00:00:00Z").getTime();

  if (now >= targetDate && now < endDate) {
    if (!document.body.classList.contains("special-mode")) {
      document.body.classList.add("special-mode");
      primary = "#ff69b4";
      document.documentElement.style.setProperty("--primary-color", primary);
      document.documentElement.style.setProperty("--glow-color", "rgba(255, 105, 180, 0.75)");
    }
  } else {
    if (document.body.classList.contains("special-mode")) {
      document.body.classList.remove("special-mode");
      document.documentElement.style.removeProperty("--primary-color");
      document.documentElement.style.removeProperty("--glow-color");
      updateColor();
    }
  }
}

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

      iterations += 1 / 4;
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

async function loadPics() {
  const gallery = document.getElementById("gallery");
  if (!gallery) return;
  initModal();

  try {
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

    gallery.innerHTML = "";

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
            src = `/pics/${folder.name}/${file}`;
          }
        }

        img.src = src;
        img.alt = file;
        img.addEventListener("click", () => openModal(img.src));
        imagesDiv.appendChild(img);
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

function generateAscii(img, canvas) {
  const ctx = canvas.getContext("2d");
  const width = 100;
  const renderedRatio = img.width / img.height;
  const height = width / renderedRatio;

  canvas.width = width;
  canvas.height = height;

  const tempCanvas = document.createElement('canvas');
  tempCanvas.width = width;
  tempCanvas.height = height;
  const tempCtx = tempCanvas.getContext('2d');

  const nw = img.naturalWidth;
  const nh = img.naturalHeight;
  let sx = 0, sy = 0, sw = nw, sh = nh;
  if (nw / nh > renderedRatio) {
    sw = nh * renderedRatio;
    sx = (nw - sw) / 2;
  } else {
    sh = nw / renderedRatio;
    sy = (nh - sh) / 2;
  }

  tempCtx.drawImage(img, sx, sy, sw, sh, 0, 0, width, height);

  const imageData = tempCtx.getImageData(0, 0, width, height);
  const data = imageData.data;
  const chars = "@%#*+=-:. ";

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
    let text;
    if (window._preFetchedPost) {
      text = await window._preFetchedPost;
      window._preFetchedPost = null;
    }
    if (!text) {
      const res = await fetch(`/blog/posts/${postFile}`);
      if (!res.ok) throw new Error("Post not found");
      text = await res.text();
    }

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

let graphCanvas, graphCtx;
let equations = [];
let variables = {};
let scale = 40;
let offsetX = 0, offsetY = 0;
let isDragging = false;
let isInteracting = false;
let lastMouseX, lastMouseY;

function loadGraph() {
  graphCanvas = document.getElementById("graph-canvas");
  if (!graphCanvas) return;
  graphCtx = graphCanvas.getContext("2d");

  startGraphRenderLoop();

  resizeGraph();
  window.addEventListener("resize", resizeGraph);
  let interactionTimeout;
  const startInteraction = () => {
    isInteracting = true;
    clearTimeout(interactionTimeout);
    drawGraph();
  };
  const endInteraction = () => {
    clearTimeout(interactionTimeout);
    interactionTimeout = setTimeout(() => {
      isInteracting = false;
      drawGraph();
    }, 500);
  };

  graphCanvas.addEventListener("mousedown", (e) => {
    isDragging = true;
    lastMouseX = e.clientX;
    lastMouseY = e.clientY;
    startInteraction();
  });

  window.addEventListener("mousemove", (e) => {
    if (isDragging) {
      const dx = e.clientX - lastMouseX;
      const dy = e.clientY - lastMouseY;
      offsetX += dx;
      offsetY += dy;
      lastMouseX = e.clientX;
      lastMouseY = e.clientY;
      startInteraction();
    }
  });

  window.addEventListener("mouseup", () => {
    isDragging = false;
    endInteraction();
  });

  const cursor = document.getElementById("cursor");
  graphCanvas.addEventListener("mouseenter", () => {
    if (cursor) cursor.classList.add("plus-mode");
  });
  graphCanvas.addEventListener("mouseleave", () => {
    if (cursor) cursor.classList.remove("plus-mode");
  });

  graphCanvas.addEventListener("wheel", (e) => {
    e.preventDefault();
    startInteraction();
    const zoomIntensity = 0.05;
    const scroll = e.deltaY < 0 ? 1 : -1;
    const zoom = Math.exp(scroll * zoomIntensity);
    const rect = graphCanvas.getBoundingClientRect();
    const mouseX = e.clientX - rect.left;
    const mouseY = e.clientY - rect.top;

    const w = graphCanvas.width / (window.devicePixelRatio || 1);
    const h = graphCanvas.height / (window.devicePixelRatio || 1);

    const cx = w / 2 + offsetX;
    const cy = h / 2 + offsetY;

    const mouseWorldX = (mouseX - cx) / scale;
    const mouseWorldY = (mouseY - cy) / scale;

    scale *= zoom;

    offsetX = mouseX - (mouseWorldX * scale) - (w / 2);
    offsetY = mouseY - (mouseWorldY * scale) - (h / 2);
    endInteraction();
  });

  graphCanvas.addEventListener("dblclick", () => {
    offsetX = 0;
    offsetY = 0;
    scale = 40;
    drawGraph();
  });

  const addBtn = document.getElementById("add-equation");
  const eqList = document.getElementById("equation-list");

  if (addBtn && eqList) {
    eqList.innerHTML = "";
    if (equations.length === 0) equations.push("");
    equations.forEach(eq => addEquationInput(eqList, eq));
    addBtn.onclick = () => {
      equations.push("");
      addEquationInput(eqList, "");
    };
  }

  drawGraph();
}

function addEquationInput(container, value) {
  const group = document.createElement("div");
  group.className = "equation-input-group";
  group.innerHTML = `
    <span class="prompt">></span>
    <input type="text" class="equation-input" value="${value}" />
    <button class="btn-delete" title="Delete equation">X</button>
  `;
  container.appendChild(group);

  const input = group.querySelector("input");
  input.addEventListener("input", (e) => {
    const index = Array.from(container.children).indexOf(group);
    equations[index] = e.target.value;
    drawGraph();
  });
  input.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      document.getElementById("add-equation").click();
    }
  });

  const deleteBtn = group.querySelector(".btn-delete");
  deleteBtn.addEventListener("click", () => {
    const index = Array.from(container.children).indexOf(group);
    equations.splice(index, 1);
    container.removeChild(group);
    drawGraph();
  });

  if (value === "") input.focus();
}

function resizeGraph() {
  if (!graphCanvas) return;
  const container = document.getElementById("graph-container");
  if (container) {
    const dpr = window.devicePixelRatio || 1;
    const rect = container.getBoundingClientRect();

    graphCanvas.width = rect.width * dpr;
    graphCanvas.height = rect.height * dpr;

    graphCanvas.style.width = `${rect.width}px`;
    graphCanvas.style.height = `${rect.height}px`;

    drawGraph();
  }
}

let graphRenderLoopId;
let graphNeedsUpdate = false;

function startGraphRenderLoop() {
  if (graphRenderLoopId) cancelAnimationFrame(graphRenderLoopId);

  const loop = () => {
    if (graphNeedsUpdate) {
      drawGraphLogic();
      graphNeedsUpdate = false;
    }
    graphRenderLoopId = requestAnimationFrame(loop);
  };
  graphRenderLoopId = requestAnimationFrame(loop);
}


function drawGraph() {
  graphNeedsUpdate = true;
}

function drawGraphLogic() {
  if (!graphCtx || !graphCanvas) return;
  const w = graphCanvas.width;
  const h = graphCanvas.height;
  const dpr = window.devicePixelRatio || 1;
  const cx = (w / 2 + offsetX * dpr);
  const cy = (h / 2 + offsetY * dpr);
  const physicalScale = scale * dpr;

  const step = isInteracting ? 12 : 3;

  graphCtx.fillStyle = "#0a0a0a";
  graphCtx.fillRect(0, 0, w, h);

  graphCtx.lineWidth = 1 * dpr;
  graphCtx.strokeStyle = "rgba(0, 255, 65, 0.2)";

  const startCol = Math.floor(-cx / physicalScale);
  const endCol = Math.floor((w - cx) / physicalScale) + 1;
  const startRow = Math.floor(-cy / physicalScale);
  const endRow = Math.floor((h - cy) / physicalScale) + 1;

  graphCtx.beginPath();
  for (let c = startCol; c <= endCol; c++) {
    const x = cx + c * physicalScale;
    graphCtx.moveTo(x, 0);
    graphCtx.lineTo(x, h);
  }
  for (let r = startRow; r <= endRow; r++) {
    const y = cy + r * physicalScale;
    graphCtx.moveTo(0, y);
    graphCtx.lineTo(w, y);
  }
  graphCtx.stroke();

  graphCtx.lineWidth = 2 * dpr;
  graphCtx.strokeStyle = "rgba(0, 255, 65, 0.8)";
  graphCtx.beginPath();
  graphCtx.moveTo(0, cy);
  graphCtx.lineTo(w, cy);
  graphCtx.moveTo(cx, 0);
  graphCtx.lineTo(cx, h);
  graphCtx.stroke();

  const collisionBuffer = new Int8Array(w * h);

  const allVars = new Set();
  equations.forEach(eq => {
    extractVariables(eq).forEach(v => allVars.add(v));
  });

  Object.keys(variables).forEach(v => {
    if (!allVars.has(v)) delete variables[v];
  });
  allVars.forEach(v => {
    if (variables[v] === undefined) variables[v] = 1.0;
  });

  updateVariableControls();

  const varNames = Object.keys(variables);
  const varValues = Object.values(variables);

  graphCtx.lineWidth = 2 * dpr;
  equations.forEach((eq, index) => {
    if (!eq.trim()) return;

    try {
      plotEquation(eq, cx, cy, w, h, index + 1, collisionBuffer, varNames, varValues, step, physicalScale);
    } catch (e) {
      console.error(`Error plotting equation ${index + 1}:`, e);
    }
  });

  if (pendingIntersections.length > 0) {
    graphCtx.save();
    graphCtx.shadowColor = "#fff";
    graphCtx.shadowBlur = 15;
    graphCtx.fillStyle = "#fff";
    for (const p of pendingIntersections) {
      graphCtx.beginPath();
      graphCtx.arc(p.x, p.y, 4, 0, Math.PI * 2);
      graphCtx.fill();
    }
    graphCtx.restore();
  }
  pendingIntersections = [];
}

function plotEquation(eqStr, cx, cy, w, h, eqId, collisionBuffer, varNames, varValues, step, pScale) {
  try {
    let processedEq = eqStr;
    varNames.forEach((name, i) => {
      const val = varValues[i];
      const re = new RegExp(`\\b${name}\\b`, 'g');
      processedEq = processedEq.replace(re, `(${val})`);
    });

    const result = plot_equation(
      processedEq,
      w,
      h,
      Number(pScale),
      Number(cx),
      Number(cy),
      Number(step),
      collisionBuffer,
      eqId,
      [],
      new Float64Array([])
    );

    const lines = result.get_lines();
    graphCtx.beginPath();
    graphCtx.strokeStyle = "#00ff41";
    for (let i = 0; i < lines.length; i += 4) {
      graphCtx.moveTo(lines[i], lines[i + 1]);
      graphCtx.lineTo(lines[i + 2], lines[i + 3]);
    }
    graphCtx.stroke();

    const intersections = result.get_intersections();
    for (let i = 0; i < intersections.length; i += 2) {
      drawIntersection(intersections[i], intersections[i + 1]);
    }

  } catch (e) {
    console.warn("Wasm plot error:", e);
  }
}

function extractVariables(eq) {
  const tokens = eq.match(/[a-zA-Z]+/g) || [];
  const knowns = new Set([
    "x", "y",
    "sin", "cos", "tan", "asin", "acos", "atan", "sinh", "cosh", "tanh",
    "log", "ln", "exp", "sqrt", "abs", "floor", "ceil", "round", "sign",
    "pi", "e", "max", "min", "pow"
  ]);

  const vars = [];
  tokens.forEach(t => {
    const low = t.toLowerCase();
    if (!knowns.has(low)) {
      vars.push(t);
    }
  });
  return vars;
}

function updateVariableControls() {
  const container = document.getElementById("variable-list");
  if (!container) return;

  const currentKeys = Object.keys(variables).sort();

  const existingGroups = Array.from(container.children);
  const existingKeys = existingGroups.map(el => el.dataset.var).sort();

  if (JSON.stringify(currentKeys) === JSON.stringify(existingKeys)) {
    return;
  }

  container.innerHTML = "";
  currentKeys.forEach(key => {
    const group = document.createElement("div");
    group.className = "variable-control-group";
    group.dataset.var = key;

    group.innerHTML = `
      <span class="var-name">${key} = </span>
      <input type="range" class="var-slider" min="-10" max="10" step="0.1" value="${variables[key]}">
      <span class="var-val">${variables[key]}</span>
    `;

    const slider = group.querySelector(".var-slider");
    const label = group.querySelector(".var-val");

    slider.addEventListener("input", (e) => {
      const val = parseFloat(e.target.value);
      variables[key] = val;
      label.innerText = val;
      drawGraph();
    });

    container.appendChild(group);
  });
}


let pendingIntersections = [];

function drawIntersection(x, y) {
  pendingIntersections.push({ x, y });
}
