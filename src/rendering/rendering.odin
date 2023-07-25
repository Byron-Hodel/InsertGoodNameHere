package rendering

import "core:image"
import "core:math/linalg/glsl"
import webgl "vendor:wasm/WebGL"

Raw_Buffer :: webgl.Buffer

Vertex_Buffer :: struct {
    raw_buffer: Raw_Buffer,
    size: int,
    vao: webgl.VertexArrayObject,
}

Index_Buffer :: struct {
    raw_buffer: Raw_Buffer,
    index_type: Index_Type,
    length: int,
}

Uniform_Buffer :: struct {
    raw_buffer: Raw_Buffer,
    size: int,
}


Buffer_Type :: enum webgl.Enum {
    Vertex = webgl.ARRAY_BUFFER,
    Index = webgl.ELEMENT_ARRAY_BUFFER,
    Uniform = webgl.UNIFORM_BUFFER,
}

Buffer_Usage :: enum webgl.Enum {
    Static = webgl.STATIC_DRAW,
    Dynamic = webgl.DYNAMIC_DRAW,
}

Index_Type :: enum webgl.Enum {
    U8 = webgl.UNSIGNED_BYTE,
    U16 = webgl.UNSIGNED_SHORT,
    U32 = webgl.UNSIGNED_INT,
}

Vertex_Attribute_Type :: enum webgl.Enum {
    I8 = webgl.BYTE,
    U8 = webgl.UNSIGNED_BYTE,
    I32 = webgl.INT,
    U32 = webgl.UNSIGNED_INT,
    F32 = webgl.FLOAT,
}

Vertex_Attribute :: struct {
    name:       string,
    location:   int,
    length:     int,
    type:       Vertex_Attribute_Type,
    normalized: bool,
    stride:     int,
    offset:     int,
}

Graphics_Pipeline :: struct {
    program: webgl.Program,
}

Texture2D :: distinct webgl.Texture

init :: proc(render_canvas_id: string) -> bool {
    return webgl.SetCurrentContextById(render_canvas_id) && webgl.IsWebGL2Supported()
}

raw_buffer_create :: proc(
    size: int,
    type: Buffer_Type,
    data: rawptr = nil,
    usage: Buffer_Usage,
) -> Raw_Buffer {
    wgl_buffer := webgl.CreateBuffer()
    buffer := Raw_Buffer(wgl_buffer)
    raw_buffer_bind(buffer, type)
    defer raw_buffer_unbind(buffer, type)
    webgl.BufferData(cast(webgl.Enum)type, size, data, cast(webgl.Enum)usage)
    return buffer
}

raw_buffer_destroy :: proc(buffer: Raw_Buffer) {
    webgl.DeleteBuffer(buffer)
}

raw_buffer_set_data :: proc(buffer: Raw_Buffer, type: Buffer_Type, size: int, data: rawptr, offset: uintptr) {
    raw_buffer_bind(buffer, type)
    defer raw_buffer_unbind(buffer, type)
    webgl.BufferSubData(cast(webgl.Enum)type, offset, size, data)
}

raw_buffer_bind :: proc(buffer: Raw_Buffer, type: Buffer_Type) {
    webgl.BindBuffer(cast(webgl.Enum)type, buffer)
}

raw_buffer_unbind :: proc(buffer: Raw_Buffer, type: Buffer_Type) {
    webgl.BindBuffer(cast(webgl.Enum)type, 0)
}


vertex_buffer_create :: proc(
    size: int,
    data: rawptr,
    attribs: []Vertex_Attribute, 
    usage: Buffer_Usage,
) -> Vertex_Buffer {

    raw_buffer := raw_buffer_create(size, .Vertex, data, usage)
    vao := webgl.CreateVertexArray()
    webgl.BindVertexArray(vao)

    buffer_bind(raw_buffer, Buffer_Type.Vertex)
    defer buffer_unbind(raw_buffer, Buffer_Type.Vertex)

    for a in attribs {
        webgl.EnableVertexAttribArray(i32(a.location))
        webgl.VertexAttribPointer(i32(a.location), a.length, cast(webgl.Enum)a.type,
                                  a.normalized, a.stride, uintptr(a.offset))
    }

    webgl.BindVertexArray(0)
    for a in attribs {
        webgl.DisableVertexAttribArray(0)
    }

    return Vertex_Buffer {
        raw_buffer = raw_buffer,
        size = size,
        vao = vao,
    }
}

