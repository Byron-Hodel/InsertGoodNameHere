#version 300 es
precision mediump float;

in vec3 pos;
in vec2 uv;
in vec4 col;
out vec4 frag_col;
out vec2 tex_coord;

// transforms ui space to screen space
uniform mat4 ortho_proj;

void main() {
    gl_Position = ortho_proj * vec4(pos, 1);
    tex_coord = uv;
    frag_col = col;
}
