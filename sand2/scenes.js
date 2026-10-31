// Scene geometry is input data. The generated Lean core handles its evolution.
export function createScene(name, cells, width, height) {
  cells.fill(0);
  const set = (x, y, m) => {
    x = Math.round(x); y = Math.round(y);
    if (x > 0 && x < width - 1 && y > 0 && y < height - 1) cells[y * width + x] = m;
  };
  const rect = (x, y, w, h, m) => {
    for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) set(xx, yy, m);
  };
  const ellipse = (cx, cy, rx, ry, m) => {
    for (let y = -ry; y <= ry; y++) for (let x = -rx; x <= rx; x++) {
      if (x * x / (rx * rx) + y * y / (ry * ry) <= 1) set(cx + x, cy + y, m);
    }
  };
  const line = (ax, ay, bx, by, m, thickness = 1) => {
    const steps = Math.ceil(Math.hypot(bx - ax, by - ay));
    for (let i = 0; i <= steps; i++) rect(Math.round(ax + (bx - ax) * i / steps), Math.round(ay + (by - ay) * i / steps), thickness, thickness, m);
  };
  const tree = (x, y, size = 1) => {
    rect(x - 1, y - 18 * size, 3, 19 * size, 4);
    line(x, y - 11 * size, x - 6 * size, y - 18 * size, 4, 2);
    line(x, y - 14 * size, x + 7 * size, y - 20 * size, 4, 2);
    ellipse(x - 6 * size, y - 21 * size, 9 * size, 6 * size, 10);
    ellipse(x + 6 * size, y - 23 * size, 10 * size, 7 * size, 10);
    ellipse(x, y - 28 * size, 9 * size, 7 * size, 10);
  };
  if (name === 'terrarium') {
    for (let x = 1; x < width - 1; x++) {
      const ground = Math.round(138 + 8 * Math.sin(x * .027) + 3 * Math.sin(x * .09));
      for (let y = ground; y < height - 1; y++) set(x, y, y > 154 ? 3 : 1);
      if (x > 145) for (let y = 137; y < ground; y++) set(x, y, 2);
      if (x < 112 && x % 3 !== 0) rect(x, ground - 1 - x % 4, 1, 2 + x % 4, 10);
    }
    // A stone arch and a wooded island above a shallow pool.
    for (let x = 28; x < 126; x++) {
      const u = (x - 77) / 49;
      const top = 109 - 22 * Math.sqrt(Math.max(0, 1 - u * u));
      const bottom = top + 5 + Math.abs(u) * 13;
      for (let y = top; y < bottom; y++) set(x, y, 3);
      if (x > 43 && x < 109) rect(x, Math.floor(top) - 2, 1, 3, 10);
    }
    tree(65, 87, 1); tree(93, 89, .6);
    tree(27, 143, .65);
    line(141, 67, 187, 71, 3, 3);
    ellipse(161, 67, 18, 3, 10);
    tree(170, 68, .7);
    ellipse(145, 48, 4, 9, 2);
    ellipse(143, 107, 5, 7, 2);
    ellipse(215, 146, 11, 5, 3);
    rect(213, 130, 2, 17, 10); rect(221, 136, 2, 11, 10);
    ellipse(44, 115, 9, 5, 1);
  } else if (name === 'volcano') {
    rect(1, 147, width - 2, 12, 1);
    rect(1, 155, width - 2, 4, 3);
    for (let y = 83; y < 148; y++) {
      const half = 10 + (y - 83) * .82;
      for (let x = 174 - half; x <= 174 + half; x++) set(x, y, 3);
      rect(167, y, 14, 1, 9);
    }
    ellipse(174, 72, 9, 10, 9);
    for (let x = 10; x < 106; x++) {
      const ground = 143 + Math.sin(x * .06) * 4;
      for (let y = 133; y < ground; y++) set(x, y, 2);
    }
    tree(84, 145, .9); tree(41, 147, .65);
    ellipse(120, 120, 7, 5, 1);
    rect(225, 137, 17, 10, 11);
  } else if (name === 'hourglass') {
    const left = 65, right = 191, neckLeft = 124, neckRight = 132;
    line(left, 17, right, 17, 13, 2);
    line(left, 18, left, 28, 13, 2); line(right, 18, right, 28, 13, 2);
    line(left, 28, neckLeft, 78, 13, 2); line(right, 28, neckRight, 78, 13, 2);
    line(neckLeft, 78, neckLeft, 86, 13, 2); line(neckRight, 78, neckRight, 86, 13, 2);
    line(neckLeft, 86, left, 137, 13, 2); line(neckRight, 86, right, 137, 13, 2);
    line(left, 137, left, 145, 13, 2); line(right, 137, right, 145, 13, 2);
    line(left, 145, right, 145, 13, 2);
    for (let y = 30; y < 76; y++) {
      const inset = (y - 28) * 1.18;
      for (let x = left + inset + 4; x < right - inset - 2; x++) set(x, y, 1);
    }
    rect(53, 14, 152, 3, 4); rect(53, 148, 152, 3, 4);
  }
}
