#[compute]
#version 450

// GPU Physics Compute Shader for Shell Fur System
// Calculates spring-based physics for fur movement on GPU
// Processes multiple instances in parallel for massive performance gains

// Workgroup size - process 64 instances at a time
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Physics state for a single fur instance
struct FurPhysicsState {
    vec3 spring_offset;           // Current spring displacement
    float _pad0;
    vec3 spring_velocity;         // Spring velocity
    float _pad1;
    vec3 spring_rotation;         // Rotational offset (euler)
    float _pad2;
    vec3 spring_angular_velocity; // Angular velocity
    float _pad3;
    vec3 previous_position;       // Last frame position
    float _pad4;
    vec3 previous_rotation;       // Last frame rotation (euler)
    float wind_time;              // Wind animation time
};

// Physics configuration (shared by all instances)
struct PhysicsConfig {
    vec3 gravity;
    float spring_constant;

    vec3 wind_direction;
    float mass;

    float damping;
    float stretch;
    float fur_length;
    float stiffness;

    float wind_enabled;        // 0.0 or 1.0 (bool)
    float wind_strength;
    float wind_turbulence;
    float wind_speed;

    float rotational_physics_scale;
    float delta_time;
    float exaggeration_factor;  // st = 8.0
    float _pad;
};

// Input: Physics state from previous frame
layout(set = 0, binding = 0, std430) restrict buffer PhysicsStateBuffer {
    FurPhysicsState states[];
} physics_state;

// Input: Current instance transforms
layout(set = 0, binding = 1, std430) restrict readonly buffer TransformBuffer {
    mat4 transforms[];
} instance_transforms;

// Input: Physics configuration
layout(set = 0, binding = 2, std140) uniform PhysicsConfigUniform {
    PhysicsConfig config;
};

// Output: Physics results per shell (offset and rotation)
// Each instance has shell_count results
layout(set = 0, binding = 3, std430) restrict writeonly buffer PhysicsResultBuffer {
    vec4 position_offsets[];  // xyz = offset, w = unused
    vec4 rotation_data[];     // xyz = euler rotation, w = unused
} physics_results;

// Push constants for per-dispatch data
layout(push_constant, std430) uniform PushConstants {
    uint instance_count;
    uint shell_count;
    uint total_shells;  // instance_count * shell_count
    uint _pad;
} push;

// Helper: Normalize angle to shortest path (-PI to PI)
float short_angle(float a) {
    const float PI = 3.14159265359;
    const float TAU = 6.28318530718;
    return mod(a + PI, TAU) - PI;
}

// Helper: Extract position from transform matrix
vec3 get_position(mat4 m) {
    return m[3].xyz;
}

// Helper: Extract euler rotation from transform matrix (approximate)
vec3 get_euler_rotation(mat4 m) {
    // Extract rotation from transform matrix
    // This is a simplified extraction - assumes no scale
    float sy = length(vec3(m[0][2], m[1][2], m[2][2]));

    float x = atan(m[2][1], m[2][2]);
    float y = atan(-m[2][0], sy);
    float z = atan(m[1][0], m[0][0]);

    return vec3(x, y, z);
}

void main() {
    uint instance_id = gl_GlobalInvocationID.x;

    // Bounds check
    if (instance_id >= push.instance_count) {
        return;
    }

    // Load state
    FurPhysicsState state = physics_state.states[instance_id];
    mat4 current_transform = instance_transforms.transforms[instance_id];

    vec3 current_position = get_position(current_transform);
    vec3 current_rotation = get_euler_rotation(current_transform);

    float delta = config.delta_time;
    float st = config.exaggeration_factor;

    // ===== LINEAR PHYSICS =====

    // Update wind time
    state.wind_time += delta * config.wind_speed;

    // Calculate compound linear forces
    vec3 f_linear = config.gravity;

    // Add wind force
    if (config.wind_enabled > 0.5) {
        float wind_noise = sin(state.wind_time) * cos(state.wind_time * 0.7) * config.wind_turbulence;
        vec3 wind_force = normalize(config.wind_direction) * config.wind_strength * (1.0 + wind_noise);
        f_linear += wind_force;
    }

    // Calculate movement from previous position
    vec3 dx = current_position - state.previous_position;
    vec3 v = delta > 0.0 ? dx / delta : vec3(0.0);
    state.spring_offset += dx;

    // Spring force (Hooke's law) with velocity damping: F = -kx - cv
    f_linear += -config.spring_constant * state.spring_offset - config.damping * state.spring_velocity;

    // Update velocity and position (Euler integration)
    vec3 a_linear = f_linear / config.mass;
    state.spring_velocity += a_linear * delta;
    state.spring_offset += state.spring_velocity * delta;

    // Limit velocity and offset
    float max_vel = 200.0 * config.fur_length;
    if (length(state.spring_velocity) > max_vel) {
        state.spring_velocity = normalize(state.spring_velocity) * max_vel;
    }

    float max_offset = config.fur_length / st * config.stretch;
    if (length(state.spring_offset) > max_offset) {
        state.spring_offset = normalize(state.spring_offset) * max_offset;
    }

    state.previous_position = current_position;

    // ===== ROTATIONAL PHYSICS =====

    // Calculate rotation delta
    vec3 dp = current_rotation - state.previous_rotation;
    dp = vec3(short_angle(dp.x), short_angle(dp.y), short_angle(dp.z));

    vec3 w = delta > 0.0 ? dp / delta : vec3(0.0);
    state.spring_rotation += dp;

    // Spring force with angular damping
    vec3 f_rotational = -state.spring_rotation * config.spring_constant - config.damping * state.spring_angular_velocity;

    // Update angular velocity and rotation
    vec3 a_rotational = f_rotational / config.mass;
    state.spring_angular_velocity += a_rotational * delta;
    state.spring_rotation += state.spring_angular_velocity * delta;

    // Limit angular velocity and rotation
    float max_angular_vel = 50.0;
    if (length(state.spring_angular_velocity) > max_angular_vel) {
        state.spring_angular_velocity = normalize(state.spring_angular_velocity) * max_angular_vel;
    }

    const float PI = 3.14159265359;
    float max_rotation = PI * config.fur_length / 2.0;
    if (length(state.spring_rotation) > max_rotation) {
        state.spring_rotation = normalize(state.spring_rotation) * max_rotation;
    }

    state.previous_rotation = current_rotation;

    // Write back updated state
    physics_state.states[instance_id] = state;

    // ===== CALCULATE PER-SHELL PHYSICS =====

    // For each shell in this instance, calculate physics based on height
    for (uint shell_idx = 0; shell_idx < push.shell_count; shell_idx++) {
        // Calculate normalized height (0.0 to 1.0) for this shell
        float h = push.shell_count > 1 ? float(shell_idx) / float(push.shell_count - 1) : 1.0;

        // Linear physics offset (scaled by height^stiffness for natural bend)
        vec3 offset_at_height = st * state.spring_offset * pow(h, config.stiffness);

        // Rotational physics offset (scaled by height^stiffness)
        vec3 rotation_at_height = config.rotational_physics_scale * state.spring_rotation * pow(h, config.stiffness);

        // Write to results buffer
        uint result_idx = instance_id * push.shell_count + shell_idx;
        physics_results.position_offsets[result_idx] = vec4(-offset_at_height, 0.0);
        physics_results.rotation_data[result_idx] = vec4(rotation_at_height, 0.0);
    }
}
