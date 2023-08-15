package main

import "core:fmt"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "core:image"
import "core:image/png"

import rend "rendering"
import webgl "vendor:wasm/WebGL"

// TODO: change screen res to not be hard coded
// TODO: Set Proper Aspect Ratio when updating camera matrices

Terrain_Scene :: struct {
    ui_layer: Ui_Layer,
    terrain_layer: Terrain_Layer,
    terrain_key_states: [Key_Id]Key_State,
    terrain_cam: Camera,
    
    test_btn: Ui_Button,
    test_slider: Ui_Slider,
}

Screen_Quad_Vert :: struct {
    pos: glsl.vec2,
    uv: glsl.vec2,
}

Camera :: struct {
    pos: glsl.vec3,
    rot: glsl.quat,
    speed: f32,

    pitch: f32,
    yaw: f32,

    right: glsl.vec3,
    up: glsl.vec3,
    forward: glsl.vec3,

    view: glsl.mat4,
    proj: glsl.mat4,
}

Terrain_Layer :: struct {
    screen_quad_vert_buf: rend.Vertex_Buffer,
    screen_quad_index_buf: rend.Index_Buffer,
    terrain_shader: rend.Graphics_Pipeline,
    ts_inverse_view_loc: i32, 
    ts_inverse_proj_loc: i32, 
    ts_height_loc: i32, 
    ts_color_loc: i32, 
    ts_sky_loc: i32,

    height_tex: rend.Texture2D,
    color_tex: rend.Texture2D,
    skybox: rend.Texture2D,
}

