shader_type spatial;
render_mode cull_disabled;

// Briznas opacas de Duelo de Sables adaptadas al relieve de Terrain3D.
// Sólo el color viaja al fragmento: sin recorte alfa ni texturas por píxel.
uniform sampler2DArray ground_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 ground_tint : source_color = vec4(0.72, 0.88, 0.58, 1.0);
uniform float ground_scale = 0.0275;
uniform bool geometric_blade = true;
uniform bool skip_hidden_work = true;
uniform float density_distance = 6.0;
uniform float max_width_scale = 1.8;
uniform float breeze_strength = 0.055;
uniform float gust_strength = 0.19;
uniform float storm_bend = 0.0;
uniform vec3 player_position = vec3(0.0, -10000.0, 0.0);
uniform float interaction_radius = 1.35;
uniform vec3 shockwave_position = vec3(0.0, -10000.0, 0.0);
uniform float shockwave_radius = 0.0;
uniform float shockwave_strength = 0.0;
uniform float lod_role = 0.0;
uniform float full_fade_start = 16.0;
uniform float full_fade_end = 28.0;
uniform float proxy_fade_start = 16.0;
uniform float proxy_fade_end = 28.0;
uniform float mid_fade_out_start = 120.0;
uniform float mid_fade_out_end = 160.0;
uniform float proxy_far_fade_start = 210.0;
uniform float proxy_far_fade_end = 260.0;
uniform float terrain_follow = 0.0;
uniform float ground_sink = -0.025;
uniform float _vertex_density = 1.0;
uniform float _region_size = 1024.0;
uniform float _region_texel_size = 0.0009765625;
uniform int _region_map_size = 32;
uniform int _region_map[1024];
uniform highp sampler2DArray _height_maps : repeat_disable, filter_linear;
uniform highp sampler2DArray _color_maps : source_color, repeat_disable, filter_linear;
uniform sampler2D urban_mask : filter_nearest, repeat_disable;
uniform bool use_urban_mask = false;
uniform highp sampler2DArray _control_maps : repeat_disable, filter_nearest;
varying vec3 blade_color;

ivec3 terrain_index_coord(vec2 grid) {
	vec2 texel_position = floor(grid);
	ivec2 region = ivec2(floor(texel_position * _region_texel_size)) + ivec2(_region_map_size / 2);
	bool valid = all(greaterThanEqual(region, ivec2(0))) && all(lessThan(region, ivec2(_region_map_size)));
	ivec2 safe_region = clamp(region, ivec2(0), ivec2(_region_map_size - 1));
	int layer = valid ? _region_map[safe_region.y * _region_map_size + safe_region.x] - 1 : -1;
	return ivec3(ivec2(mod(texel_position, _region_size)), layer);
}

float root_random(vec2 root, float seed) {
	return fract(sin(dot(root, vec2(12.9898, 78.233)) + seed) * 43758.5453);
}

