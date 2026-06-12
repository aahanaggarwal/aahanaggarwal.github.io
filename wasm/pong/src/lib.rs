use std::f64::consts::PI;
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = Math)]
    fn random() -> f64;
}

// Modifier bits ("protocols") that stack as the streak climbs.
pub const MOD_SPLIT: u32 = 1; // second ball
pub const MOD_SHRINK: u32 = 2; // smaller player paddle
pub const MOD_GRAVITY: u32 = 4; // ball arcs downward
pub const MOD_PHANTOM: u32 = 8; // ball blinks in and out
pub const MOD_TURBO: u32 = 16; // faster serves, higher cap
pub const MOD_MIRROR: u32 = 32; // controls inverted
pub const MOD_WRAP: u32 = 64; // top/bottom wrap around
pub const MOD_DRUNK: u32 = 128; // ball wobbles
pub const MOD_SNIPER: u32 = 256; // AI aims perfectly
pub const MOD_JUGGERNAUT: u32 = 512; // AI paddle grows
pub const MOD_BLACKOUT: u32 = 1024; // darkness outside ball light
pub const MOD_CURVE: u32 = 2048; // AI returns carry heavy spin
pub const MOD_TELEPORT: u32 = 4096; // ball randomly blinks vertically
pub const MOD_SHIELD: u32 = 8192; // one-time save wall (a mercy!)
pub const MOD_GIANT: u32 = 16384; // your paddle grows (also a mercy)

const ALL_MODS: [u32; 15] = [
    MOD_SPLIT,
    MOD_SHRINK,
    MOD_GRAVITY,
    MOD_PHANTOM,
    MOD_TURBO,
    MOD_MIRROR,
    MOD_WRAP,
    MOD_DRUNK,
    MOD_SNIPER,
    MOD_JUGGERNAUT,
    MOD_BLACKOUT,
    MOD_CURVE,
    MOD_TELEPORT,
    MOD_SHIELD,
    MOD_GIANT,
];

// Event bits returned from tick_with_dt so the frontend can do juice
// (particles, sound, shake, slow-mo) without polling game state.
pub const EVT_PADDLE_LEFT: u32 = 1;
pub const EVT_PADDLE_RIGHT: u32 = 2;
pub const EVT_WALL: u32 = 4;
pub const EVT_SCORE: u32 = 8;
pub const EVT_DEATH: u32 = 16;
pub const EVT_NEAR_MISS: u32 = 32;
pub const EVT_NEW_MOD: u32 = 64;
pub const EVT_SHIELD_SAVE: u32 = 128;
pub const EVT_TELEPORT: u32 = 256;

#[derive(Clone)]
struct Ball {
    x: f64,
    y: f64,
    dx: f64,
    dy: f64,
    spin: f64,
    phase: f64, // drives PHANTOM blinking / DRUNK wobble
}

#[wasm_bindgen]
pub struct PongGame {
    width: f64,
    height: f64,
    paddle_width: f64,
    player_height: f64,
    ai_height: f64,
    ball_size: f64,

    paddle_left_y: f64,
    paddle_right_y: f64,
    balls: Vec<Ball>,

    streak: u32,
    serve_right: bool,
    mods: u32,
    last_new_mod: u32,
    shield_charges: u32,

    // -1: Up, 0: Stop, 1: Down
    player_move: i32,

    ai_target_y: f64,
    ai_reaction_timer: f64,
}

#[wasm_bindgen]
impl PongGame {
    pub fn new(width: f64, height: f64) -> PongGame {
        let mut game = PongGame {
            width,
            height,
            paddle_width: 10.0,
            player_height: 100.0,
            ai_height: 100.0,
            ball_size: 10.0,

            paddle_left_y: (height - 100.0) / 2.0,
            paddle_right_y: (height - 100.0) / 2.0,
            balls: Vec::new(),

            streak: 0,
            serve_right: random() > 0.5,
            mods: 0,
            last_new_mod: 0,
            shield_charges: 0,

            player_move: 0,

            ai_target_y: height / 2.0,
            ai_reaction_timer: 0.0,
        };
        game.reset_balls();
        game
    }

    fn serve_speed(&self) -> f64 {
        if self.mods & MOD_TURBO != 0 {
            9.5
        } else {
            8.0
        }
    }

    fn max_speed(&self) -> f64 {
        if self.mods & MOD_TURBO != 0 {
            24.0
        } else {
            18.0
        }
    }

