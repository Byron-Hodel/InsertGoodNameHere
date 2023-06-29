package main

import "core:fmt"
import "core:os"
import "core:math/linalg/glsl"

import webgl "vendor:wasm/WebGL"
import "vendor:wasm/js"

Screen_Quad_Vert :: struct {
    pos: glsl.vec2,
    uv: glsl.vec2
}

SCREEN_QUAD_VERT_SRC :: #load("../resources/shaders/screen_quad.vert", string)
TERRAIN_FRAG_SRC :: #load("../resources/shaders/terrain.frag", string)

SCREEN_QUAD_VERTS := [4]Screen_Quad_Vert {
    { pos = { -1, -1 }, uv = { 0, 0 } },
    { pos = {  1, -1 }, uv = { 1, 0 } },
    { pos = {  1,  1 }, uv = { 1, 1 } },
    { pos = { -1,  1 }, uv = { 0, 1 } }
}
SCREEN_QUAD_INDICES := [6]u16 {
    0, 2, 1,
    0, 3, 2
}

vao: webgl.VertexArrayObject

main :: proc() {
    fmt.println("program start!")
    webgl.SetCurrentContextById("render-area")

    terrain_shader, ts_ok := webgl.CreateProgramFromStrings({ SCREEN_QUAD_VERT_SRC },
                                                            { TERRAIN_FRAG_SRC })
    if !ts_ok {
        fmt.eprintln("failed to compile terrain shader")
        return
    }
    webgl.BindAttribLocation(terrain_shader, 0, "pos")
    webgl.BindAttribLocation(terrain_shader, 1, "uv")

    
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
}

// the update loop.
// I would use an infinite loop in the main function,
// however, that would end terribly
@export
step :: proc(delta_time: f32) {
    webgl.BindVertexArray(vao)
    webgl.DrawElements(webgl.TRIANGLES, len(SCREEN_QUAD_INDICES), webgl.UNSIGNED_SHORT, nil)
}