void vertex() {
	mat3 inverse_model_basis = inverse(mat3(MODEL_MATRIX));
	vec3 local_root = geometric_blade ? vec3(UV2.x, -0.08, UV2.y) : vec3(VERTEX.x, 0.0, VERTEX.z);
	vec3 world_root = (MODEL_MATRIX * vec4(local_root, 1.0)).xyz;
	float camera_distance = length(world_root.xz - CAMERA_POSITION_WORLD.xz);
	float fade = 1.0 - smoothstep(full_fade_start, full_fade_end, camera_distance);
	if (lod_role > 1.5) {
		fade = smoothstep(proxy_fade_start, proxy_fade_end, camera_distance)
			* (1.0 - smoothstep(mid_fade_out_start, mid_fade_out_end, camera_distance));
	} else if (lod_role > 0.5) {
		fade = smoothstep(mid_fade_out_start, mid_fade_out_end, camera_distance)
			* (1.0 - smoothstep(proxy_far_fade_start, proxy_far_fade_end, camera_distance));
	}
	// El sorteo es fijo en el mundo. El ancho tiene límite: compensarlo por
	// completo convertía las hojas lejanas en triángulos de más de tres metros.
	float fraction = clamp(pow(density_distance / max(camera_distance, density_distance), 2.0), 0.04, 1.0);
	bool alive = root_random(world_root.xz, lod_role * 17.0) < fade
		&& root_random(world_root.xz, 71.7) < fraction;
	// Las hojas retiradas no necesitan leer cuatro mapas ni calcular viento.
	// El control de coste vive en la captura, nunca en una partida normal.
	if (alive || !skip_hidden_work) {
		vec2 grid = world_root.xz * _vertex_density;
		ivec3 index = terrain_index_coord(grid);
		vec2 terrain_uv = (mod(grid, _region_size) + vec2(0.5)) / _region_size;
		vec3 map_color = vec3(1.0);
		float green_weight = 1.0;
		if (index.z >= 0) {
			if (terrain_follow > 0.5) {
				world_root.y = textureLod(_height_maps, vec3(terrain_uv, float(index.z)), 0.0).r + ground_sink;
			}
			map_color = textureLod(_color_maps, vec3(terrain_uv, float(index.z)), 0.0).rgb;
			uint control = floatBitsToUint(texelFetch(_control_maps, index, 0).r);
			float blend = float((control >> 14u) & 255u) / 255.0;
			float base_green = ((control >> 27u) & 31u) == 0u ? 1.0 : 0.0;
			float over_green = ((control >> 22u) & 31u) == 0u ? 1.0 : 0.0;
			green_weight = mix(base_green, over_green, blend);
			if ((control & 4u) != 0u) { green_weight = 0.0; }
		}
		float urban = use_urban_mask ? textureLod(urban_mask, (world_root.xz + vec2(6000.0)) / 12000.0, 0.0).r : 1.0;
		fade *= smoothstep(0.45, 0.85, green_weight) * urban;
		alive = alive && root_random(world_root.xz, lod_role * 17.0) < fade;
		vec3 offset = VERTEX - local_root;
		offset.xz *= min(inversesqrt(fraction), max_width_scale);
		vec2 wind_direction = normalize(vec2(0.84, 0.54));
		float wave_position = dot(world_root.xz, wind_direction);
		float spatial_phase = world_root.x * 0.006 + world_root.z * 0.004;
		float soft_gust = smoothstep(0.56, 0.91, sin(TIME * 0.36 - spatial_phase) * 0.5 + 0.5);
		float strong_gust = smoothstep(0.84, 0.985, sin(TIME * 0.095 - spatial_phase * 0.43 + 1.7) * 0.5 + 0.5);
		float travelling_wave = sin(wave_position * 0.052 - TIME * (0.92 + strong_gust * 0.34));
		float fine_wave = sin(wave_position * 0.137 - TIME * 1.64 + soft_gust * 1.2);
		float height_mask = UV.y;
		float bend = (breeze_strength + gust_strength * (soft_gust * 0.38 + strong_gust * 1.08))
			* (travelling_wave * 0.78 + fine_wave * 0.22) * height_mask;
		float storm_wave = sin(wave_position * 0.11 - TIME * 5.2) * 0.5 + sin(wave_position * 0.27 - TIME * 8.9) * 0.5;
		bend += storm_bend * (0.62 + storm_wave * 0.38) * height_mask;
		offset += inverse_model_basis * vec3(wind_direction.x, 0.0, wind_direction.y) * bend;
		offset.y -= storm_bend * 0.34 * height_mask;
		vec2 player_delta = world_root.xz - player_position.xz;
		float player_distance = length(player_delta);
		float interaction = (1.0 - smoothstep(interaction_radius * 0.28, interaction_radius, player_distance))
			* (1.0 - smoothstep(0.8, 2.0, abs(player_position.y - world_root.y)));
		vec2 outward = player_delta / max(player_distance, 0.001);
		vec3 local_outward = inverse_model_basis * vec3(outward.x, 0.0, outward.y);
		offset += local_outward * interaction * 0.52 * height_mask;
		offset.y -= interaction * 0.13 * height_mask;
		vec2 blast_delta = world_root.xz - shockwave_position.xz;
		float blast_distance = length(blast_delta);
		float blast = shockwave_strength * (1.0 - smoothstep(max(shockwave_radius, 0.01) * 0.30, max(shockwave_radius, 0.01), blast_distance));
		offset += inverse_model_basis * vec3(blast_delta.x, 0.0, blast_delta.y) / max(blast_distance, 0.001) * blast * 1.15 * height_mask;
		offset.y -= blast * 0.62 * height_mask;
		VERTEX = inverse_model_basis * (world_root - MODEL_MATRIX[3].xyz) + (alive ? offset : vec3(0.0));
		vec3 ground = textureLod(ground_texture, vec3(world_root.xz * ground_scale + vec2(0.5), 0.0), 1.0).rgb * ground_tint.rgb * map_color;
		blade_color = ground * mix(0.78, 1.10, height_mask) * (1.0 + soft_gust * 0.10);
	} else {
		VERTEX = local_root;
		blade_color = vec3(0.0);
	}
}

void fragment() {
	vec3 face_normal = FRONT_FACING ? NORMAL : -NORMAL;
	// El cielo ilumina ambas caras sin convertir las hojas a contraluz en neón.
	vec3 up = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	NORMAL = normalize(mix(face_normal, up, 0.55));
	ALBEDO = blade_color;
	ROUGHNESS = 0.98;
	SPECULAR = 0.08;
}
