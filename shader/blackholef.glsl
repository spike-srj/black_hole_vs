#version 330 core
out vec4 FragColor;

// --- Uniforms ---
uniform vec3 iResolution;           // Viewport resolution in pixels.
uniform float iTime;                // Shader running time in seconds.
uniform mat4 invViewMatrix;         // Inverse of the camera's view matrix to transform rays to world space.
uniform float SchwarzschildRadius;  // The Schwarzschild radius of the black hole (2GM/c^2).
uniform vec3 blackholeCenterWorld;  // The world-space position of the black hole.
uniform samplerCube skyboxSampler;  // The skybox texture for the background.

// --- Constants ---
const int MAX_STEPS = 2000;         // Maximum number of steps for ray tracing. A trade-off between performance and quality.
const float MAX_TRACE_R = 50.0;     // Maximum trace distance in SchwarzschildRadius units. If a ray goes beyond this, we assume it has escaped.
const float PI = 3.14159265359;
const float EPSILON = 1e-5;         // A small number to avoid division by zero and other floating point issues.

// Adaptive step size parameters for the RK4 integrator.
const float D_LAMBDA_MIN = 0.005;   // Minimum step size, used when close to the black hole for precision.
const float D_LAMBDA_MAX = 0.5;    // Maximum step size, used when far away for performance.

// --- Structs ---
// Represents the state of a photon in its 2D orbital plane.
// The entire geodesic integration happens in this 2D plane to simplify calculations.
struct PhotonState {
    float r;      // Radial distance from the black hole's center.
    float phi;    // Angle in the orbital plane.
};

// Represents the result of one step of the RK4 integrator.
struct StepResult {
    PhotonState next_state;     // The photon's state after the step.
    float next_k_r_direction;   // The radial direction (+1 away, -1 towards) after the step.
};


// --- Geodesic Integration ---

// Calculates the derivatives (dr/dλ, dφ/dλ) for the geodesic equations of a photon in Schwarzschild spacetime.
// These equations describe the path of light. We integrate in the orbital plane, so dθ/dλ = 0.
vec2 get_geodesic_derivatives(float r, float E, float L) {
    // If inside or too close to the event horizon, motion effectively stops.
    if (r <= SchwarzschildRadius * 1.001 || r < EPSILON) {
        return vec2(0.0);
    }

    float r2 = r * r;
    // (dφ/dλ) = L / r²
    // This describes how the angle changes. L is the conserved angular momentum.
    float dphi_dlambda = L / r2;

    // (dr/dλ)² = E² - V(r), where V(r) is the effective potential.
    // The potential term is (L²/r²) * (1 - Rs/r).
    float potential_term = (L * L / r2) * (1.0 - SchwarzschildRadius / r);
    float dr_dlambda_sq = E * E - potential_term;

    // The radial velocity is the square root of this value.
    // If it's negative, the photon is in a "forbidden" region and has zero radial velocity.
    float dr_dlambda = (dr_dlambda_sq < 0.0) ? 0.0 : sqrt(dr_dlambda_sq);

    return vec2(dr_dlambda, dphi_dlambda);
}

