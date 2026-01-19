// Instanced Shell Fur Shader
// Uses GPU instancing to render all shells in a single draw call
// Shell height (h) comes from INSTANCE_CUSTOM.r instead of uniform

shader_type spatial;
render_mode cull_disabled;

// Core parameters (NO h uniform - comes from instance data!)
uniform float height = 0.0;
uniform float normal_strength = 1.0;
uniform vec3 static_direction_local = vec3(0.0, 0.0, 0.0);
uniform vec3 static_direction_world = vec3(0.0, 0.0, 0.0);
uniform float density = 1.0;
uniform bool render_skin = true;
uniform int seed = 0;
uniform float scruffiness = 0.5;

// Texture atlas
uniform sampler2D texture_atlas : source_color, filter_linear;
uniform bool use_texture_atlas = false;

// Individual textures
uniform sampler2D heightmap_texture : source_color, filter_nearest;
uniform bool use_heightmap_texture = false;
uniform sampler2D turbulence_texture : filter_linear;
uniform sampler2D jitter_texture : filter_linear;

uniform float turbulence_strength = 0.5;
uniform float jitter_strength = 0.0;

// Curls
uniform bool curls_enabled = true;
uniform float curls_twist = 24.0;
uniform float curls_fill = 0.7853981634;

// Thickness
uniform sampler2D thickness_curve;
uniform bool use_thickness_curve = false;
uniform float thickness_scale = 1.0;

// Appearance
uniform vec3 color : source_color;
uniform sampler2D height_gradient : source_color, filter_nearest;
uniform bool use_height_gradient = false;
uniform bool scale_height_gradient = true;
uniform bool use_albedo_texture = false;
uniform sampler2D albedo_texture : source_color;

// Emission
uniform bool use_emission = false;
uniform vec3 emission_color : source_color;
uniform float emission_energy_multiplier = 1.0;
uniform bool use_emission_texture = false;
uniform sampler2D emission_texture : source_color;

// Physics (applied uniformly to all instances)
uniform vec3 physics_pos_offset = vec3(0.0, 0.0, 0.0);
uniform mat3 physics_rot_offset = mat3(
	vec3(1.0, 0.0, 0.0),
	vec3(0.0, 1.0, 0.0),
	vec3(0.0, 0.0, 1.0)
);

// Interactive Physics (Collision-based)
uniform bool interactive_physics_enabled = false;
uniform vec3 interactive_displacement = vec3(0.0, 0.0, 0.0);
uniform float interactive_compression = 0.5;

// Ambient Occlusion
uniform bool ao_enabled = false;
uniform float ao_strength = 0.7;
uniform float ao_depth_falloff = 2.0;
uniform vec3 ao_color : source_color = vec3(0.3, 0.25, 0.2);

