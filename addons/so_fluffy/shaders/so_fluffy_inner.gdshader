// Simplified Inner Shell Shader
// Optimized for performance - used for inner shells (< 60% height)
// Removes expensive features: emission, curls, detailed turbulence

shader_type spatial;
render_mode cull_disabled;

// Core parameters
uniform float height = 0.0;
uniform float normal_strength = 1.0;
uniform vec3 static_direction_local = vec3(0.0, 0.0, 0.0);
uniform vec3 static_direction_world = vec3(0.0, 0.0, 0.0);
uniform float h = 0.0;
uniform float density = 1.0;
uniform bool render_skin = true;
uniform int seed = 0;
uniform float scruffiness = 0.5;

// Texture atlas (R=heightmap, G=turbulence, B=jitter, A=unused)
uniform sampler2D texture_atlas : source_color, filter_linear;
uniform bool use_texture_atlas = false;

// Individual textures (fallback)
uniform sampler2D heightmap_texture : source_color, filter_nearest;
uniform bool use_heightmap_texture = false;

// Simplified turbulence (no jitter in inner shells)
uniform float turbulence_strength = 0.0;

// Thickness
uniform sampler2D thickness_curve;
uniform bool use_thickness_curve = false;
uniform float thickness_scale = 1.0;

// Appearance (simplified - no emission)
uniform vec3 color : source_color;
uniform sampler2D height_gradient : source_color, filter_nearest;
uniform bool use_height_gradient = false;
uniform bool scale_height_gradient = true;
uniform bool use_albedo_texture = false;
uniform sampler2D albedo_texture : source_color;

// Physics (Momentum-based)
uniform vec3 physics_pos_offset = vec3(0.0, 0.0, 0.0);
uniform mat3 physics_rot_offset;

// Interactive Physics (Collision-based)
uniform bool interactive_physics_enabled = false;
uniform vec3 interactive_displacement = vec3(0.0, 0.0, 0.0);
uniform float interactive_compression = 0.5;

// Gold Noise - fast procedural noise
float gold_noise(vec2 p) {
	p = p + vec2(float(seed), float(seed));
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	// Physics offset in world space (momentum-based)
	vec3 physics_pos_offset_world = (vec4(physics_pos_offset, 0.0) * MODEL_MATRIX).xyz * h * 0.2;

	// Interactive physics offset (collision-based)
	vec3 interactive_offset = vec3(0.0);
	if (interactive_physics_enabled) {
		interactive_offset = (vec4(interactive_displacement, 0.0) * MODEL_MATRIX).xyz * h * h;
		float compression_factor = 1.0 - (length(interactive_displacement) * interactive_compression * h);
		compression_factor = max(compression_factor, 0.5);
		height *= compression_factor;
	}

	// Growth direction blend
	vec3 direction = static_direction_local + (vec4(static_direction_world, 0.0) * MODEL_MATRIX).xyz;

	// Displace vertex
	VERTEX += (NORMAL * normal_strength + direction * (1.0 - normal_strength)) * height * h + physics_pos_offset_world + interactive_offset;
	VERTEX = VERTEX * physics_rot_offset;
}

void fragment() {
	vec2 uv = UV * density;
	vec2 xy = uv;

	// Simplified turbulence (only if needed and using atlas)
	if (turbulence_strength > 0.0) {
		vec2 turbulence;
		if (use_texture_atlas) {
			turbulence = texture(texture_atlas, uv).gb - vec2(0.5, 0.5);
		} else {
			// No turbulence for inner shells without atlas
			turbulence = vec2(0.0, 0.0);
		}

		vec2 displacement = turbulence * turbulence_strength * 0.1;
		xy = xy + displacement * pow((1.0 - h * 0.5), turbulence_strength);
	}

	// Strand length variation
	float noise = 0.0;
	if (scruffiness > 0.0) {
		noise = gold_noise(floor(xy * 1024.0));
	}
	float len = scruffiness <= 0.0 ? 1.0 : pow(noise, scruffiness);

	// Heightmap
	if (use_heightmap_texture) {
		if (use_texture_atlas) {
			len *= texture(texture_atlas, UV).r;
		} else {
			len *= texture(heightmap_texture, UV).r;
		}
	}

	// Distance from strand center
	vec2 center_offset = fract(xy * 1024.0) - vec2(0.5, 0.5);
	float relDist = length(center_offset) / thickness_scale * 2.0;

	// Thickness
	float thickness;
	if (use_thickness_curve) {
		thickness = texture(thickness_curve, vec2(clamp(h / len, 0.0, 0.99), 0.0)).r * len;
	} else {
		thickness = h;
	}

	// Render strand (no curls for inner shells)
	if (len - thickness >= relDist && h < len || (render_skin && h == 0.0)) {
		if (!FRONT_FACING) NORMAL = -NORMAL;

		vec3 col = color;

		// Height gradient
		float grad_h = h;
		if (scale_height_gradient) {
			grad_h /= len;
		}

		vec3 height_col;
		if (use_height_gradient) {
			height_col = texture(height_gradient, vec2(grad_h * 0.999, 0.0)).rgb;
		} else {
			float hg = pow(h, 0.9);
			height_col = vec3(hg, hg, hg);
		}
		col *= height_col;

		// Albedo texture
		if (use_albedo_texture) {
			col *= texture(albedo_texture, UV).rgb;
		}

		ALBEDO = col;

		// No emission for inner shells
	} else {
		discard;
	}
}

void light() {
	// Half-Lambert for softer lighting
	float d = dot(NORMAL, LIGHT) / 2.0 + 0.5;
	DIFFUSE_LIGHT += d * d * ATTENUATION * LIGHT_COLOR;
}
