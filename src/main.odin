package main

import "core:math/linalg/glsl"

import "core:runtime"
import "allocators"
import rend "rendering"

general_allocator_data: allocators.General_Allocator_Data

Scene :: union {
    Terrain_Scene,
}

@(private="file")
scene: Scene

main :: proc() {
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

    scene = Terrain_Scene {}
    if !terrain_scene_init(&scene.(Terrain_Scene)) {
        panic("failed to init terrain scene")
    }
}

@export
step :: proc(delta_time: f32) {
    mouse_delta: glsl.vec2
    scroll_delta: f32

    for event_queue_len > 0 {
        event := next_event()
        switch s in scene {
        case Terrain_Scene:
            terrain_scene_on_event(&scene.(Terrain_Scene), event)
        }

        #partial switch e in event {
        case Mouse_Move_Event:
            mouse_delta[0] += f32(e.delta.x)
            mouse_delta[1] += f32(e.delta.y)
        case Mouse_Wheel_Event:
            scroll_delta += e.delta.x
        }
    }
    switch s in scene {
    case Terrain_Scene:
        terrain_scene_update(&scene.(Terrain_Scene), delta_time, scroll_delta)
        terrain_scene_draw(&scene.(Terrain_Scene))
    }
}