vertex_buffer_destroy :: proc(buffer: Vertex_Buffer) {
    raw_buffer_destroy(buffer.raw_buffer)
}

vertex_buffer_set_data :: proc(buffer: Vertex_Buffer, size: int, data: rawptr, offset: uintptr) {
    raw_buffer_set_data(buffer.raw_buffer, .Vertex, size, data, offset)
}

vertex_buffer_bind :: proc(buffer: Vertex_Buffer) {
    webgl.BindVertexArray(buffer.vao)
    webgl.BindBuffer(webgl.ARRAY_BUFFER, buffer.raw_buffer)
}

vertex_buffer_unbind :: proc(buffer: Vertex_Buffer) {
    webgl.BindVertexArray(0)
    webgl.BindBuffer(webgl.ARRAY_BUFFER, 0)
}

index_buffer_create :: proc(
    length: int,
    index_type: Index_Type,
    data: rawptr,
    usage: Buffer_Usage,
) -> Index_Buffer {
    index_size: int
    switch index_type {
    case .U8:
        index_size = 1
    case .U16:
        index_size = 2
    case .U32:
        index_size = 4
    case:
        panic("Invalid Index Type")
    }
    return Index_Buffer {
        raw_buffer = raw_buffer_create(length * index_size, .Index, data, usage),
        index_type = index_type,
        length = length * index_size,
    }
}

index_buffer_destroy :: proc(buffer: Index_Buffer) {
    raw_buffer_destroy(buffer.raw_buffer)
}

index_buffer_set_data :: proc(buffer: Index_Buffer, length: int, data: rawptr, offset: uintptr) {
    index_size: int
    switch buffer.index_type {
    case .U8:
        index_size = 1
    case .U16:
        index_size = 2
    case .U32:
        index_size = 4
    case:
        panic("Invalid Index Type")
    }
    raw_buffer_set_data(buffer.raw_buffer, .Index, length * index_size, data, offset)
}

index_buffer_bind :: proc(buffer: Index_Buffer) {
    webgl.BindBuffer(webgl.ELEMENT_ARRAY_BUFFER, buffer.raw_buffer)
}


index_buffer_unbind :: proc(buffer: Index_Buffer) {
    webgl.BindBuffer(webgl.ELEMENT_ARRAY_BUFFER, 0)
}

uniform_buffer_create :: proc(
    size: int,
    data: rawptr,
    usage: Buffer_Usage,
) -> Uniform_Buffer {
    return Uniform_Buffer {
        raw_buffer = raw_buffer_create(size, .Uniform, data, usage),
        size = size,
    }
}

uniform_buffer_destroy :: proc(buffer: Uniform_Buffer) {
    raw_buffer_destroy(buffer.raw_buffer)
}

uniform_buffer_bind :: proc(buffer: Uniform_Buffer, binding: i32) {
    webgl.BindBufferBase(webgl.UNIFORM_BUFFER, binding, buffer.raw_buffer)
}

uniform_buffer_unbind :: proc(buffer: Uniform_Buffer, binding: i32) {
    webgl.BindBufferBase(webgl.UNIFORM_BUFFER, 0, buffer.raw_buffer)
}

uniform_buffer_set_data :: proc(buffer: Uniform_Buffer, size: int, data: rawptr, offset: uintptr) {
    raw_buffer_set_data(buffer.raw_buffer, .Uniform, size, data, offset)
}

buffer_destroy :: proc {
    vertex_buffer_destroy,
    index_buffer_destroy,
    uniform_buffer_destroy,
    raw_buffer_destroy,
}

buffer_bind :: proc {
    vertex_buffer_bind,
    index_buffer_bind,
    uniform_buffer_bind,
    raw_buffer_bind,
}

buffer_unbind:: proc {
    vertex_buffer_unbind,
    index_buffer_unbind,
    uniform_buffer_unbind,
    raw_buffer_unbind,
}

buffer_set_data :: proc {
    vertex_buffer_set_data,
    index_buffer_set_data,
    uniform_buffer_set_data,
    raw_buffer_set_data,
}


