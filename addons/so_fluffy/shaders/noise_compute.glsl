#[compute]
#version 450

// Compute shader for pre-generating noise patterns for fur rendering
// This runs once on the GPU and stores results in a texture
// Massive performance improvement over per-fragment noise calculation

// Workgroup size - processes 8x8 pixels per workgroup
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Output texture - stores pre-computed noise
layout(rgba16f, set = 0, binding = 0) uniform restrict writeonly image2D output_texture;

// Parameters
layout(set = 0, binding = 1) uniform NoiseParams {
	int seed;
	float density;
	float scruffiness;
	int texture_size;
	float turbulence_scale;
	float jitter_scale;
	int noise_type;  // 0=gold, 1=perlin, 2=simplex
	float padding;   // Alignment
} params;

// Constants
const float PI = 3.14159265359;
const float GOLDEN_RATIO = 1.618033988749;

// ===== NOISE FUNCTIONS =====

// Gold Noise - fast and high quality
float gold_noise(vec2 p, int seed_offset) {
	vec2 sp = p + vec2(float(params.seed + seed_offset));
	vec3 p3 = fract(vec3(sp.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Improved Perlin-like noise
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float perlin_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	// Cubic interpolation
	vec2 u = f * f * (3.0 - 2.0 * f);

	// Sample corners
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	// Interpolate
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Simplex-like noise (faster than Perlin)
float simplex_noise(vec2 p) {
	const float K1 = 0.366025404; // (sqrt(3)-1)/2
	const float K2 = 0.211324865; // (3-sqrt(3))/6

	vec2 i = floor(p + (p.x + p.y) * K1);
	vec2 a = p - i + (i.x + i.y) * K2;
	vec2 o = (a.x > a.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
	vec2 b = a - o + K2;
	vec2 c = a - 1.0 + 2.0 * K2;

	vec3 h = max(0.5 - vec3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
	vec3 n = h * h * h * h * vec3(hash(i), hash(i + o), hash(i + 1.0));

	return dot(n, vec3(70.0));
}

// Fractal Brownian Motion - layered noise
float fbm(vec2 p, int octaves) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;

	for (int i = 0; i < octaves; i++) {
		value += amplitude * simplex_noise(p * frequency);
		frequency *= 2.0;
		amplitude *= 0.5;
	}

	return value;
}

// ===== MAIN COMPUTE FUNCTION =====

void main() {
	// Get pixel coordinates
	ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);

	// Bounds check
	if (pixel_coords.x >= params.texture_size || pixel_coords.y >= params.texture_size) {
		return;
	}

	// Normalize coordinates to [0, 1]
	vec2 uv = vec2(pixel_coords) / float(params.texture_size);

	// Scale by density
	vec2 scaled_uv = uv * params.density;

	// ===== COMPUTE NOISE CHANNELS =====

	// R channel: Strand length variation (scruffiness)
	float base_noise = 0.0;
	switch (params.noise_type) {
		case 0:  // Gold noise
			base_noise = gold_noise(scaled_uv * 1024.0, 0);
			break;
		case 1:  // Perlin
			base_noise = perlin_noise(scaled_uv * 8.0) * 0.5 + 0.5;
			break;
		case 2:  // Simplex
			base_noise = simplex_noise(scaled_uv * 8.0) * 0.5 + 0.5;
			break;
	}

	// Apply scruffiness power curve
	float strand_length = pow(base_noise, params.scruffiness);

	// G channel: Turbulence (directional displacement)
	float turbulence_x = fbm(scaled_uv * params.turbulence_scale, 3);
	float turbulence_y = fbm((scaled_uv + vec2(100.0, 100.0)) * params.turbulence_scale, 3);
	float turbulence = (turbulence_x + 1.0) * 0.5;  // Normalize to [0, 1]

	// B channel: Jitter (high-frequency variation)
	float jitter_noise = gold_noise(uv * 1024.0 * params.jitter_scale, 12345);

	// A channel: Additional pattern (for future use - curls, clumping, etc.)
	float pattern = fbm(scaled_uv * 4.0, 2) * 0.5 + 0.5;

	// ===== WRITE TO OUTPUT TEXTURE =====

	vec4 result = vec4(strand_length, turbulence, jitter_noise, pattern);
	imageStore(output_texture, pixel_coords, result);
}
