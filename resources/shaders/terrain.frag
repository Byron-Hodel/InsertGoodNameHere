#version 300 es

precision mediump float;

in vec2 tex_coord;

out vec4 col;

uniform vec2 u_screen_resolution;

uniform sampler2D u_color_map;
uniform sampler2D u_height_map;

#define MAX_DST 2048.0
#define MAX_ITERATIONS 1024
#define GRID_SCALE 1024

// uvs go from 0 to one, so scaling by 1024 should make it about the same as 0 to 1024
#define HEIGHT_SCALE_FACTOR 200.0

bool in_terrain(vec3 pos) {
    float height = texture(u_height_map, pos.xz).x;
    return pos.y <= height * HEIGHT_SCALE_FACTOR;
}

// Based on this implimentation https://www.shadertoy.com/view/4dX3zl
vec4 ray_march_terrain(vec3 ro, vec3 rd, float grid_scale) {
    vec4 col = vec4(0);
    
    rd = normalize(rd);

    ivec3 grid_pos = ivec3(floor(ro));
    ivec3 step_dir = ivec3(sign(rd));

    vec3 step_size = 1.0 / abs(rd);

    // distance to current intersection
    vec3 intersection_dst = (sign(rd) * (vec3(grid_pos) - ro) + (sign(rd) * 0.5) + 0.5) * step_size;

    for(int i = 0; i < MAX_ITERATIONS; i++) {
        vec3 pos = vec3(grid_pos) / grid_scale;
        pos.y *= grid_scale;
        if(in_terrain(pos)) {
            col = texture(u_color_map, vec2(grid_pos.xz) / grid_scale);
            return col;
        }
        bvec3 mask = lessThanEqual(intersection_dst.xyz, min(intersection_dst.yzx, intersection_dst.zxy));

        intersection_dst += vec3(mask) * step_size;
        grid_pos += ivec3(mask) * step_dir;
    }
    return col;
}

void main() {
    vec2 uv = (tex_coord.xy) * 2.0 - 1.0;
    vec3 ro = vec3(0, 100, 0);
    vec3 rd = normalize(vec3(uv.xy, 1));

    col = ray_march_terrain(ro, rd, float(GRID_SCALE));
}
