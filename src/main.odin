package gol

import "core:fmt"
import "core:mem"
import rl "vendor:raylib"

PIXEL_SIZE :: 10
DISPLAY_WIDTH :: 1230
DISPLAY_HEIGHT :: 770
COLS :: DISPLAY_WIDTH / PIXEL_SIZE
ROWS :: DISPLAY_HEIGHT / PIXEL_SIZE

Game_State :: struct {
	paused:         bool,
	framebuffer:    [COLS * ROWS]bool,
	waiting_pixels: [COLS * ROWS]bool,
	generations:    u32,
	step:           bool,
	speed:          i32,
}

main :: proc() {
	// track for memory leaks
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	state := Game_State {
		paused = true,
		speed  = 10,
	}

	rl.SetTargetFPS(60)
	rl.SetTraceLogLevel(.NONE)
	rl.InitWindow(DISPLAY_WIDTH, DISPLAY_HEIGHT + 50, "Game of life in Odin")
	defer rl.CloseWindow()

	for !rl.WindowShouldClose() {
		free_all(context.temp_allocator)

		if rl.IsKeyPressed(.SPACE) do state.paused = !state.paused
		if rl.IsKeyPressed(.S) do state.step = false

		// grid edition
		if state.paused {
			rl.SetTargetFPS(60)
			if rl.IsKeyPressed(.C) {
				mem.zero_slice(state.framebuffer[:])
				mem.zero_slice(state.waiting_pixels[:])
				state.generations = 0
			}

			if in_rec(rl.GetMousePosition(), {0, 0, DISPLAY_WIDTH, DISPLAY_HEIGHT}) {
				if rl.IsMouseButtonDown(.LEFT) {
					x := clamp(rl.GetMouseX() / PIXEL_SIZE, 0, COLS - 1)
					y := clamp(rl.GetMouseY() / PIXEL_SIZE, 0, ROWS - 1)

					state.framebuffer[y * COLS + x] = true
				}

				if rl.IsMouseButtonDown(.RIGHT) {
					x := clamp(rl.GetMouseX() / PIXEL_SIZE, 0, COLS - 1)
					y := clamp(rl.GetMouseY() / PIXEL_SIZE, 0, ROWS - 1)

					state.framebuffer[y * COLS + x] = false
				}
			}
		}

		// cells evolution
		if !state.paused || state.step == false {
			rl.SetTargetFPS(state.speed)

			for x := 0; x < COLS; x += 1 {
				for y := 0; y < ROWS; y += 1 {
					cell := state.framebuffer[y * COLS + x]
					total_count := get_total_neighbors(state, x, y)

					// apply game of life rules
					if cell == true {
						if total_count < 2 do state.waiting_pixels[y * COLS + x] = false
						else if total_count == 2 || total_count == 3 do state.waiting_pixels[y * COLS + x] = true
						else if total_count > 3 do state.waiting_pixels[y * COLS + x] = false
					} else {
						if total_count == 3 do state.waiting_pixels[y * COLS + x] = true
					}
				}
			}

			for pix, idx in state.waiting_pixels {
				state.framebuffer[idx] = pix
			}

			state.generations += 1
		}
		state.step = true

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		// game drawing
		for x := 0; x < COLS; x += 1 {
			for y := 0; y < ROWS; y += 1 {
				if state.framebuffer[y * COLS + x] {
					pixel := rl.Rectangle {
						f32(x) * PIXEL_SIZE,
						f32(y) * PIXEL_SIZE,
						PIXEL_SIZE,
						PIXEL_SIZE,
					}
					rl.DrawRectangleRec(pixel, rl.WHITE)
				}
			}
		}

		// ui drawing
		menu_rec := rl.Rectangle{0, DISPLAY_HEIGHT, DISPLAY_WIDTH, 50}
		btn_y := i32(menu_rec.y + 10)
		last_rec_w := 0

		rl.DrawRectangleRec(menu_rec, rl.RAYWHITE)
		if ui_button(&last_rec_w, i32(menu_rec.x + 10), btn_y, state.paused ? "Play (SPACE)" : "Pause (SPACE)") do state.paused = !state.paused
		if ui_button(&last_rec_w, i32(last_rec_w + 10), btn_y, "Speed +") do state.speed = clamp(state.speed + 10, 10, 60)
		if ui_button(&last_rec_w, i32(last_rec_w + 10), btn_y, "Speed -") do state.speed = clamp(state.speed - 10, 10, 60)

		if state.paused {
			if ui_button(&last_rec_w, i32(last_rec_w + 10), btn_y, "Step (S)") do state.step = false
			if ui_button(&last_rec_w, i32(last_rec_w + 10), btn_y, "Clear (C)") {
				mem.zero_slice(state.framebuffer[:])
				mem.zero_slice(state.waiting_pixels[:])
				state.generations = 0
			}
		}
		gen_text := rl.TextFormat("Generation: %d", state.generations)
		rl.DrawText(gen_text, i32(last_rec_w) + 30, btn_y + 5, 20, rl.BLACK)
		last_rec_w += int(rl.MeasureText(gen_text, 20) + 30)

		rl.DrawText(
			rl.TextFormat("FPS: %d", rl.GetFPS()),
			i32(last_rec_w) + 30,
			btn_y + 5,
			20,
			rl.BLACK,
		)

		rl.EndDrawing()
	}
}

get_total_neighbors :: proc(state: Game_State, x, y: int) -> (total_count: u8) {
	total_count += u8(state.framebuffer[get_fb_index(x - 1, y - 1)])
	total_count += u8(state.framebuffer[get_fb_index(x - 1, y)])
	total_count += u8(state.framebuffer[get_fb_index(x - 1, y + 1)])

	total_count += u8(state.framebuffer[get_fb_index(x, y - 1)])
	total_count += u8(state.framebuffer[get_fb_index(x, y + 1)])

	total_count += u8(state.framebuffer[get_fb_index(x + 1, y - 1)])
	total_count += u8(state.framebuffer[get_fb_index(x + 1, y)])
	total_count += u8(state.framebuffer[get_fb_index(x + 1, y + 1)])

	return
}

ui_button :: proc(last_rec_w: ^int, x, y: i32, txt: cstring) -> bool {
	w := rl.MeasureText(txt, 20) + 30
	last_rec_w^ += int(w) + 10
	rec := rl.Rectangle{f32(x), f32(y), f32(w), 30}
	hover := in_rec(rl.GetMousePosition(), rec)

	rl.DrawRectangleRec(rec, hover ? rl.BLACK : rl.RAYWHITE)
	rl.DrawRectangleLinesEx(rec, 2, rl.BLACK)
	rl.DrawText(txt, x + 15, y + 5, 20, hover ? rl.RAYWHITE : rl.BLACK)

	return hover && rl.IsMouseButtonPressed(.LEFT)
}

in_rec :: proc(mouse_pos: rl.Vector2, bounds: rl.Rectangle) -> bool {
	x_ok := mouse_pos[0] >= bounds.x && mouse_pos[0] <= (bounds.x + bounds.width)
	y_ok := mouse_pos[1] >= bounds.y && mouse_pos[1] <= (bounds.y + bounds.height)

	return x_ok && y_ok
}

get_fb_index :: proc(x, y: int) -> int {
	vx := x
	vy := y

	if y < 0 do vy = ROWS - 1
	else if y >= ROWS do vy = 0

	if x < 0 do vx = COLS - 1
	else if x >= COLS do vx = 0

	return vy * COLS + vx
}
