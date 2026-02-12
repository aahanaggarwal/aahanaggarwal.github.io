use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub struct TronGame {
    width: u32,
    height: u32,
    grid: Vec<u8>, // 0=empty, 1=p1 trail, 2=p2 trail
    p1_x: u32,
    p1_y: u32,
    p1_dir: u8, // 0=up, 1=right, 2=down, 3=left
    p2_x: u32,
    p2_y: u32,
    p2_dir: u8,
    p1_alive: bool,
    p2_alive: bool,
    game_over: bool,
    winner: u8, // 0=draw, 1=p1, 2=p2
    tick_count: u32,
}

fn advance(x: u32, y: u32, dir: u8) -> (i32, i32) {
    match dir {
        0 => (x as i32, y as i32 - 1),     // up
        1 => (x as i32 + 1, y as i32),      // right
        2 => (x as i32, y as i32 + 1),      // down
        3 => (x as i32 - 1, y as i32),      // left
        _ => (x as i32, y as i32),
    }
}

#[wasm_bindgen]
impl TronGame {
    pub fn new(width: u32, height: u32) -> TronGame {
        let grid = vec![0u8; (width * height) as usize];
        TronGame {
            width,
            height,
            grid,
            p1_x: width / 4,
            p1_y: height / 2,
            p1_dir: 1, // right
            p2_x: 3 * width / 4,
            p2_y: height / 2,
            p2_dir: 3, // left
            p1_alive: true,
            p2_alive: true,
            game_over: false,
            winner: 0,
            tick_count: 0,
        }
    }

    pub fn tick(&mut self) {
        if self.game_over {
            return;
        }

        // Mark current positions as trails before moving
        if self.p1_alive {
            let idx = (self.p1_y * self.width + self.p1_x) as usize;
            self.grid[idx] = 1;
        }
        if self.p2_alive {
            let idx = (self.p2_y * self.width + self.p2_x) as usize;
            self.grid[idx] = 2;
        }

        // Compute new positions
        let (np1x, np1y) = if self.p1_alive {
            advance(self.p1_x, self.p1_y, self.p1_dir)
        } else {
            (self.p1_x as i32, self.p1_y as i32)
        };
        let (np2x, np2y) = if self.p2_alive {
            advance(self.p2_x, self.p2_y, self.p2_dir)
        } else {
            (self.p2_x as i32, self.p2_y as i32)
        };

        // Check wall collisions
        let p1_wall = self.p1_alive
            && (np1x < 0 || np1y < 0 || np1x >= self.width as i32 || np1y >= self.height as i32);
        let p2_wall = self.p2_alive
            && (np2x < 0 || np2y < 0 || np2x >= self.width as i32 || np2y >= self.height as i32);

        // Check trail collisions (against grid with trails already written)
        let p1_trail = self.p1_alive
            && !p1_wall
            && self.grid[(np1y as u32 * self.width + np1x as u32) as usize] != 0;
        let p2_trail = self.p2_alive
            && !p2_wall
            && self.grid[(np2y as u32 * self.width + np2x as u32) as usize] != 0;

        // Head-to-head collision
        let head_on =
            self.p1_alive && self.p2_alive && !p1_wall && !p2_wall && np1x == np2x && np1y == np2y;

        let p1_dead = self.p1_alive && (p1_wall || p1_trail || head_on);
        let p2_dead = self.p2_alive && (p2_wall || p2_trail || head_on);

        // Update positions for surviving players
        if self.p1_alive && !p1_wall {
            self.p1_x = np1x as u32;
            self.p1_y = np1y as u32;
        }
        if self.p2_alive && !p2_wall {
            self.p2_x = np2x as u32;
            self.p2_y = np2y as u32;
        }

        // Apply deaths
        if p1_dead {
            self.p1_alive = false;
        }
        if p2_dead {
            self.p2_alive = false;
        }

        if p1_dead || p2_dead {
            self.game_over = true;
            self.winner = match (p1_dead, p2_dead) {
                (true, true) => 0,   // draw
                (true, false) => 2,  // p2 wins
                (false, true) => 1,  // p1 wins
                (false, false) => 0, // shouldn't happen
            };
        }

        self.tick_count += 1;
    }

    pub fn set_direction(&mut self, player: u8, dir: u8) {
        if dir > 3 {
            return;
        }
        let current = if player == 0 {
            self.p1_dir
        } else {
            self.p2_dir
        };
        // Prevent 180-degree reversal: opposite pairs are 0↔2, 1↔3
        if (dir + 2) % 4 == current {
            return;
        }
        if player == 0 {
            self.p1_dir = dir;
        } else {
            self.p2_dir = dir;
        }
    }