Terrain_Scene_Ui_Ids :: enum i32 {
    Test_Button,
    Test_Slider,
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

SCREEN_QUAD_VERT_SRC :: #load("../resources/shaders/screen_quad.vert", string)
TERRAIN_FRAG_SRC :: #load("../resources/shaders/terrain.frag", string)

MAP_HEIGHT_PNG :: #load("../resources/images/D1.png", []u8)
MAP_COLOR_PNG :: #load("../resources/images/C1W.png", []u8)
SKYBOX_PNG :: #load("../resources/images/skybox.png", []u8)

terrain_scene_init :: proc(scene: ^Terrain_Scene) -> bool {
    ui_layer_init(&scene.ui_layer) or_return
    terrain_layer_init(&scene.terrain_layer) or_return
    
    scene.terrain_cam.pos = glsl.vec3 { 0, 32, 0 }
    scene.terrain_cam.rot = quaternion(1, 0, 0, 0)
    scene.terrain_cam.speed = 25
    scene.terrain_cam.right = glsl.vec3 { 1, 0, 0 }
    scene.terrain_cam.up = glsl.vec3 { 0, 1, 0 }
    scene.terrain_cam.forward = glsl.vec3 { 0, 0, 1 }
    update_camera_matrices(&scene.terrain_cam)

    ui_button_init(&scene.test_btn, i32(Terrain_Scene_Ui_Ids.Test_Button))
    //ui_layer_add_element(&scene.ui_layer, scene.test_btn)

    return true
}

terrain_scene_deinit :: proc(scene: ^Terrain_Scene) {
    terrain_layer_deinit(&scene.terrain_layer)
}

terrain_scene_on_event :: proc(scene: ^Terrain_Scene, event: Event) {
    // pressed and released are set for only one frame, then changed the next
    for id in Key_Id {
        if scene.terrain_key_states[id] == .Pressed {
            scene.terrain_key_states[id] = .Held
        }
        else if scene.terrain_key_states[id] == .Released {
            scene.terrain_key_states[id] = .None
        }
    }
    if !ui_layer_on_event(&scene.ui_layer, event) {
        key_event, is_key_event := event.(Key_Event)
        if is_key_event && key_event.new_state != .Held {
            scene.terrain_key_states[key_event.id] = key_event.new_state
        }
    }
}

terrain_scene_update :: proc(scene: ^Terrain_Scene, delta_time: f32, scroll_delta: f32) {
    key_states := scene.terrain_key_states
    //layer.cam.pitch += mouse_delta.y * delta_time
    //layer.cam.yaw += mouse_delta.x * delta_time
    if key_states[.Left] == .Pressed || key_states[.Left] == .Held {
        scene.terrain_cam.yaw -= 1 * delta_time
    }
    if key_states[.Right] == .Pressed || key_states[.Right] == .Held {
        scene.terrain_cam.yaw += 1 * delta_time
    }
    if key_states[.Up] == .Pressed || key_states[.Up] == .Held {
        scene.terrain_cam.pitch -= 1 * delta_time
    }
    if key_states[.Down] == .Pressed || key_states[.Down] == .Held {
        scene.terrain_cam.pitch += 1 * delta_time
    }

    scene.terrain_cam.speed += scroll_delta * 10 * delta_time

    yaw_quat: glsl.quat = glsl.quatAxisAngle({0,1,0}, scene.terrain_cam.yaw)
    forward := rotate(yaw_quat, {0, 0, 1})
    right: glsl.vec3 = glsl.cross(glsl.vec3 {0, 1, 0}, forward)

    pitch_quat: glsl.quat = glsl.quatAxisAngle(right, -scene.terrain_cam.pitch)
    cam_rot: glsl.quat = pitch_quat * yaw_quat
    
    forward = rotate(pitch_quat, forward)
    up: glsl.vec3 = glsl.cross(forward, right)

    scene.terrain_cam.rot = cam_rot
    scene.terrain_cam.right = right
    scene.terrain_cam.up = up
    scene.terrain_cam.forward = forward

    local_movement := glsl.vec3 { 0, 0, 0 }
    if key_states[.W] == .Pressed || key_states[.W] == .Held {
        local_movement.z += 1
    }
    if key_states[.A] == .Pressed || key_states[.A] == .Held {
        local_movement.x -= 1
    }
    if key_states[.S] == .Pressed || key_states[.S] == .Held {
        local_movement.z -= 1
    }
    if key_states[.D] == .Pressed || key_states[.D] == .Held {
        local_movement.x += 1
    }
    if key_states[.Space] == .Pressed || key_states[.Space] == .Held {
        local_movement.y += 1
    }
    if key_states[.Shift_L] == .Pressed || key_states[.Shift_L] == .Held {
        local_movement.y -= 1
    }
    if glsl.length(local_movement) > 0 {
        local_movement = glsl.normalize(local_movement)
    }
    local_movement *= delta_time * scene.terrain_cam.speed
    global_movement: glsl.vec3 = local_movement.x * scene.terrain_cam.right +
                                 local_movement.y * glsl.vec3 {0, 1, 0} +
                                 local_movement.z * scene.terrain_cam.forward
    scene.terrain_cam.pos += global_movement
    update_camera_matrices(&scene.terrain_cam)
}

terrain_scene_draw :: proc(scene: ^Terrain_Scene) {
    terrain_layer_draw(&scene.terrain_layer, scene.terrain_cam)
    ui_layer_draw(&scene.ui_layer, { 900, 900 })
}



terrain_layer_init :: proc(layer: ^Terrain_Layer) -> bool {
    height_img, height_err := png.load_from_bytes(MAP_HEIGHT_PNG)
    color_img, color_err := png.load_from_bytes(MAP_COLOR_PNG)
    sky_img, sky_err := png.load_from_bytes(SKYBOX_PNG)
    defer image.destroy(height_img)
    defer image.destroy(color_img)
    defer image.destroy(sky_img)

    if height_err != nil {
        fmt.eprintln("Failed To Load Height Map: ", height_err)
    }
    if color_err != nil {
        fmt.eprintln("Failed To Load Height Map: ", height_err)
    }
    if sky_err != nil {
        fmt.eprintln("Failed To Load Skybox: ", sky_err)
    }

    layer.height_tex = rend.create_texture2d(height_img)
    layer.color_tex = rend.create_texture2d(color_img)
    layer.skybox = rend.create_texture2d(sky_img)

    terrain_shader, ts_ok := rend.graphics_pipeline_create(SCREEN_QUAD_VERT_SRC, TERRAIN_FRAG_SRC,
                                                           SCREEN_QUAD_VERT_ATTRIBUTES)

    if !ts_ok {
        return false
    }

    //layer.ts_screen_res_loc = rend.graphics_pipeline_get_uniform_location(terrain_shader,
    //                                                                          "u_screen_resolution")
    layer.ts_inverse_view_loc = rend.graphics_pipeline_get_uniform_location(terrain_shader,
                                                                            "u_inverse_view")
    layer.ts_inverse_proj_loc = rend.graphics_pipeline_get_uniform_location(terrain_shader,
                                                                            "u_inverse_proj")
    layer.ts_height_loc = rend.graphics_pipeline_get_uniform_location(terrain_shader, "u_height_map")
    layer.ts_color_loc = rend.graphics_pipeline_get_uniform_location(terrain_shader, "u_color_map")
    layer.ts_sky_loc = rend.graphics_pipeline_get_uniform_location(terrain_shader, "u_skybox")

    layer.terrain_shader = terrain_shader
    layer.screen_quad_vert_buf = rend.vertex_buffer_create(len(SCREEN_QUAD_VERTS) * size_of(Screen_Quad_Vert),
                                                           raw_data(SCREEN_QUAD_VERTS),
                                                           SCREEN_QUAD_VERT_ATTRIBUTES, .Static)
    layer.screen_quad_index_buf = rend.index_buffer_create(len(SCREEN_QUAD_INDICES), .U16,
                                                           raw_data(SCREEN_QUAD_INDICES), .Static)

    return true
}

terrain_layer_deinit :: proc(layer: ^Terrain_Layer) {
    rend.buffer_destroy(layer.screen_quad_vert_buf)
    rend.buffer_destroy(layer.screen_quad_index_buf)
    rend.graphics_pipeling_destroy(layer.terrain_shader)
}

terrain_layer_draw :: proc(layer: ^Terrain_Layer, cam: Camera) {
    rend.bind(layer.terrain_shader)
    defer rend.unbind(layer.terrain_shader)

    rend.bind(layer.height_tex, 0)
    defer rend.unbind(layer.height_tex, 0)
    rend.bind(layer.color_tex, 1)
    defer rend.unbind(layer.color_tex, 1)
    rend.bind(layer.skybox, 2)
    defer rend.unbind(layer.color_tex, 2)
    rend.graphics_pipeline_set_uniform1i(layer.ts_height_loc, 0)
    rend.graphics_pipeline_set_uniform1i(layer.ts_color_loc, 1)
    rend.graphics_pipeline_set_uniform1i(layer.ts_sky_loc, 2)

    rend.graphics_pipeline_set_uniform_mat4(layer.ts_inverse_view_loc,
                                            glsl.inverse(cam.view))
    rend.graphics_pipeline_set_uniform_mat4(layer.ts_inverse_proj_loc,
                                            glsl.inverse(cam.proj))
    //rend.graphics_pipeline_set_uniform2f(layer.ts_screen_res_loc, SCREEN_RES.x, SCREEN_RES.y)

    rend.draw_indices(0, layer.screen_quad_vert_buf, layer.screen_quad_index_buf)
}

update_camera_matrices :: proc(cam: ^Camera) {
    aspect_ratio: f32 = 1

    pos_mat := glsl.mat4Translate(-cam.pos)
    rotation_mat := glsl.mat4FromQuat(glsl.inverse(cam.rot))
    view := rotation_mat * pos_mat

    proj := glsl.mat4PerspectiveInfinite(90.0, aspect_ratio, 0.1)
    view_proj := proj * view

    // used to flip camera direction from -z to +z
    invert_z_mat :: glsl.mat4 {
        1, 0,  0, 0,
        0, 1,  0, 0,
        0, 0, -1, 0,
        0, 0,  0, 1,
    }

    cam.view = view
    cam.proj = proj * invert_z_mat
}

rotate_vec3_axis :: proc(radians: f32, axis, vec: glsl.vec3) -> glsl.vec3 {
    hs: f32 = glsl.sin(radians / 2.0)
    hc: f32 = glsl.cos(radians / 2.0)
    rot_quat: glsl.quat = quaternion(hc, hs * axis.x, hs * axis.y, hs * axis.z)
    inverse_rot_quat := glsl.inverse(rot_quat)
    vec_quat: glsl.quat = quaternion(0, vec.x, vec.y, vec.z)
    result := rot_quat * vec_quat * inverse_rot_quat
    return glsl.vec3 { result.x, result.y, result.z }
}

rotate_vec3 :: proc(rot_quat: glsl.quat, vec: glsl.vec3) -> glsl.vec3 {
    inverse_rot_quat := glsl.inverse(rot_quat)
    vec_quat: glsl.quat = quaternion(0, vec.x, vec.y, vec.z)
    result := rot_quat * vec_quat * inverse_rot_quat
    return glsl.vec3 { result.x, result.y, result.z }
}

rotate :: proc {rotate_vec3, rotate_vec3_axis}