    fn recompute_paddles(&mut self) {
        let mut p = 100.0;
        if self.mods & MOD_SHRINK != 0 {
            p *= 0.7;
        }
        if self.mods & MOD_GIANT != 0 {
            p *= 1.45;
        }
        self.player_height = p;
        self.ai_height = if self.mods & MOD_JUGGERNAUT != 0 {
            145.0
        } else {
            100.0
        };
        self.paddle_left_y = self
            .paddle_left_y
            .clamp(0.0, self.height - self.player_height);
        self.paddle_right_y = self.paddle_right_y.clamp(0.0, self.height - self.ai_height);
    }

    fn new_ball(&mut self) -> Ball {
        let speed = self.serve_speed();
        let angle = (random() * PI / 4.0) - PI / 8.0;
        let direction = if self.serve_right { 1.0 } else { -1.0 };
        self.serve_right = !self.serve_right;
        Ball {
            x: self.width / 2.0,
            y: self.height / 2.0,
            dx: direction * speed * angle.cos(),
            dy: speed * angle.sin(),
            spin: 0.0,
            phase: random() * PI * 2.0,
        }
    }

    fn desired_ball_count(&self) -> usize {
        if self.mods & MOD_SPLIT != 0 {
            2
        } else {
            1
        }
    }

    fn reset_balls(&mut self) {
        self.balls.clear();
        let n = self.desired_ball_count();
        for _ in 0..n {
            let b = self.new_ball();
            self.balls.push(b);
        }
    }

    fn on_player_scored(&mut self) -> u32 {
        let mut events = EVT_SCORE;
        self.streak += 1;
        if self.streak % 3 == 0 {
            // swap to a different random protocol (one active at a time)
            let options: Vec<u32> = ALL_MODS
                .iter()
                .copied()
                .filter(|m| *m != self.mods)
                .collect();
            let pick = options[(random() * options.len() as f64) as usize % options.len()];
            self.mods = pick;
            self.last_new_mod = pick;
            events |= EVT_NEW_MOD;
            self.shield_charges = if pick == MOD_SHIELD { 1 } else { 0 };
            self.recompute_paddles();
            if pick == MOD_SPLIT {
                // split immediately: clone the surviving ball, mirrored
                if let Some(b) = self.balls.first().cloned() {
                    let mut twin = b;
                    twin.dy = -twin.dy;
                    twin.spin = -twin.spin;
                    self.balls.push(twin);
                }
            }
        }
        events
    }

    fn on_player_died(&mut self) {
        self.streak = 0;
        self.mods = 0;
        self.shield_charges = 0;
        self.recompute_paddles();
        self.reset_balls();
    }

    pub fn tick(&mut self) -> u32 {
        self.tick_with_dt(1.0)
    }

