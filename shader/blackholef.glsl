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
const float HORIZON_TOL = 1.001;    // r <= Rs*HORIZON_TOL is considered inside horizon for termination
const int   MAX_REFINES = 6;        // Maximum backtracking refinements per step
const float FLIP_HYST_FRAC = 0.02;  // Radial hysteresis fraction to avoid flip ping-pong

// Adaptive step size parameters for the RK4 integrator.
// We will further limit step by Δr and Δφ constraints each step.
const float D_LAMBDA_MIN = 0.0005;  // Minimum step size, used when close to the black hole for precision.
const float D_LAMBDA_MAX = 0.25;    // Maximum step size, used when far away for performance.
const float MAX_DR_FRACTION = 0.02;  // Limit |Δr| <= MAX_DR_FRACTION * max(r, Rs) per step
const float MAX_DPHI = 0.05;         // Limit |Δφ| per step to avoid spinning too much near photon sphere

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

// --- Numeric utilities ---
bool is_nan(float v) { return !(v == v); }
bool is_inf(float v) { return abs(v) > 1e30; }
bool is_bad(float v) { return is_nan(v) || is_inf(v); }
bool any_bad(vec3 v) { return is_bad(v.x) || is_bad(v.y) || is_bad(v.z); }

// Small helpers
bool near_horizon(float r) { return r <= SchwarzschildRadius * HORIZON_TOL; }
float safe_len(vec3 v) { return length(v); }
float safe_max_r(float r) { return max(r, SchwarzschildRadius); }


// --- Geodesic Integration ---

// Calculates derivatives (dr/dλ, dφ/dλ) for null geodesics in Schwarzschild spacetime
// We integrate in the orbital plane (θ fixed), so only r and φ are evolved.
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

// One RK4 advance for (r, φ). Caller manages radial direction flips.
StepResult advance_rk4(PhotonState currentState, float k_r_direction, float E, float L, float d_lambda) {
    StepResult result;
    result.next_k_r_direction = k_r_direction; // Caller decides flips; default unchanged.

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
    
    // Radial direction is not flipped here; caller performs robust turning-point logic.

    return result;
}

// Effective potential V_eff(r) = (L^2/r^2) * (1 - Rs/r)
float effective_potential(float r, float L) {
    float r2 = r * r;
    return (L * L / r2) * (1.0 - SchwarzschildRadius / r);
}

// Compute adaptive step based on local derivatives to bound Δr and Δφ per step
float compute_adaptive_step_size(float r, float dr_dl_abs, float dphi_dl_abs) {
    float rs = SchwarzschildRadius;
    float max_dr = MAX_DR_FRACTION * max(r, rs);
    float dl_from_dr = (dr_dl_abs > EPSILON) ? (max_dr / dr_dl_abs) : D_LAMBDA_MIN;
    float dl_from_dphi = (dphi_dl_abs > EPSILON) ? (MAX_DPHI / dphi_dl_abs) : D_LAMBDA_MAX;
    float d_lambda = min(min(dl_from_dr, dl_from_dphi), D_LAMBDA_MAX);
    return clamp(d_lambda, D_LAMBDA_MIN, D_LAMBDA_MAX);
}

// Build orthonormal basis (u, v) for orbital plane given orbit normal and initial rel pos
void build_orbit_plane_basis(vec3 orbit_normal_w, vec3 p_rel_initial_cart, out vec3 u_plane_w, out vec3 v_plane_w) {
    u_plane_w = normalize(p_rel_initial_cart);
    v_plane_w = cross(orbit_normal_w, u_plane_w);
    if (safe_len(v_plane_w) < 1e-8) {
        vec3 helper = abs(orbit_normal_w.x) < 0.9 ? vec3(1.0,0.0,0.0) : vec3(0.0,1.0,0.0);
        v_plane_w = normalize(cross(orbit_normal_w, helper));
        u_plane_w = normalize(cross(v_plane_w, orbit_normal_w));
    } else {
        v_plane_w = normalize(v_plane_w);
    }
}

