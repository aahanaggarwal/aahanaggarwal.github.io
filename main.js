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
(function() {
  const timerElement = document.getElementById("countdown-timer");
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
