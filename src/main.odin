package main

import "core:fmt"
import "core:os"
import "core:math/linalg/glsl"
import img "core:image"
import "core:image/png"
import "core:runtime"
import "core:mem"
import "allocators"

import webgl "vendor:wasm/WebGL"
import "vendor:wasm/js"

Screen_Quad_Vert :: struct {
    pos: glsl.vec2,
    uv: glsl.vec2,
}

SCREEN_QUAD_VERT_SRC :: #load("../resources/shaders/screen_quad.vert", string)
TERRAIN_FRAG_SRC :: #load("../resources/shaders/terrain.frag", string)

TERRAIN_HEIGHT_DATA :: #load("../resources/images/D17.png", []u8)
TERRAIN_COLOR_DATA :: #load("../resources/images/C17W.png", []u8)

SCREEN_QUAD_VERTS := [4]Screen_Quad_Vert {
    { pos = { -1, -1 }, uv = { 0, 0 } },
    { pos = {  1, -1 }, uv = { 1, 0 } },
    { pos = {  1,  1 }, uv = { 1, 1 } },
    { pos = { -1,  1 }, uv = { 0, 1 } },
}
SCREEN_QUAD_INDICES := [6]u16 {
    0, 2, 1,
    0, 3, 2,
}

vao: webgl.VertexArrayObject


create_texture2d :: proc(image_bytes: []u8) -> (tex: webgl.Texture, ok: bool) {
    loaded_image, img_ok := img.load_from_bytes(image_bytes, {})
    if img_ok != nil {
        #partial switch err in img_ok {
        case img.General_Image_Error:
            fmt.eprintln("image general error: ", err)
        case img.PNG_Error:
            fmt.eprintln("image png error: ", err)
        case runtime.Allocator_Error:
            fmt.eprintln("image alloc error: ", err)
        case:
            fmt.eprintln("image error: ", err)
        }
        ok = false
        return
    }
    defer img.destroy(loaded_image)

    internal_img_fmt: webgl.Enum
    switch loaded_image.channels {
    case 1:
        internal_img_fmt = webgl.ALPHA
    case 2:
        internal_img_fmt = webgl.LUMINANCE_ALPHA
    case 3:
        internal_img_fmt = webgl.RGB
    case 4:
        internal_img_fmt = webgl.RGBA
    case:
        ok = false
        return
    }
    fmt_type := webgl.UNSIGNED_BYTE
    
    tex = webgl.CreateTexture()

    webgl.BindTexture(webgl.TEXTURE_2D, tex)
    defer webgl.BindTexture(webgl.TEXTURE_2D, 0)

    webgl.TexParameteri(webgl.TEXTURE_2D, webgl.TEXTURE_WRAP_S, i32(webgl.CLAMP_TO_EDGE))
    webgl.TexParameteri(webgl.TEXTURE_2D, webgl.TEXTURE_WRAP_T, i32(webgl.CLAMP_TO_EDGE))
    webgl.TexParameteri(webgl.TEXTURE_2D, webgl.TEXTURE_MIN_FILTER, i32(webgl.NEAREST))
    webgl.TexParameteri(webgl.TEXTURE_2D, webgl.TEXTURE_MAG_FILTER, i32(webgl.NEAREST))
    
    webgl.TexImage2D(webgl.TEXTURE_2D, 0, internal_img_fmt,
                     i32(loaded_image.width), i32(loaded_image.height),
                     0, internal_img_fmt, fmt_type, len(loaded_image.pixels.buf),
                     raw_data(loaded_image.pixels.buf))

    ok = true
    return
}

general_allocator_data: allocators.General_Allocator_Data

main :: proc() {
    fmt.println("program start!")


    // start general allocator with half a gig
    allocators.general_init(&general_allocator_data, 500000000)
    general_allocator: runtime.Allocator = {
        procedure = allocators.general_allocator_proc,
        data = &general_allocator_data,
    }
    
    context.allocator = general_allocator

    webgl.SetCurrentContextById("render-area")

    height_tex, ht_ok := create_texture2d(TERRAIN_HEIGHT_DATA)
    if !ht_ok {
        fmt.eprintln("failed to create terrain height map texture")
        return
    }
    fmt.println("loaded height map")
    color_tex, ct_ok := create_texture2d(TERRAIN_COLOR_DATA)
    if !ct_ok {
        fmt.eprintln("failed to create terrain color map texture")
        return
    }
    fmt.println("loaded color map")



    terrain_shader, ts_ok := webgl.CreateProgramFromStrings({ SCREEN_QUAD_VERT_SRC },
                                                            { TERRAIN_FRAG_SRC })
    if !ts_ok {
        fmt.eprintln("failed to compile terrain shader")
        return
    }
    webgl.BindAttribLocation(terrain_shader, 0, "pos")
    webgl.BindAttribLocation(terrain_shader, 1, "uv")

    height_location := webgl.GetUniformLocation(terrain_shader, "u_height_map")
    webgl.ActiveTexture(webgl.TEXTURE0)
    webgl.BindTexture(webgl.TEXTURE_2D, color_tex)
    webgl.Uniform1i(height_location, 0)
    


    vert_buff := webgl.CreateBuffer()
    webgl.BindBuffer(webgl.ARRAY_BUFFER, vert_buff)
    webgl.BufferData(webgl.ARRAY_BUFFER, size_of(SCREEN_QUAD_VERTS),
                     &SCREEN_QUAD_VERTS, webgl.STATIC_DRAW)
    
    index_buff := webgl.CreateBuffer()
    webgl.BindBuffer(webgl.ELEMENT_ARRAY_BUFFER, index_buff)
    webgl.BufferData(webgl.ELEMENT_ARRAY_BUFFER, size_of(SCREEN_QUAD_INDICES),
                     &SCREEN_QUAD_INDICES, webgl.STATIC_DRAW)

    

    vao = webgl.CreateVertexArray()
    webgl.BindVertexArray(vao)
    
    webgl.BindBuffer(webgl.ARRAY_BUFFER, vert_buff)
    webgl.BindBuffer(webgl.ELEMENT_ARRAY_BUFFER, index_buff)

    webgl.EnableVertexAttribArray(0)
    webgl.EnableVertexAttribArray(1)
    webgl.VertexAttribPointer(0, 3, webgl.FLOAT, false, size_of(Screen_Quad_Vert), 0)
    webgl.VertexAttribPointer(1, 2, webgl.FLOAT, false, size_of(Screen_Quad_Vert), size_of(glsl.vec3))

    webgl.UseProgram(terrain_shader)

    webgl.BindVertexArray(0)

    webgl.BindVertexArray(vao)
    webgl.DrawElements(webgl.TRIANGLES, len(SCREEN_QUAD_INDICES), webgl.UNSIGNED_SHORT, nil)
}

// the update loop.
// I would use an infinite loop in the main function,
// however, that would end terribly
@export
step :: proc(delta_time: f32) {
}