    pub fn tick_with_dt(&mut self, dt: f64) -> u32 {
        let mut events: u32 = 0;

        // --- player paddle (MIRROR inverts controls) ---
        let effective_move = if self.mods & MOD_MIRROR != 0 {
            -self.player_move
        } else {
            self.player_move
        };
        let speed = 6.0 * dt;
        if effective_move == -1 {
            self.paddle_left_y -= speed;
        } else if effective_move == 1 {
            self.paddle_left_y += speed;
        }
        self.paddle_left_y = self
            .paddle_left_y
            .clamp(0.0, self.height - self.player_height);

        // --- AI paddle: track the most threatening approaching ball ---
        self.ai_reaction_timer += dt;
        let threat = self
            .balls
            .iter()
            .filter(|b| b.dx > 0.0)
            .max_by(|a, b| a.x.partial_cmp(&b.x).unwrap_or(std::cmp::Ordering::Equal))
            .cloned();

        if let Some(tb) = threat {
            if self.ai_reaction_timer > 10.0 {
                self.ai_reaction_timer = 0.0;
                let perfect_target = tb.y - self.ai_height / 2.0;
                let dist_ratio = (self.width - tb.x).max(0.0) / self.width;
                let error_mag = if self.mods & MOD_SNIPER != 0 {
                    2.0
                } else {
                    60.0 * dist_ratio + 5.0
                };
                let error = (random() - 0.5) * 2.0 * error_mag;
                self.ai_target_y = perfect_target + error;
            }
            let ai_speed = 6.0 * dt;
            if self.paddle_right_y < self.ai_target_y - 5.0 {
                self.paddle_right_y += ai_speed;
            } else if self.paddle_right_y > self.ai_target_y + 5.0 {
                self.paddle_right_y -= ai_speed;
            }
        } else {
            self.ai_reaction_timer = 0.0;
            let center_y = (self.height - self.ai_height) / 2.0;
            let drift = 3.0 * dt;
            if self.paddle_right_y < center_y - 5.0 {
                self.paddle_right_y += drift;
            } else if self.paddle_right_y > center_y + 5.0 {
                self.paddle_right_y -= drift;
            }
        }
        self.paddle_right_y = self.paddle_right_y.clamp(0.0, self.height - self.ai_height);

        // --- balls ---
        let max_speed = self.max_speed();
        let gravity_on = self.mods & MOD_GRAVITY != 0;
        let wrap_on = self.mods & MOD_WRAP != 0;
        let drunk_on = self.mods & MOD_DRUNK != 0;
        let teleport_on = self.mods & MOD_TELEPORT != 0;
        let mut scored = 0u32;
        let mut died = false;

        for bi in 0..self.balls.len() {
            let mut b = self.balls[bi].clone();
            b.phase += 0.12 * dt;

            let current_speed = (b.dx.powi(2) + b.dy.powi(2)).sqrt();

            // spin curves the ball; renormalize so spin doesn't change speed
            b.dy += b.spin * dt;
            b.spin *= (0.96_f64).powf(dt);
            let sp_sq = b.dx.powi(2) + b.dy.powi(2);
            if sp_sq > 0.0001 {
                let sp = sp_sq.sqrt();
                b.dx = (b.dx / sp) * current_speed;
                b.dy = (b.dy / sp) * current_speed;
            }

            // protocols that bend the trajectory (capped below, so they
            // can't pump energy into the ball forever)
            if gravity_on {
                b.dy += 0.08 * dt;
            }
            if drunk_on {
                b.dy += (b.phase * 4.0).sin() * 0.35 * dt;
            }
            let sp_sq = b.dx.powi(2) + b.dy.powi(2);
            if sp_sq > max_speed * max_speed {
                let sp = sp_sq.sqrt();
                b.dx = (b.dx / sp) * max_speed;
                b.dy = (b.dy / sp) * max_speed;
            }

            if b.dy.abs() < 0.5 && !gravity_on {
                let sign = if b.dy >= 0.0 { 1.0 } else { -1.0 };
                b.dy = sign * 0.5;
                b.dx = b.dx.signum() * (current_speed * current_speed - 0.25).max(0.0).sqrt();
            }

            // TELEPORT: the ball blinks to a different height mid-flight
            if teleport_on && random() < 0.006 * dt {
                let jump = (random() - 0.5) * 220.0;
                b.y = (b.y + jump).clamp(0.0, self.height - self.ball_size);
                events |= EVT_TELEPORT;
            }

            let prev_x = b.x;
            b.x += b.dx * dt;
            b.y += b.dy * dt;

            // walls (or wrap-around)
            if wrap_on {
                if b.y < -self.ball_size {
                    b.y += self.height + self.ball_size;
                } else if b.y > self.height {
                    b.y -= self.height + self.ball_size;
                }
            } else if b.y <= 0.0 {
                b.y = 0.0;
                b.dy = b.dy.abs();
                b.spin *= 0.5;
                b.dy += (random() - 0.5) * 0.2;
                events |= EVT_WALL;
            } else if b.y + self.ball_size >= self.height {
                b.y = self.height - self.ball_size;
                b.dy = -b.dy.abs();
                b.spin *= 0.5;
                b.dy += (random() - 0.5) * 0.2;
                events |= EVT_WALL;
            }

            // player paddle (left, occupies x 0..paddle_width)
            let crossed_left = prev_x > self.paddle_width && b.x <= self.paddle_width;
            if b.x <= self.paddle_width
                && b.y + self.ball_size >= self.paddle_left_y
                && b.y <= self.paddle_left_y + self.player_height
                && b.dx < 0.0
            {
                let paddle_center = self.paddle_left_y + self.player_height / 2.0;
                let ball_center = b.y + self.ball_size / 2.0;
                let relative = (ball_center - paddle_center) / self.player_height;
                let bounce_angle = relative * (PI / 2.5);

                let sp = (b.dx.powi(2) + b.dy.powi(2)).sqrt();
                let new_speed = (sp * 1.03).min(max_speed);
                b.dx = new_speed * bounce_angle.cos();
                b.dy = new_speed * bounce_angle.sin();
                b.x = self.paddle_width;
                b.spin = if self.player_move != 0 {
                    (self.player_move as f64) * 0.25
                } else {
                    0.0
                };
                events |= EVT_PADDLE_LEFT;
            } else if crossed_left && b.dx < 0.0 {
                // near miss: ball passed the paddle plane just out of reach
                let gap = if b.y + self.ball_size < self.paddle_left_y {
                    self.paddle_left_y - (b.y + self.ball_size)
                } else {
                    b.y - (self.paddle_left_y + self.player_height)
                };
                if gap > 0.0 && gap < 40.0 {
                    events |= EVT_NEAR_MISS;
                }
            }

            // AI paddle (right, occupies width-paddle_width..width)
            if b.x + self.ball_size >= self.width - self.paddle_width
                && b.y + self.ball_size >= self.paddle_right_y
                && b.y <= self.paddle_right_y + self.ai_height
                && b.dx > 0.0
            {
                let paddle_center = self.paddle_right_y + self.ai_height / 2.0;
                let ball_center = b.y + self.ball_size / 2.0;
                let relative = (ball_center - paddle_center) / self.ai_height;
                let bounce_angle = relative * (PI / 2.5);

                let sp = (b.dx.powi(2) + b.dy.powi(2)).sqrt();
                let new_speed = (sp * 1.03).min(max_speed);
                b.dx = -1.0 * new_speed * bounce_angle.cos();
                b.dy = new_speed * bounce_angle.sin();
                b.x = self.width - self.paddle_width - self.ball_size;
                b.spin = if self.mods & MOD_CURVE != 0 {
                    (random() - 0.5) * 0.8
                } else {
                    0.0
                };
                events |= EVT_PADDLE_RIGHT;
            }

            // scoring / shield save
            if b.x < -self.ball_size {
                if self.shield_charges > 0 {
                    self.shield_charges -= 1;
                    b.x = 0.0;
                    b.dx = b.dx.abs().max(4.0);
                    events |= EVT_SHIELD_SAVE;
                } else {
                    died = true;
                }
            } else if b.x > self.width {
                scored += 1;
                let nb = self.new_ball();
                self.balls[bi] = nb;
                continue;
            }

            self.balls[bi] = b;
        }

        if died {
            events |= EVT_DEATH;
            self.on_player_died();
        } else {
            for _ in 0..scored {
                events |= self.on_player_scored();
            }
            // keep ball count in sync with SPLIT (e.g. just activated)
            while self.balls.len() < self.desired_ball_count() {
                let b = self.new_ball();
                self.balls.push(b);
            }
            while self.balls.len() > self.desired_ball_count() {
                self.balls.pop();
            }
        }

        events
    }

