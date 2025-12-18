use std::f64::consts::PI;
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
extern "C" {
    #[wasm_bindgen(js_namespace = Math)]
    fn random() -> f64;
}

#[wasm_bindgen]
pub struct PongGame {
    width: f64,
    height: f64,
    paddle_height: f64,
    paddle_width: f64,
    ball_size: f64,

    // Game State
    paddle_left_y: f64,
    paddle_right_y: f64,
    ball_x: f64,
    ball_y: f64,
    ball_dx: f64,
    ball_dy: f64,
    ball_spin: f64,

    streak: u32,

    // -1: Up, 0: Stop, 1: Down
    player_move: i32,

    // AI State
    ai_target_y: f64,
    ai_reaction_timer: i32,
}

#[wasm_bindgen]
impl PongGame {
    pub fn new(width: f64, height: f64) -> PongGame {
        let mut game = PongGame {
            width,
            height,
            paddle_height: 100.0,
            paddle_width: 10.0,
            ball_size: 10.0,

            paddle_left_y: (height - 100.0) / 2.0,
            paddle_right_y: (height - 100.0) / 2.0,

            ball_x: width / 2.0,
            ball_y: height / 2.0,
            ball_dx: 0.0,
            ball_dy: 0.0,
            ball_spin: 0.0,

            streak: 0,

            player_move: 0,

            ai_target_y: height / 2.0,
            ai_reaction_timer: 0,
        };
        game.reset_ball();
        game
    }

    fn reset_ball(&mut self) {
        self.ball_x = self.width / 2.0;
        self.ball_y = self.height / 2.0;
        self.ball_spin = 0.0;

        let speed = 8.0;
        let angle = (random() * PI / 4.0) - PI / 8.0;

        let direction = 1.0;

        self.ball_dx = direction * speed * angle.cos();
        self.ball_dy = speed * angle.sin();
    }

    pub fn tick(&mut self) {
        let speed = 6.0;
        if self.player_move == -1 {
            self.paddle_left_y -= speed;
        } else if self.player_move == 1 {
            self.paddle_left_y += speed;
        }

        if self.paddle_left_y < 0.0 {
            self.paddle_left_y = 0.0;
        }
        if self.paddle_left_y + self.paddle_height > self.height {
            self.paddle_left_y = self.height - self.paddle_height;
        }

        self.ai_reaction_timer += 1;

        if self.ball_dx > 0.0 {
            if self.ai_reaction_timer > 10 {
                self.ai_reaction_timer = 0;

                let perfect_target = self.ball_y - self.paddle_height / 2.0;

                let dist_ratio = (self.width - self.ball_x).max(0.0) / self.width;

                let error_mag = 60.0 * dist_ratio + 5.0;
                let error = (random() - 0.5) * 2.0 * error_mag;

                self.ai_target_y = perfect_target + error;
            }

            let ai_speed = 6.0;
            if self.paddle_right_y < self.ai_target_y - 5.0 {
                self.paddle_right_y += ai_speed;
            } else if self.paddle_right_y > self.ai_target_y + 5.0 {
                self.paddle_right_y -= ai_speed;
            }
        } else {
            self.ai_reaction_timer = 0;

            let center_y = (self.height - self.paddle_height) / 2.0;
            if self.paddle_right_y < center_y - 5.0 {
                self.paddle_right_y += 3.0;
            } else if self.paddle_right_y > center_y + 5.0 {
                self.paddle_right_y -= 3.0;
            }
        }

        if self.paddle_right_y < 0.0 {
            self.paddle_right_y = 0.0;
        }
        if self.paddle_right_y + self.paddle_height > self.height {
            self.paddle_right_y = self.height - self.paddle_height;
        }

        let current_speed = (self.ball_dx.powi(2) + self.ball_dy.powi(2)).sqrt();

        self.ball_dy += self.ball_spin;
        self.ball_spin *= 0.96;

        let new_speed_sq = self.ball_dx.powi(2) + self.ball_dy.powi(2);
        if new_speed_sq > 0.0001 {
            let new_speed = new_speed_sq.sqrt();
            self.ball_dx = (self.ball_dx / new_speed) * current_speed;
            self.ball_dy = (self.ball_dy / new_speed) * current_speed;
        }

        if self.ball_dy.abs() < 0.5 {
            let sign = if self.ball_dy >= 0.0 { 1.0 } else { -1.0 };
            self.ball_dy = sign * 0.5;
        }

        self.ball_x += self.ball_dx;
        self.ball_y += self.ball_dy;

        if self.ball_y <= 0.0 || self.ball_y + self.ball_size >= self.height {
            self.ball_dy = -self.ball_dy;
            self.ball_spin *= 0.5;

            self.ball_dy += (random() - 0.5) * 0.2;
        }

        if self.ball_x <= self.paddle_width
            && self.ball_y + self.ball_size >= self.paddle_left_y
            && self.ball_y <= self.paddle_left_y + self.paddle_height
        {
            let paddle_center = self.paddle_left_y + self.paddle_height / 2.0;
            let ball_center = self.ball_y + self.ball_size / 2.0;
            let relative_intersect = (ball_center - paddle_center) / self.paddle_height;

            let bounce_angle = relative_intersect * (PI / 2.5);

            let current_speed = (self.ball_dx.powi(2) + self.ball_dy.powi(2)).sqrt();
            let new_speed = current_speed * 1.05;

            self.ball_dx = new_speed * bounce_angle.cos();
            self.ball_dy = new_speed * bounce_angle.sin();

            self.ball_x = self.paddle_width;

            let spin_amount = 0.25;
            if self.player_move != 0 {
                self.ball_spin = (self.player_move as f64) * spin_amount;
            } else {
                self.ball_spin = 0.0;
            }
        }

        if self.ball_x + self.ball_size >= self.width - self.paddle_width
            && self.ball_y + self.ball_size >= self.paddle_right_y
            && self.ball_y <= self.paddle_right_y + self.paddle_height
        {
            let paddle_center = self.paddle_right_y + self.paddle_height / 2.0;
            let ball_center = self.ball_y + self.ball_size / 2.0;
            let relative_intersect = (ball_center - paddle_center) / self.paddle_height;

            let bounce_angle = relative_intersect * (PI / 2.5);

            let current_speed = (self.ball_dx.powi(2) + self.ball_dy.powi(2)).sqrt();
            let new_speed = current_speed * 1.05;

            self.ball_dx = -1.0 * new_speed * bounce_angle.cos();
            self.ball_dy = new_speed * bounce_angle.sin();

            self.ball_x = self.width - self.paddle_width - self.ball_size;

            self.ball_spin = 0.0;
        }

        if self.ball_x < 0.0 {
            self.streak = 0;
            self.reset_ball();
        } else if self.ball_x > self.width {
            self.streak += 1;
            self.reset_ball();
        }
    }

    pub fn streak(&self) -> u32 {
        self.streak
    }

    pub fn paddle_left_y(&self) -> f64 {
        self.paddle_left_y
    }

    pub fn paddle_right_y(&self) -> f64 {
        self.paddle_right_y
    }

    pub fn ball_x(&self) -> f64 {
        self.ball_x
    }

    pub fn ball_y(&self) -> f64 {
        self.ball_y
    }

    pub fn set_player_movement(&mut self, move_dir: i32) {
        self.player_move = move_dir;
    }

    pub fn get_ball_speed(&self) -> f64 {
        (self.ball_dx.powi(2) + self.ball_dy.powi(2)).sqrt()
    }
}
