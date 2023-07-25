package main

import "core:math/linalg/glsl"
import rend "rendering"

TEXT_VERT_SRC :: #load("../resources/shaders/text.vert", string)
TEXT_FRAG_SRC :: #load("../resources/shaders/text.frag", string)

Ui_Layer :: struct {
    vertex_buffer: rend.Vertex_Buffer,
    index_buffer: rend.Index_Buffer,
    quad_data_buffer: rend.Uniform_Buffer,
    text_shader: rend.Graphics_Pipeline,
    quad_data: Quad_Data,
    quad_data_loc: i32,
    instances: int,

    show_menu: bool,
}

Quad_Data :: struct {
    origin: [MAX_QUADS]glsl.vec4,
    size: [MAX_QUADS]glsl.vec4,
    tex_coord: [MAX_QUADS]glsl.vec4,
    tex_extent: [MAX_QUADS]glsl.vec4,
}

QUAD_INSTANCE_VERTS :: []glsl.vec2 {
    { 0, 0 },
    { 1, 0 },
    { 1, 1 },
    { 0, 1 },
} 

QUAD_INSTANCE_INDICES :: []u8 {
    0, 2, 1,
    0, 3, 2,
}

QUAD_INSTANCE_VERT_ATTRIBUTES :: []rend.Vertex_Attribute {
    {
        name = "pos",
        location = 0,
        length = 2,
        type = .F32,
        normalized = false,
        stride = size_of(glsl.vec2),
        offset = 0,
    },
}

MAX_QUADS :: 1024


ui_layer_init :: proc(layer: ^Ui_Layer) -> bool {
    layer.quad_data.origin[0] = {-0.25,-0.25,0,0}
    layer.quad_data.size[0] = {0.5,0.5,0,0}
    layer.quad_data.tex_coord[0] = {0,0,0,0}
    layer.quad_data.tex_extent[0] = {1,1,0,0}

    layer.text_shader = rend.graphics_pipeline_create(TEXT_VERT_SRC, TEXT_FRAG_SRC,
                                                      QUAD_INSTANCE_VERT_ATTRIBUTES) or_return

    layer.vertex_buffer = rend.vertex_buffer_create(size_of(glsl.vec2) * len(QUAD_INSTANCE_VERTS),
                                                    raw_data(QUAD_INSTANCE_VERTS),
                                                    QUAD_INSTANCE_VERT_ATTRIBUTES, .Static)
    layer.index_buffer = rend.index_buffer_create(size_of(u8) * len(QUAD_INSTANCE_INDICES),
                                                  .U8, raw_data(QUAD_INSTANCE_INDICES), .Static)

    layer.quad_data_buffer = rend.uniform_buffer_create(size_of(Quad_Data), &layer.quad_data, .Static)

    layer.quad_data_loc = rend.graphics_pipeline_get_ubuffer_location(layer.text_shader,
                                                                      "Instance_Data")


    return true
}

ui_layer_on_event :: proc(layer: ^Ui_Layer, event: Event) -> bool {
    #partial switch e in event {
    case Key_Event:
        if e.id == .Escape && e.new_state == .Pressed {
            layer.show_menu = !layer.show_menu
            return true
        }
    }
    return false
}

ui_layer_draw :: proc(layer: ^Ui_Layer) {
    if !layer.show_menu {
        return
    }
    rend.buffer_bind(layer.vertex_buffer)
    rend.buffer_bind(layer.index_buffer)
    rend.graphics_pipeline_bind(layer.text_shader)
    rend.buffer_bind(layer.quad_data_buffer, layer.quad_data_loc)

    rend.draw_indices_instanced(len(QUAD_INSTANCE_INDICES), 0, .U8, 1)
}

