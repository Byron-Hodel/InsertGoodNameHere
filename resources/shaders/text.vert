#version 300 es

precision mediump float;

in vec2 pos;
out vec2 tex_coord;

#define MAX_QUADS 1024

uniform mat4 view_proj;

layout(std140) uniform Instance_Data {
    vec2 origin[MAX_QUADS];
    vec2 size[MAX_QUADS];
    vec2 tex_coord[MAX_QUADS];
    vec2 tex_extent[MAX_QUADS];
} u_instance;

void main() {
    vec2 origin = u_instance.origin[gl_InstanceID];
    vec2 size = u_instance.size[gl_InstanceID];
    vec2 position = origin + pos * size;

    vec2 coord = u_instance.tex_coord[gl_InstanceID];
    vec2 extent = u_instance.tex_extent[gl_InstanceID];
    tex_coord = coord + pos * extent;

    gl_Position = vec4(position.xy, 0, 1);
}
