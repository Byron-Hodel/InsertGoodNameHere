#version 300 es

precision mediump float;

in vec2 tex_coord;

out vec4 col;

uniform sampler2D u_height_map;

void main() {
    col = texture(u_height_map, tex_coord);
    //col = vec4(tex_coord.xy, 0.0, 1.0);
}