// Performs a single step of the light ray's path using the 4th-order Runge-Kutta (RK4) method.
// This is more accurate than simple Euler integration for solving the differential equations.
StepResult light_step_rk4(PhotonState currentState, float k_r_direction, float E, float L, float d_lambda) {
    StepResult result;
    result.next_k_r_direction = k_r_direction; // Assume direction doesn't change by default.

    // k1: derivative at the start of the interval.
    vec2 deriv1 = get_geodesic_derivatives(currentState.r, E, L);
    float dr1 = k_r_direction * deriv1.x;
    float dp1 = deriv1.y;

    // k2: derivative at the midpoint of the interval.
    vec2 deriv2 = get_geodesic_derivatives(currentState.r + 0.5 * d_lambda * dr1, E, L);
    float dr2 = k_r_direction * deriv2.x;
    float dp2 = deriv2.y;

    // k3: derivative at the midpoint, using k2's slope.
    vec2 deriv3 = get_geodesic_derivatives(currentState.r + 0.5 * d_lambda * dr2, E, L);
    float dr3 = k_r_direction * deriv3.x;
    float dp3 = deriv3.y;

    // k4: derivative at the end of the interval.
    vec2 deriv4 = get_geodesic_derivatives(currentState.r + d_lambda * dr3, E, L);
    float dr4 = k_r_direction * deriv4.x;
    float dp4 = deriv4.y;

    // Update state by combining the weighted derivatives.
    result.next_state.r = currentState.r + (d_lambda / 6.0) * (dr1 + 2.0 * dr2 + 2.0 * dr3 + dr4);
    result.next_state.phi = currentState.phi + (d_lambda / 6.0) * (dp1 + 2.0 * dp2 + 2.0 * dp3 + dp4);
    
    // --- Update radial direction (handle turning points) ---
    // A turning point is where the ray is closest to the black hole and starts moving away.
    float r_new = result.next_state.r;
    vec2 next_derivs = get_geodesic_derivatives(r_new, E, L);
    // If the radial velocity at the new position is effectively zero, it's a turning point. Flip direction.
    if (next_derivs.x < EPSILON) {
        result.next_k_r_direction = -k_r_direction;
    }

    return result;
}

// Determines the adaptive step size based on distance to the black hole.
// Smaller steps are taken when closer for better accuracy near the strong gravitational field.
float get_adaptive_step_size(float r) {
    float r_close = SchwarzschildRadius * 3.0;
    float r_far = SchwarzschildRadius * 30.0;
    
    // Linearly interpolate between min and max step size based on distance.
    float t = clamp((r - r_close) / (r_far - r_close), 0.0, 1.0);
    return mix(D_LAMBDA_MIN, D_LAMBDA_MAX, t);
}

// When a photon escapes, this function calculates its final direction vector in world space.
// This direction is then used to sample the skybox, creating the gravitational lensing effect.
vec3 getFinalDirection(
    PhotonState final_state,
    float k_r_direction,
    float E, float L,
    vec3 u_plane_w, vec3 v_plane_w, // Orbital plane basis vectors
    vec3 initial_ray_dir           // The ray's initial direction, for the no-deflection case
) {
    // If angular momentum is negligible, the path is a straight line, so there's no deflection.
    if (L < EPSILON) {
        return initial_ray_dir;
    }

    // 1. Get final velocity components (dr/dλ, dφ/dλ) in the orbital plane's polar coordinates.
    vec2 final_derivs = get_geodesic_derivatives(final_state.r, E, L);
    float final_dr_dl = k_r_direction * final_derivs.x;
    float final_dphi_dl = final_derivs.y;

    // 2. Convert this polar velocity into a 2D Cartesian velocity vector within the orbital plane.
    // The basis of this 2D system is defined by u_plane_w and v_plane_w.
    float sin_phi = sin(final_state.phi);
    float cos_phi = cos(final_state.phi);
    
    // The transformation from polar to cartesian derivatives: d(r*cos(phi))/dλ and d(r*sin(phi))/dλ
    vec2 k_orbit_plane;
    k_orbit_plane.x = final_dr_dl * cos_phi - final_state.r * final_dphi_dl * sin_phi; // component along u_plane_w
    k_orbit_plane.y = final_dr_dl * sin_phi + final_state.r * final_dphi_dl * cos_phi; // component along v_plane_w

    // 3. Transform the 2D velocity vector from the orbital plane's basis back to 3D world coordinates.
    return normalize(k_orbit_plane.x * u_plane_w + k_orbit_plane.y * v_plane_w);
}

