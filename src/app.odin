package main

import "core:fmt"
import "core:math/linalg/glsl"
import "core:image"
import "core:image/png"

import rend "rendering"
import webgl "vendor:wasm/WebGL"

Screen_Quad_Vert :: struct {
    pos: glsl.vec2,
    uv: glsl.vec2,
}

Camera :: struct {
    speed: f32,
    x_dir: glsl.vec3,
    y_dir: glsl.vec3,
    z_dir: glsl.vec3,
    pos: glsl.vec3,
    rot: glsl.quat,
    view: glsl.mat4,
    proj: glsl.mat4,
    view_proj: glsl.mat4,
}

Camera_Mode :: enum {
    Free,
    Orbital,
}

App_State :: struct {
    screen_quad_vert_buff: rend.Vertex_Buffer,
    screen_quad_index_buff: rend.Index_Buffer,
    terrain_shader: rend.Graphics_Pipeline,
    //ts_screen_res_loc: i32,
    ts_inverse_view_loc: i32, 
    ts_inverse_proj_loc: i32, 
    ts_height_loc: i32, 
    ts_color_loc: i32, 

    height_tex: rend.Texture2D,
    color_tex: rend.Texture2D,

    cam: Camera,
    cam_mode: Camera_Mode, 
}

SCREEN_QUAD_VERTS :: []Screen_Quad_Vert {
    { pos = { -1, -1 }, uv = { 0, 0 } },
    { pos = {  1, -1 }, uv = { 1, 0 } },
    { pos = {  1,  1 }, uv = { 1, 1 } },
    { pos = { -1,  1 }, uv = { 0, 1 } },
}

SCREEN_QUAD_INDICES :: []u16 {
    0, 2, 1,
    0, 3, 2,
}

SCREEN_QUAD_VERT_ATTRIBUTES :: []rend.Vertex_Attribute {
    {
        name = "pos",
        location = 0,
        length = 2,
        type = .F32,
        normalized = false,
        stride = size_of(Screen_Quad_Vert),
        offset = int(offset_of(Screen_Quad_Vert, pos)),
    },
    {
        name = "uv",
        location = 1,
        length = 2,
        type = .F32,
        normalized = false,
        stride = size_of(Screen_Quad_Vert),
        offset = int(offset_of(Screen_Quad_Vert, uv)),
    },
}

SCREEN_RES :: glsl.vec2 { 900, 900 }

SCREEN_QUAD_VERT_SRC :: #load("../resources/shaders/screen_quad.vert", string)
TERRAIN_FRAG_SRC :: #load("../resources/shaders/terrain.frag", string)

MAP_HEIGHT_PNG :: #load("../resources/images/D1.png", []u8)
MAP_COLOR_PNG :: #load("../resources/images/C1W.png", []u8)

app_init :: proc(app_state: ^App_State) -> bool {
    height_img, height_err := png.load_from_bytes(MAP_HEIGHT_PNG)
    color_img, color_err := png.load_from_bytes(MAP_COLOR_PNG)
    defer image.destroy(height_img)
    defer image.destroy(color_img)

    app_state.height_tex = rend.create_texture2d(height_img)
    app_state.color_tex = rend.create_texture2d(color_img)

    if height_err != nil {
        fmt.eprintln("Failed To Load Height Map: ", height_err)
    }
    if color_err != nil {
        fmt.eprintln("Failed To Load Height Map: ", height_err)
    }

    terrain_shader, ts_ok := rend.graphics_pipeline_create(SCREEN_QUAD_VERT_SRC, TERRAIN_FRAG_SRC,
                                                           SCREEN_QUAD_VERT_ATTRIBUTES)

    if !ts_ok {
        return false
    }

    //app_state.ts_screen_res_loc = rend.graphics_pipeline_get_uniform_location(terrain_shader,
    //                                                                          "u_screen_resolution")
    app_state.ts_inverse_view_loc = rend.graphics_pipeline_get_uniform_location(terrain_shader,
                                                                              "u_inverse_view")
    app_state.ts_inverse_proj_loc = rend.graphics_pipeline_get_uniform_location(terrain_shader,
                                                                              "u_inverse_proj")
    app_state.ts_height_loc = rend.graphics_pipeline_get_uniform_location(terrain_shader, "u_height_map")
    app_state.ts_color_loc = rend.graphics_pipeline_get_uniform_location(terrain_shader, "u_color_map")

    //fmt.println("scr res loc: ", app_state.ts_screen_res_loc)
    fmt.println("inv view loc: ", app_state.ts_inverse_view_loc)
    fmt.println("inv proj loc: ", app_state.ts_inverse_proj_loc)
    fmt.println("height loc: ", app_state.ts_height_loc)
    fmt.println("color loc: ", app_state.ts_color_loc)

    app_state.terrain_shader = terrain_shader
    app_state.screen_quad_vert_buff = rend.vertex_buffer_create(len(SCREEN_QUAD_VERTS) * size_of(Screen_Quad_Vert),
                                                                raw_data(SCREEN_QUAD_VERTS),
                                                                SCREEN_QUAD_VERT_ATTRIBUTES, .Static)
    app_state.screen_quad_index_buff = rend.index_buffer_create(len(SCREEN_QUAD_INDICES), .U16,
                                                                raw_data(SCREEN_QUAD_INDICES), .Static)

    app_state.cam_mode = .Free
    app_state.cam.speed = 100
    app_state.cam.pos = glsl.vec3 { 0, 100, 0 }
    app_state.cam.x_dir = glsl.vec3 { 1, 0, 0 }
    app_state.cam.y_dir = glsl.vec3 { 0, 1, 0 }
    app_state.cam.z_dir = glsl.vec3 { 0, 0, 1 }

    update_camera_matrices()

    return true
}

