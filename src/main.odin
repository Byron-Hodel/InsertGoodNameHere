package main

import "core:math/linalg/glsl"

import "core:runtime"
import "allocators"
import rend "rendering"

general_allocator_data: allocators.General_Allocator_Data
scene_layer: Scene_Layer
ui_layer: Ui_Layer

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

    if !scene_layer_init(&scene_layer) {
        panic("failed to init scene layer")
    }

    if !ui_layer_init(&ui_layer) {
        panic("failed to init scene layer")
    }
}

@(private="file")
scene_layer_key_states: [Key_Id]Key_State

// the update loop.
// I would use an infinite loop in the main function,
// however, that would end terribly
@export
step :: proc(delta_time: f32) {
    for k in Key_Id {
        if scene_layer_key_states[k] == .Pressed {
            scene_layer_key_states[k] = .Held
        }
    }
    mouse_delta: glsl.vec2

    for event_queue_len > 0 {
        event := next_event()
        handled: bool = ui_layer_on_event(&ui_layer, event)
        if !handled {
            #partial switch e in event {
            case Key_Event:
                scene_layer_key_states[e.id] = e.new_state
            case Mouse_Move_Event:
                mouse_delta[0] += f32(e.delta.x)
                mouse_delta[1] += f32(e.delta.y)
            }
        }
    }
    scene_layer_tick(&scene_layer, scene_layer_key_states, mouse_delta, delta_time)
    scene_layer_draw(&scene_layer)

    ui_layer_draw(&ui_layer)
}
