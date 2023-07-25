package main

import "core:fmt"
import "core:os"
import "core:math/linalg/glsl"
import img "core:image"
import "core:image/png"
import "core:runtime"
import "core:mem"

import "allocators"
import rend "rendering"

import webgl "vendor:wasm/WebGL"
import "vendor:wasm/js"

vao: webgl.VertexArrayObject
screen_res: glsl.vec2 = { 500, 500 }

general_allocator_data: allocators.General_Allocator_Data
scene_layer: Scene_Layer
ui_layer: Ui_Layer

main :: proc() {
    fmt.println("program start!")


    // start general allocator with half a gig
    allocators.general_init(&general_allocator_data, 500000000)
    general_allocator: runtime.Allocator = {
        procedure = allocators.general_allocator_proc,
        data = &general_allocator_data,
    }
    
    context.allocator = general_allocator

    events_ok := events_init()
    if !events_ok {
        panic("failed to init events")
    }

    renderer_ok := rend.init("render-area")
    if !renderer_ok {
        panic("failed to init rendering")
    }

    if !scene_layer_init(&scene_layer) {
        panic("failed to init scene layer")
    }

    if !ui_layer_init(&ui_layer) {
        panic("failed to init scene layer")
    }
}

// the update loop.
// I would use an infinite loop in the main function,
// however, that would end terribly
@export
step :: proc(delta_time: f32) {
    for event_queue_len > 0 {
        event := next_event()
        handled: bool = ui_layer_on_event(&ui_layer, event)
    }
    update_key_states()
    scene_layer_tick(&scene_layer, delta_time)
    scene_layer_draw(&scene_layer)

    ui_layer_draw(&ui_layer)
}