void main()
{
    // --- 1. Setup Ray and Coordinate System ---
    // Convert fragment coordinates from screen space to Normalized Device Coordinates (NDC) [-1, 1].
    vec2 ndc = (gl_FragCoord.xy / iResolution.xy) * 2.0 - 1.0;
    ndc.x *= iResolution.x / iResolution.y; // Correct for aspect ratio.
    
    // Unproject the NDC to get a ray direction in view space, then transform to world space using the inverse view matrix.
    vec4 viewRayDir = vec4(ndc.x, ndc.y, -1.0, 0.0);
    vec3 ray_dir_world = normalize((invViewMatrix * viewRayDir).xyz);
    vec3 ray_pos_world = (invViewMatrix * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

    // --- 2. Calculate Conserved Quantities ---
    // These quantities (Energy and Angular Momentum) are constant along the photon's geodesic.
    vec3 p_rel_initial_cart = ray_pos_world - blackholeCenterWorld;
    
    // For a photon coming from infinity, Energy E is normalized to 1.
    float E_const = 1.0;
    // Angular momentum L = r x p. Here, p is the photon's direction vector.
    vec3 L_vec_world = cross(p_rel_initial_cart, ray_dir_world);
    float L_const = length(L_vec_world);

    // Initial radial direction: positive if pointing away from the black hole center.
    float k_r_direction = sign(dot(ray_dir_world, p_rel_initial_cart));

    // --- 3. Define the Orbital Plane ---
    // The entire trajectory of the photon will lie in a single plane. We do all calculations in this plane.
    vec3 orbit_normal_w = normalize(L_vec_world);
    // If L is zero, the motion is purely radial. We can pick an arbitrary plane.
    if (L_const < EPSILON) {
        // Create a normal vector perpendicular to the initial direction.
        // This is a robust way to create an orthogonal vector.
        vec3 tangent = vec3(1.0, 0.0, 0.0);
        if(abs(dot(tangent, ray_dir_world)) > 0.9) tangent = vec3(0.0, 1.0, 0.0);
        orbit_normal_w = normalize(cross(ray_dir_world, tangent));
    }
   
    // Create an orthonormal basis for the orbital plane.
    vec3 u_plane_w = normalize(p_rel_initial_cart); // u-vector points to the initial position.
    vec3 v_plane_w = cross(orbit_normal_w, u_plane_w); // v-vector is orthogonal to u and the normal.

    // --- 4. Initialize Photon State ---
    PhotonState currentState;
    currentState.r = length(p_rel_initial_cart);
    currentState.phi = 0.0; // By definition, we align the initial position with phi=0 in our new orbital plane.
    
    // If starting inside the horizon, the ray is immediately terminated.
    if (currentState.r <= SchwarzschildRadius) {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // --- 5. Ray Tracing Loop ---
    // We trace the ray backwards from the camera until it either hits the horizon or escapes to infinity.
    bool hit_horizon = false;
    float max_trace_dist_sq = pow(MAX_TRACE_R * SchwarzschildRadius, 2.0);

    for (int j = 0; j < MAX_STEPS; j++) {
        // Check for termination conditions.
        if (currentState.r <= SchwarzschildRadius * 1.001) { // Use a small tolerance.
            hit_horizon = true;
            break;
        }
        if (currentState.r * currentState.r > max_trace_dist_sq) {
            break; // Ray has escaped to "infinity".
        }
        
        // Take one step along the geodesic using our RK4 integrator.
        float d_lambda = get_adaptive_step_size(currentState.r);
        StepResult step_res = light_step_rk4(currentState, k_r_direction, E_const, L_const, d_lambda);
        
        // Update state for the next iteration.
        currentState = step_res.next_state;
        k_r_direction = step_res.next_k_r_direction;
    }

    // --- 6. Determine Final Color ---
    if (hit_horizon) {
        // The ray fell into the black hole, so it's black.
        FragColor = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        // The ray escaped. Calculate its final direction to find out where it "came from" in the sky.
        vec3 final_dir = getFinalDirection(currentState, k_r_direction, E_const, L_const, u_plane_w, v_plane_w, ray_dir_world);
        // Use this direction to sample the background skybox, creating the lensing effect.
        FragColor = texture(skyboxSampler, final_dir);
    }
}