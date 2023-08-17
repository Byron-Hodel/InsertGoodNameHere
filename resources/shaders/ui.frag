#version 300 es
precision mediump float;

in vec2 frag_coord;
in vec4 frag_col;
out vec4 col;

void main() {
    col = frag_col;
}
