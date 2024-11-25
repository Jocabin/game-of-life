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
	paused:      bool,
	framebuffer: [COLS * ROWS]bool,
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

	waiting_pixels: [dynamic]int
	generations := 1
	step := false

	state := Game_State{}
	state.paused = true

	rl.SetTargetFPS(10)
	rl.InitWindow(DISPLAY_WIDTH, DISPLAY_HEIGHT + 50, "Game of life in Odin")
	defer rl.CloseWindow()

	for !rl.WindowShouldClose() {
		free_all(context.temp_allocator)

		if rl.IsKeyPressed(.SPACE) do state.paused = !state.paused
		if rl.IsKeyPressed(.S) do step = false

		// grid edition
		if state.paused {
			if rl.IsKeyPressed(.C) do mem.zero_slice(state.framebuffer[:])

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

		if !state.paused || step == false {
			clear(&waiting_pixels)

			// todo: optimize this shitty code
			// todo: fix cels stopping at window borders
			for x := 0; x < COLS; x += 1 {
				for y := 0; y < ROWS; y += 1 {
					cell := state.framebuffer[y * COLS + x]
					total_count := get_total_neighbors(state, x, y)

					// apply game of life rules
					// if cell == true {
					// 	if total_count < 2 do state.framebuffer[y * COLS + x] = false
					// 	else if total_count == 2 || total_count == 3 do state.framebuffer[y * COLS + x] = true
					// 	else if total_count > 3 do state.framebuffer[y * COLS + x] = false
					// } else {
					// 	if total_count == 3 do state.framebuffer[y * COLS + x] = true
					// }
					if cell == true && (total_count == 2 || total_count == 3) do append(&waiting_pixels, y * COLS + x)
					else if cell == false && total_count == 3 do append(&waiting_pixels, y * COLS + x)
				}
			}

			mem.zero_slice(state.framebuffer[:])
			for pix in waiting_pixels {
				state.framebuffer[pix] = true
			}

			generations += 1
		}
		step = true

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
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

		menu_rec := rl.Rectangle{0, DISPLAY_HEIGHT, DISPLAY_WIDTH, 50}
		rl.DrawRectangleRec(menu_rec, rl.RAYWHITE)
		// todo: btn play/pause
		// todo: label generations
		// todo: btn step
		// todo: btn clear
		// todo: toggle menu

		rl.EndDrawing()
	}
}

get_total_neighbors :: proc(state: Game_State, x, y: int) -> (total_count: u8) {
	if x > 0 {
		if y > 0 do total_count += u8(state.framebuffer[(y - 1) * COLS + (x - 1)])
		total_count += u8(state.framebuffer[y * COLS + (x - 1)])
		if y < ROWS - 1 do total_count += u8(state.framebuffer[(y + 1) * COLS + (x - 1)])
	}

	if y > 0 do total_count += u8(state.framebuffer[(y - 1) * COLS + x])
	if y < ROWS - 1 do total_count += u8(state.framebuffer[(y + 1) * COLS + x])

	if x < COLS - 1 {
		if y > 0 do total_count += u8(state.framebuffer[(y - 1) * COLS + (x + 1)])
		total_count += u8(state.framebuffer[y * COLS + (x + 1)])
		if y < ROWS - 1 do total_count += u8(state.framebuffer[(y + 1) * COLS + (x + 1)])
	}

	return
}