    // Flat [x, y, phase, ...] per ball for rendering.
    pub fn balls_data(&self) -> Vec<f64> {
        let mut out = Vec::with_capacity(self.balls.len() * 3);
        for b in &self.balls {
            out.push(b.x);
            out.push(b.y);
            out.push(b.phase);
        }
        out
    }

    pub fn streak(&self) -> u32 {
        self.streak
    }

    pub fn active_mods(&self) -> u32 {
        self.mods
    }

    pub fn last_new_mod(&self) -> u32 {
        self.last_new_mod
    }

    pub fn shield_charges(&self) -> u32 {
        self.shield_charges
    }

    pub fn paddle_left_y(&self) -> f64 {
        self.paddle_left_y
    }

    pub fn paddle_right_y(&self) -> f64 {
        self.paddle_right_y
    }

    pub fn player_paddle_height(&self) -> f64 {
        self.player_height
    }

    pub fn ai_paddle_height(&self) -> f64 {
        self.ai_height
    }

    pub fn ball_x(&self) -> f64 {
        self.balls.first().map(|b| b.x).unwrap_or(0.0)
    }

    pub fn ball_y(&self) -> f64 {
        self.balls.first().map(|b| b.y).unwrap_or(0.0)
    }

    pub fn set_player_movement(&mut self, move_dir: i32) {
        self.player_move = move_dir;
    }

    pub fn get_ball_speed(&self) -> f64 {
        self.balls
            .first()
            .map(|b| (b.dx.powi(2) + b.dy.powi(2)).sqrt())
            .unwrap_or(0.0)
    }
}