// Gold Noise
float gold_noise(vec2 p) {
	p = p + vec2(float(seed), float(seed));
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Fast atan2 approximation
float atan2_approximation2(float x, float y) {
	if (x == 0.0) {
		if (y > 0.0) return PI / 2.0;
		if (y == 0.0) return 0.0;
		return -PI / 2.0;
	}
	float atan_val;
	float z = y / x;
	if (abs(z) < 1.0) {
		atan_val = z / (1.0 + 0.28 * z * z);
		if (x < 0.0) {
			if (y < 0.0) return atan_val - PI;
			return atan_val + PI;
		}
	} else {
		atan_val = PI / 2.0 - z / (z * z + 0.28);
		if (y < 0.0) return atan_val - PI;
	}
	return atan_val;
}

// Calculate AO
float calculate_ao(float shell_h, float strand_density) {
	if (!ao_enabled) return 1.0;

	float depth_ao = pow(shell_h, ao_depth_falloff);
	float final_ao = depth_ao;

	return mix(1.0, final_ao, ao_strength);
}

void vertex() {
	// ===== GET SHELL HEIGHT FROM INSTANCE DATA =====
	// INSTANCE_CUSTOM.r contains the shell height (0.0 to 1.0)
	float h = INSTANCE_CUSTOM.r;

	// Physics offset in world space (momentum-based)
	vec3 physics_pos_offset_world = (MODEL_MATRIX * vec4(physics_pos_offset, 0.0)).xyz * h * 0.2;

	// Interactive physics offset (collision-based)
	vec3 interactive_offset = vec3(0.0);
	if (interactive_physics_enabled) {
		interactive_offset = (MODEL_MATRIX * vec4(interactive_displacement, 0.0)).xyz * h * h;
		float compression_factor = 1.0 - (length(interactive_displacement) * interactive_compression * h);
		compression_factor = max(compression_factor, 0.5);
		height *= compression_factor;
	}

	// Growth direction blend
	vec3 direction = static_direction_local + (MODEL_MATRIX * vec4(static_direction_world, 0.0)).xyz;

	// Displace vertex based on shell height
	VERTEX += (NORMAL * normal_strength + direction * (1.0 - normal_strength)) * height * h + physics_pos_offset_world + interactive_offset;
	VERTEX = physics_rot_offset * VERTEX;

	// Pass h to fragment shader via COLOR.r
	// (We can't use custom varying in spatial shaders, so use COLOR as transport)
	COLOR.r = h;
}

void fragment() {
	// Retrieve shell height from vertex shader
	float h = COLOR.r;

	vec2 uv = UV * density;
	vec2 xy = uv;

	// Turbulence
	if (turbulence_strength > 0.0) {
		vec2 turbulence;
		if (use_texture_atlas) {
			turbulence = texture(texture_atlas, uv).gg - vec2(0.5, 0.5);
		} else {
			turbulence = texture(turbulence_texture, uv).xy - vec2(0.5, 0.5);
		}

		vec2 displacement = turbulence * turbulence_strength * 0.1;
		xy = xy + displacement * pow((1.0 - h * 0.5), turbulence_strength);
	}

	// Jitter
	if (jitter_strength > 0.0) {
		vec2 jitter;
		if (use_texture_atlas) {
			jitter = texture(texture_atlas, UV).bb - vec2(0.5, 0.5);
		} else {
			jitter = texture(jitter_texture, UV).xy - vec2(0.5, 0.5);
		}
		xy = xy + jitter * jitter_strength / 200.0;
	}

	// Strand length variation
	float noise = 0.0;
	if (scruffiness > 0.0 || curls_enabled) {
		noise = gold_noise(floor(xy * 1024.0));
	}
	float len = scruffiness <= 0.0 ? 1.0 : pow(noise, scruffiness);

	// Heightmap
	if (use_heightmap_texture) {
		float heightmap_val;
		if (use_texture_atlas) {
			heightmap_val = texture(texture_atlas, UV).r;
		} else {
			heightmap_val = texture(heightmap_texture, UV).r;
		}
		len *= heightmap_val;
	}

	// Distance from strand center
	vec2 center_offset = fract(xy * 1024.0) - vec2(0.5, 0.5);
	float relDist = length(center_offset) / thickness_scale * 2.0;

	// Thickness
	float thickness;
	if (use_thickness_curve) {
		// Guard against division by zero
		float safe_len = max(len, 0.0001);
		thickness = texture(thickness_curve, vec2(clamp(h / safe_len, 0.0, 0.99), 0.0)).r * len;
	} else {
		thickness = h;
	}

	// Curls
	bool curl = true;
	if (curls_enabled) {
		float a = mod(atan2_approximation2(center_offset.y, center_offset.x) + h * curls_twist + noise * 1024.0, 2.0 * PI);
		curl = a > 0.0 && a < curls_fill;
	}

	// Render strand
	if (curl && (len - thickness >= relDist && h < len || (render_skin && h == 0.0))) {
		if (!FRONT_FACING) NORMAL = -NORMAL;

		vec3 col = color;

		// Height gradient
		float grad_h = h;
		if (scale_height_gradient) {
			// Guard against division by zero
			float safe_len = max(len, 0.0001);
			grad_h /= safe_len;
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

		// Ambient Occlusion
		float ao_factor = calculate_ao(h, density);
		col = mix(col * ao_color, col, ao_factor);

		ALBEDO = col;

		// Emission
		if (use_emission) {
			vec3 emission = emission_color;
			if (use_emission_texture) {
				emission += texture(emission_texture, UV).rgb;
			}
			EMISSION = emission * emission_energy_multiplier * ao_factor;
		}

		ROUGHNESS = mix(0.8, 1.0, ao_factor);

	} else {
		discard;
	}
}

void light() {
	// Half-Lambert lighting
	float d = dot(NORMAL, LIGHT) / 2.0 + 0.5;
	DIFFUSE_LIGHT += d * d * ATTENUATION * LIGHT_COLOR;
}
