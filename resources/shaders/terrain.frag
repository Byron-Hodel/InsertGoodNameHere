#version 300 es

precision mediump float;

in vec2 tex_coord;

out vec4 col;

uniform vec2 u_screen_resolution;

uniform sampler2D u_color_map;
uniform sampler2D u_height_map;

#define MAX_DST 2048.0
#define MAX_ITERATIONS 512

// uvs go from 0 to one, so scaling by 1024 should make it about the same as 0 to 1024
#define SCALE_FACTOR 2048
#define HEIGHT_SCALE_FACTOR 200.0

void main() {
    vec2 uv = (tex_coord.xy) * 2.0 - 1.0;
    vec3 ro = vec3(0, 100, 0);
    vec3 rd = normalize(vec3(uv.xy, 1));

    float t = float(0.0);
    int i;
    for(i = 0; i < MAX_ITERATIONS && t < MAX_DST; i++) {
        vec3 pos = t * rd + ro;
        vec2 sample_uv = vec2(pos.xz) / float(SCALE_FACTOR);
        float terrain_height = texture(u_height_map, sample_uv).x * HEIGHT_SCALE_FACTOR;
        if(pos.y <= terrain_height) {
            col = texture(u_color_map, sample_uv);
            break;
        }
        t += 0.01 * float(i+1);
    }
    if(i >= MAX_ITERATIONS || t >= MAX_DST) {
        col = vec4(rd, 1);
    }
}