// Take a robust step with backtracking against forbidden region and horizon crossing
StepResult robust_step(PhotonState state, float k_r_dir, float E, float L, float d_lambda_try) {
    StepResult step_res;
    float d_lambda_used = d_lambda_try;
    for (int refine = 0; refine < MAX_REFINES; refine++) {
        step_res = advance_rk4(state, k_r_dir, E, L, d_lambda_used);
        float r_new = step_res.next_state.r;
        float dr_sq_new = E * E - effective_potential(max(r_new, SchwarzschildRadius * 1.000001), L);
        if (dr_sq_new >= 0.0 && !is_bad(r_new) && !near_horizon(r_new)) {
            break;
        }
        d_lambda_used *= 0.5;
    }
    return step_res;
}

// Compute final escape direction in world space from final state and plane basis
// This direction is used to sample the skybox.
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

    // 3. Transform back to 3D world coordinates.
    vec3 dir = k_orbit_plane.x * u_plane_w + k_orbit_plane.y * v_plane_w;
    if (length(dir) < 1e-12 || any_bad(dir)) {
        return initial_ray_dir; // fallback to initial direction to avoid NaN/Inf
    }
    return normalize(dir);
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
    vec3 u_plane_w, v_plane_w;
    build_orbit_plane_basis(orbit_normal_w, p_rel_initial_cart, u_plane_w, v_plane_w);

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
    float last_flip_r = -1.0; // hysteresis for flipping to avoid ping-pong

    for (int j = 0; j < MAX_STEPS; j++) {
        // Check for termination conditions.
        if (currentState.r <= SchwarzschildRadius * 1.001) { // Use a small tolerance.
            hit_horizon = true;
            break;
        }
        if (currentState.r * currentState.r > max_trace_dist_sq) {
            break; // Ray has escaped to "infinity".
        }
        
        // Derivatives at current position to compute step size
        vec2 derivs_here = get_geodesic_derivatives(currentState.r, E_const, L_const);
        float dr_dl_abs = derivs_here.x;
        float dphi_dl_abs = derivs_here.y;
        if (is_bad(dr_dl_abs) || is_bad(dphi_dl_abs)) {
            dr_dl_abs = max(dr_dl_abs, 0.0);
            dphi_dl_abs = max(dphi_dl_abs, 0.0);
        }

        // Compute adaptive step to limit Δr and Δφ
        float d_lambda_try = compute_adaptive_step_size(currentState.r, dr_dl_abs, dphi_dl_abs);
        // Robust step with backtracking
        StepResult step_res = robust_step(currentState, k_r_direction, E_const, L_const, d_lambda_try);

        // Turning-point and direction flip logic with hysteresis
        float r_old = currentState.r;
        float r_new_final = step_res.next_state.r;
        bool expect_outward = (k_r_direction > 0.0);
        bool moved_outward = (r_new_final > r_old);
        bool crossed_expectation = (expect_outward != moved_outward);

        // Also check near turning: (dr/dλ)^2 ~ 0 at new position
        float dr_sq_at_new = E_const * E_const - effective_potential(max(r_new_final, SchwarzschildRadius * 1.000001), L_const);
        bool near_turning = abs(dr_sq_at_new) <= 1e-7;

        // Apply hysteresis: avoid flipping again until moved away a bit
        bool allow_flip = true;
        if (last_flip_r > 0.0) {
            allow_flip = abs(r_new_final - last_flip_r) > (FLIP_HYST_FRAC * safe_max_r(r_new_final));
        }

        if (allow_flip && (crossed_expectation || near_turning)) {
            k_r_direction = -k_r_direction;
            last_flip_r = r_new_final;
        }

        // Commit state with sanitization
        if (is_bad(r_new_final)) {
            break; // abort trace and treat as escaped
        }
        currentState = step_res.next_state;
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