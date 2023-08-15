package main

import "core:math/linalg/glsl"
import rend "rendering"

// TODO: impliment vertex buffer resizing to allow for more ui elements other than a single button

Ui_Layer :: struct {
    elements: [dynamic]Ui_Element,
    ui_pipeline: rend.Graphics_Pipeline,
    ortho_loc: i32,
    vert_buffer: rend.Vertex_Buffer,
    index_buffer: rend.Index_Buffer,
}

Ui_Element :: union {
    Ui_Button,
    Ui_Slider,
}

Ui_Element_State :: enum {
    Default,
    // ui element not visible
    Hidden,
    // cursor hovering over element
    Hovering,
    // left mouse button pressed while over ui element
    Pressed,
    // left mouse button held
    Held,
    // left mouse button released, can only happen after ui element was in the pressed or held state
    Released,
}

//Ui_Button :: struct {
//    id: i32,
//    state: Ui_Element_State, 
//    constraints: Ui_Constraints,
//}

Ui_Button :: struct {
    id: i32,
    width: u32,
    height: u32,
}

Ui_Slider :: struct {
    
}

Ui_Vertex :: struct {
    pos: glsl.vec3,
    uv: glsl.vec2,
}

UI_VERT_SRC :: #load("../resources/shaders/ui.vert", string)
UI_FRAG_SRC :: #load("../resources/shaders/ui.frag", string)

UI_VERTEX_LAYOUT :: []rend.Vertex_Attribute {
    {
       name = "", 
       location = 0,
       length = 0,
       type = .F32,
       normalized = false,
       stride = 0,
       offset = 0,
    },
}

ui_layer_init :: proc(layer: ^Ui_Layer) -> bool {
    p_ok: bool
    layer.ui_pipeline, p_ok = rend.graphics_pipeline_create(UI_VERT_SRC, UI_FRAG_SRC,
                                                            UI_VERTEX_LAYOUT)
    if !p_ok {
        //return false
    }
    layer.ortho_loc = rend.graphics_pipeline_get_uniform_location(layer.ui_pipeline, "ortho_proj")

    STARTING_VERTEX_COUNT :: 1024 
    STARTING_INDEX_COUNT :: 1024 

    vert_buffer_size := size_of(Ui_Vertex) * STARTING_VERTEX_COUNT
    layer.vert_buffer = rend.vertex_buffer_create(vert_buffer_size, nil, UI_VERTEX_LAYOUT, .Dynamic)
    layer.index_buffer = rend.index_buffer_create(STARTING_INDEX_COUNT, .U16, nil, .Dynamic)

    return true
}

ui_layer_on_event :: proc(layer: ^Ui_Layer, event: Event) -> bool {
    #partial switch e in event {
    case Mouse_Button_Event:
    }
    return false
}

ui_layer_add_element :: proc(layer: ^Ui_Layer, element: Ui_Element) {
    append(&layer.elements, element)
    switch e in element {
    case Ui_Button:
        
    case Ui_Slider:

    }
}

@(private="file")
expand_vertex_buffer :: proc(layer: ^Ui_Layer, vertex_count: int) {
    
}

@(private="file")
expand_index_buffer :: proc(layer: ^Ui_Layer, vertex_count: int) {
    
}

ui_layer_draw :: proc(layer: ^Ui_Layer, screen_res: [2]u32) {
    ortho_proj := glsl.mat4Ortho3d(0, f32(screen_res.x), 0, f32(screen_res.y), 0, 1)

    rend.bind(layer.ui_pipeline)
    defer rend.unbind(layer.ui_pipeline)

    rend.graphics_pipeline_set_uniform_mat4(layer.ortho_loc, ortho_proj)
}

ui_button_init :: proc(btn: ^Ui_Button, id: i32) {
    btn.id = id
}

