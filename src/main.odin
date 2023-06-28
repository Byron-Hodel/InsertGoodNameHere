package main

import "core:fmt"

import webgl "vendor:wasm/WebGL"
import "vendor:wasm/js"

main :: proc() {
	fmt.println("program start!")
}

@export
step :: proc(delta_time: f32) {
}