app_deinit :: proc() {
    rend.buffer_destroy(app_state.screen_quad_vert_buff)
    rend.buffer_destroy(app_state.screen_quad_index_buff)
    rend.graphics_pipeling_destroy(app_state.terrain_shader)
}

app_tick :: proc(app_state: ^App_State, delta_time: f32) {
    switch app_state.cam_mode {
    case .Free:
        x_dir := app_state.cam.x_dir
        y_dir := app_state.cam.y_dir
        z_dir := app_state.cam.z_dir
        local_movement := glsl.vec3 { 0, 0, 0 }
        if key_states[.W] == .Pressed || key_states[.W] == .Held {
            local_movement[2] += 1
        }
        if key_states[.A] == .Pressed || key_states[.A] == .Held {
            local_movement[0] -= 1
        }
        if key_states[.S] == .Pressed || key_states[.S] == .Held {
            local_movement[2] -= 1
        }
        if key_states[.D] == .Pressed || key_states[.D] == .Held {
            local_movement[0] += 1
        }
        if key_states[.Space] == .Pressed || key_states[.Space] == .Held {
            local_movement[1] += 1
        }
        if key_states[.Shift_L] == .Pressed || key_states[.Shift_L] == .Held {
            local_movement[1] -= 1
        }
        if glsl.length(local_movement) > 0 {
            local_movement = glsl.normalize(local_movement)
        }
        local_movement *= delta_time * app_state.cam.speed
        global_movement: glsl.vec3 = local_movement[0] * x_dir +
                                     local_movement[1] * y_dir +
                                     local_movement[2] * -z_dir
        app_state.cam.pos += global_movement
        update_camera_matrices()
    case .Orbital:
        
    case:
        panic("Illegal Camera Mode")
    }
}

app_draw :: proc(app_state: ^App_State) {
    rend.texture2d_bind(app_state.height_tex, 0)
    defer rend.texture2d_unbind(app_state.height_tex, 0)
    rend.texture2d_bind(app_state.color_tex, 1)
    defer rend.texture2d_unbind(app_state.color_tex, 1)
    rend.graphics_pipeline_set_uniform1i(app_state.ts_height_loc, 0)
    rend.graphics_pipeline_set_uniform1i(app_state.ts_color_loc, 1)

    rend.buffer_bind(app_state.screen_quad_vert_buff)
    defer rend.buffer_unbind(app_state.screen_quad_vert_buff)
    rend.buffer_bind(app_state.screen_quad_index_buff)
    defer rend.buffer_unbind(app_state.screen_quad_index_buff)

    rend.graphics_pipeline_bind(app_state.terrain_shader)
    defer rend.graphics_pipeline_bind(app_state.terrain_shader)

    rend.graphics_pipeline_set_uniform_mat4(app_state.ts_inverse_view_loc,
                                            glsl.inverse(app_state.cam.view))
    rend.graphics_pipeline_set_uniform_mat4(app_state.ts_inverse_proj_loc,
                                            glsl.inverse(app_state.cam.proj))
    //rend.graphics_pipeline_set_uniform2f(app_state.ts_screen_res_loc, SCREEN_RES.x, SCREEN_RES.y)

    rend.draw_indices(len(SCREEN_QUAD_INDICES), 0, app_state.screen_quad_index_buff.index_type)
}

update_camera_matrices :: proc() {
    pos := app_state.cam.pos
    rot := app_state.cam.rot
    //fmt.println(pos)
    // TODO: Set Proper Aspect Ratio
    aspect_ratio: f32 = 1
    proj := glsl.mat4PerspectiveInfinite(90.0, aspect_ratio, 0.1)
    pos_transform := glsl.inverse(glsl.mat4Translate(pos))
    rotation_transform := glsl.mat4FromQuat(rot)
    view := pos_transform * rotation_transform
    view_proj := view * proj 

    app_state.cam.view = view
    app_state.cam.proj = proj
    app_state.cam.view_proj = view_proj
}

