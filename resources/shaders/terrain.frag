#version 300 es

precision mediump float;

in vec2 tex_coord;

out vec4 col;

void main() {
    col = vec4(tex_coord.xy, 0.0, 1.0);
}