graphics_pipeline_create :: proc(
    vert_src: string,
    frag_src: string,
    vertex_layout: []Vertex_Attribute,
) -> (Graphics_Pipeline, bool) {
    program, ok := webgl.CreateProgramFromStrings({vert_src}, {frag_src})
    if !ok {
        return {}, false
    }
    
    for vl in vertex_layout {
        webgl.BindAttribLocation(program, i32(vl.location), vl.name)
    }

    return Graphics_Pipeline {
        program = program,
    }, true 
}

graphics_pipeling_destroy :: proc(pipeline: Graphics_Pipeline) {
    webgl.DeleteProgram(pipeline.program)
}

graphics_pipeline_get_ubuffer_location :: proc(pipeline: Graphics_Pipeline, name: string) -> i32 {
    return webgl.GetUniformBlockIndex(pipeline.program, name)
}

graphics_pipeline_get_uniform_location :: proc(pipeline: Graphics_Pipeline, name: string) -> i32 {
    return webgl.GetUniformLocation(pipeline.program, name)
}

graphics_pipeline_set_uniform2f :: proc(location: i32, v0, v1: f32) {
    webgl.Uniform2f(location, v0, v1)
}

graphics_pipeline_set_uniform1i :: proc(location: i32, v: i32) {
    webgl.Uniform1i(location, v)
}

graphics_pipeline_set_uniform_mat4 :: proc(location: i32, mat: glsl.mat4) {
    webgl.UniformMatrix4fv(location, mat)
}

graphics_pipeline_bind :: proc(pipeline: Graphics_Pipeline) {
    webgl.UseProgram(pipeline.program)
}

graphics_pipeline_unbind :: proc(pipeline: Graphics_Pipeline) {
    webgl.UseProgram(0)
}

// webgl.BindAttribLocation(program, i32(attrib.location), attrib.name)


create_texture2d :: proc(img: ^image.Image) -> Texture2D {
    internal_img_fmt: webgl.Enum
    switch img.channels {
    case 1:
        internal_img_fmt = webgl.ALPHA
    case 2:
        internal_img_fmt = webgl.LUMINANCE_ALPHA
    case 3:
        internal_img_fmt = webgl.RGB
    case 4:
        internal_img_fmt = webgl.RGBA
    case:
        return {}
    }
    fmt_type := webgl.UNSIGNED_BYTE
    
    tex := webgl.CreateTexture()

    webgl.BindTexture(webgl.TEXTURE_2D, tex)
    defer webgl.BindTexture(webgl.TEXTURE_2D, 0)

    webgl.TexParameteri(webgl.TEXTURE_2D, webgl.TEXTURE_WRAP_S, i32(webgl.REPEAT))
    webgl.TexParameteri(webgl.TEXTURE_2D, webgl.TEXTURE_WRAP_T, i32(webgl.REPEAT))
    webgl.TexParameteri(webgl.TEXTURE_2D, webgl.TEXTURE_MIN_FILTER, i32(webgl.LINEAR))
    webgl.TexParameteri(webgl.TEXTURE_2D, webgl.TEXTURE_MAG_FILTER, i32(webgl.LINEAR))
    
    webgl.TexImage2D(webgl.TEXTURE_2D, 0, internal_img_fmt,
                     i32(img.width), i32(img.height),
                     0, internal_img_fmt, fmt_type, len(img.pixels.buf),
                     raw_data(img.pixels.buf))

    return cast(Texture2D)tex
}

// TODO: create destroy texture proc

texture2d_bind :: proc(tex: Texture2D, tex_coord: i32) {
    gl_coord: i32 = i32(webgl.TEXTURE0) + tex_coord
    webgl.ActiveTexture(cast(webgl.Enum)gl_coord)
    webgl.BindTexture(webgl.TEXTURE_2D, cast(webgl.Texture)tex)
}

texture2d_unbind :: proc(tex: Texture2D, tex_coord: i32) {
    gl_coord: i32 = i32(webgl.TEXTURE0) + tex_coord
    webgl.ActiveTexture(cast(webgl.Enum)gl_coord)
    webgl.BindTexture(webgl.TEXTURE_2D, 0)
}


draw_indices :: proc(count: int, offset: uintptr, index_type: Index_Type) {
    webgl.DrawElements(webgl.TRIANGLES, count, cast(webgl.Enum)index_type, rawptr(offset))
}

draw_indices_instanced :: proc(count: int, offset: int, index_type: Index_Type, instances: int) {
    webgl.DrawElementsInstanced(webgl.TRIANGLES, count,
                                cast(webgl.Enum)index_type,
                                offset, instances)
}