    pub fn grid_ptr(&self) -> *const u8 {
        self.grid.as_ptr()
    }

    pub fn width(&self) -> u32 {
        self.width
    }

    pub fn height(&self) -> u32 {
        self.height
    }

    pub fn p1_x(&self) -> u32 {
        self.p1_x
    }

    pub fn p1_y(&self) -> u32 {
        self.p1_y
    }

    pub fn p1_dir(&self) -> u8 {
        self.p1_dir
    }

    pub fn p2_x(&self) -> u32 {
        self.p2_x
    }

    pub fn p2_y(&self) -> u32 {
        self.p2_y
    }

    pub fn p2_dir(&self) -> u8 {
        self.p2_dir
    }

    pub fn p1_alive(&self) -> bool {
        self.p1_alive
    }

    pub fn p2_alive(&self) -> bool {
        self.p2_alive
    }

    pub fn is_game_over(&self) -> bool {
        self.game_over
    }

    pub fn winner(&self) -> u8 {
        self.winner
    }

    pub fn tick_count(&self) -> u32 {
        self.tick_count
    }

    pub fn reset(&mut self) {
        self.grid.fill(0);
        self.p1_x = self.width / 4;
        self.p1_y = self.height / 2;
        self.p1_dir = 1;
        self.p2_x = 3 * self.width / 4;
        self.p2_y = self.height / 2;
        self.p2_dir = 3;
        self.p1_alive = true;
        self.p2_alive = true;
        self.game_over = false;
        self.winner = 0;
        self.tick_count = 0;
    }

    pub fn checksum(&self) -> u32 {
        let mut hash: u32 = 0;
        for (i, &cell) in self.grid.iter().enumerate() {
            if cell != 0 {
                hash ^= (cell as u32).wrapping_mul(i as u32).wrapping_add(i as u32);
            }
        }
        hash ^= self.p1_x.wrapping_mul(31);
        hash ^= self.p1_y.wrapping_mul(37);
        hash ^= self.p2_x.wrapping_mul(41);
        hash ^= self.p2_y.wrapping_mul(43);
        hash ^= (self.p1_dir as u32) << 16;
        hash ^= (self.p2_dir as u32) << 20;
        hash
    }

    pub fn serialize_state(&self) -> Vec<u8> {
        let grid_len = self.grid.len();
        let mut data = Vec::with_capacity(grid_len + 20);
        data.extend_from_slice(&self.grid);
        data.extend_from_slice(&self.p1_x.to_le_bytes());
        data.extend_from_slice(&self.p1_y.to_le_bytes());
        data.push(self.p1_dir);
        data.extend_from_slice(&self.p2_x.to_le_bytes());
        data.extend_from_slice(&self.p2_y.to_le_bytes());
        data.push(self.p2_dir);
        data.push(self.p1_alive as u8);
        data.push(self.p2_alive as u8);
        data.push(self.game_over as u8);
        data.push(self.winner);
        data.extend_from_slice(&self.tick_count.to_le_bytes());
        data
    }

    pub fn load_state(&mut self, data: &[u8]) {
        let grid_len = (self.width * self.height) as usize;
        if data.len() < grid_len + 20 {
            return;
        }
        self.grid.copy_from_slice(&data[..grid_len]);
        let mut off = grid_len;
        self.p1_x = u32::from_le_bytes([data[off], data[off + 1], data[off + 2], data[off + 3]]);
        off += 4;
        self.p1_y = u32::from_le_bytes([data[off], data[off + 1], data[off + 2], data[off + 3]]);
        off += 4;
        self.p1_dir = data[off];
        off += 1;
        self.p2_x = u32::from_le_bytes([data[off], data[off + 1], data[off + 2], data[off + 3]]);
        off += 4;
        self.p2_y = u32::from_le_bytes([data[off], data[off + 1], data[off + 2], data[off + 3]]);
        off += 4;
        self.p2_dir = data[off];
        off += 1;
        self.p1_alive = data[off] != 0;
        off += 1;
        self.p2_alive = data[off] != 0;
        off += 1;
        self.game_over = data[off] != 0;
        off += 1;
        self.winner = data[off];
        off += 1;
        self.tick_count =
            u32::from_le_bytes([data[off], data[off + 1], data[off + 2], data[off + 3]]);
    }
}
