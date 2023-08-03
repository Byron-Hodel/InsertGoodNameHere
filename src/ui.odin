package main

import "core:math/linalg/glsl"
import rend "rendering"


Ui_Layer :: struct {
    view_proj: glsl.mat4,
    batches: [dynamic]Batch,
    textures: [dynamic]rend.Texture2D,

    test_button: Ui_Button,
}


Ui_Button :: struct {
    state: Ui_Button_State,
    pos: glsl.vec2,
    extent: glsl.vec2,
}

Ui_Button_State :: enum {
    Hidden,
    Pressed,
    Held,
    Released,
}

Quad_Batch_Vertex :: struct {
    pos: glsl.vec2,
    tex_coord: glsl.vec2,
    tex_id: u8,
}

Batch :: struct {
    vert_buf: rend.Vertex_Buffer,
    index_buf: rend.Index_Buffer,
    textures: [8]rend.Texture2D,
    texture_bind_coords: [8]i32,
    texture_count: u8,
}

ui_layer_init :: proc(layer: ^Ui_Layer) -> bool {

    return true
}

ui_layer_on_event :: proc(layer: ^Ui_Layer, event: Event) -> bool {
    #partial switch e in event {
    case Mouse_Button_Event:
    }
    return false
}

ui_layer_draw :: proc(layer: ^Ui_Layer) {
    for b in layer.batches {
        //batch_draw(b)
    }
}

batch_draw :: proc(batch: Batch) {
    for i in 0..<batch.texture_count {
        rend.bind(batch.textures[i], batch.texture_bind_coords[i])
    }
    defer for i in 0..<batch.texture_count {
        rend.unbind(batch.textures[i], batch.texture_bind_coords[i])
    }
    rend.draw_indices(0, batch.vert_buf, batch.index_buf)
}
