#version 300 es

precision mediump float;

in vec2 pos;
in vec2 uv;

out vec2 tex_coord;

void main() {
    tex_coord = uv;
    gl_Position = vec4(pos, 0, 1.0);
}
