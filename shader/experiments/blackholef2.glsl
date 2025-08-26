#version 330 core // 或更高版本
out vec4 FragColor;

// --- Uniforms ---
uniform vec3 iResolution;         // 视口分辨率 (x, y = width, height)
uniform float iTime;              // 时间 (秒) - 这个示例中未使用，但保留接口
uniform mat4 invViewMatrix;       // 逆视图矩阵 (相机世界矩阵 V^-1)
uniform float SchwarzschildRadius; // 黑洞的史瓦西半径 (用于视界判断)
uniform float M; // // 黑洞质量 (如果加速度公式需要)
uniform vec3 blackholeCenterWorld;
uniform samplerCube skyboxSampler;  // 天空盒纹理采样器

// --- 新增：球体参数 (可以在 C++ 端作为 uniform 传入，这里硬编码) ---
uniform vec3 sphereCenter;      // 球体世界坐标中心
uniform float sphereRadius;     // 球体半径
const vec3 sphereColor = vec3(1.0, 1.0, 0.0); // 黄色

// --- 常量 ---
const int MAX_STEPS = 2000;              // 积分步数 (根据效果和性能调整)
const float STEP_TIME_TOTAL = 0.001;   // 基础步长因子 (需要调整!)
const float MAX_DIST_SQ = 200.0;   // 最大追踪距离平方
const float PI = 3.14159265359;
const float TWO_PI = 2.0 * PI;

const float D_LAMBDA = 0.005;        // 仿射参数步长 dλ (需要仔细调整)
const float MAX_R_TRACE = 5000.0;     // 最大追踪半径 (倍数于 Rs，或绝对值)
const float EPSILON = 1e-5; // 或者 1e-4, 1e-6，取决于你需要的精度和场景尺度
// --- 工具函数 ---

// --- 结构体：光子在球坐标下的状态 ---
struct PhotonStateSpherical {
    float r;     // 径向坐标 (相对于黑洞中心)
    float theta; // 极角 (0 到 PI, 通常我们假设运动在赤道面 theta=PI/2)
    float phi;   // 方位角 (0 到 2*PI)
    // float t_coord; // 坐标时 (如果需要追踪)

    // 四维速度的球坐标空间分量 (或者直接用 dr/dλ, dθ/dλ, dφ/dλ)
    // 为了与一阶 ODE 对应，我们直接存储导数
    float dr_dlambda;
    float dtheta_dlambda;
    float dphi_dlambda;
    // float dt_dlambda;
};

// --- 坐标转换函数 (你的实现或标准实现) ---
// 笛卡尔坐标转球坐标 (相对于给定的原点 origin)
// output: vec3(r, theta, phi)
// r: 径向距离
// theta: 极角 (与 Y 轴正方向的夹角, 0 到 PI)
// phi: 方位角 (在 XZ 平面内，从 X 轴正方向逆时针到 Z 轴正方向, 0 到 2*PI)
vec3 cartesianToSpherical(vec3 p_cart_relative) { // 直接传入相对向量
    float r = length(p_cart_relative);
    if (r < 1e-6) return vec3(0.0, 0.0, 0.0);
    // 确保 p_cart_relative.y / r 在 [-1, 1] 范围内
    float theta = acos(clamp(p_cart_relative.y / r, -1.0, 1.0));
    float phi = atan(p_cart_relative.z, p_cart_relative.x); // atan2(z,x) 通常更好，但 atan(z,x) 也可以
    if (phi < 0.0) phi += TWO_PI;
    return vec3(r, theta, phi);
}

// 球坐标转笛卡尔坐标 (生成相对于原点的笛卡尔向量)
// input: r, theta, phi
vec3 sphericalToCartesian(float r, float theta, float phi) {
    vec3 p_cart_relative;
    p_cart_relative.x = r * sin(theta) * cos(phi);
    p_cart_relative.z = r * sin(theta) * sin(phi); // 对应 atan(z,x)
    p_cart_relative.y = r * cos(theta);
    return p_cart_relative;
}

float intersectSphere(vec3 rayOrigin, vec3 rayDir, vec3 sCenter, float sRadius) {
    vec3 oc = rayOrigin - sCenter;
    float b = dot(oc, rayDir);
    float c = dot(oc, oc) - sRadius * sRadius;
    float h = b * b - c;
    if (h < 0.0) return -1.0; // 不相交
    // 我们需要最近的那个正交点距离
    float t = -b - sqrt(h);
    // 如果起点就在球内部，这个 t 可能是负的，但对于视界穿越，
    // 我们通常关心的是从外部进入内部的第一次碰撞，所以 t>=0 比较重要。
    // 如果允许从内部出来（虽然物理上不可能离开视界），需要考虑 t2 = -b + sqrt(h)。
    // 对于这个应用场景，只关心 t >= 0 的情况就足够了。
    return t;
}

// --- 史瓦西度规下的光子一阶 ODE 系统 ---
// 输入：当前球坐标 r, theta (守恒量 E_const, L_const)
// 输出：PhotonStateSpherical 结构体，其中包含 dr/dλ, dtheta/dλ, dphi/dλ
// (dt/dλ 如果需要的话)
// 我们假设 L_const 是总角动量大小，运动被限制在一个平面上，
// 可以通过旋转坐标系使得这个平面是赤道面 theta = PI/2。
// 如果做这个简化，dtheta/dλ = 0。
PhotonStateSpherical get_schwarzschild_geodesic_derivatives(
    float r,
    float theta, // 即使假设赤道面，也保留theta以备将来扩展
    float E_const,
    float L_const // L_const 是总角动量大小
) {
    PhotonStateSpherical derivs;
    derivs.r = 0.0; derivs.theta = 0.0; derivs.phi = 0.0; // 初始化坐标（虽然这个函数只返回导数）
    derivs.dr_dlambda = 0.0; derivs.dtheta_dlambda = 0.0; derivs.dphi_dlambda = 0.0;

    if (r <= SchwarzschildRadius * 1.001 || r < 1e-5) { // 非常接近或在视界内，或在奇点
        return derivs; // 导数为0，停止前进
    }

    float r2 = r * r;
    float sin_theta = sin(theta);
    float sin2_theta = sin_theta * sin_theta;

    // 简化：假设运动在初始定义的轨道平面上，可以通过旋转使之为赤道面
    // 对于史瓦西，任何轨道都在一个平面内。我们可以选择坐标系使 theta = PI/2
    // 那么 sin2_theta = 1.0， dtheta_dλ = 0。
    // L_const 此处代表总角动量 Lz (如果 z 轴垂直轨道平面)
    if (abs(sin2_theta) < 1e-6) { // 避免除以零，如果初始就在极点
        sin2_theta = 1e-6; // 或直接返回0导数
    }

    // dφ/dλ = L / (r² sin²θ)
    derivs.dphi_dlambda = L_const / (r2 * sin2_theta); // 如果假设赤道面，sin2_theta = 1

    // (dr/dλ)² = E² - (L²/r²) * (1 - Rs/r)  (这里 L 是总角动量)
    // (dθ/dλ)² = (Q - Lz²cot²θ)/r⁴  (对于史瓦西 Q=0, Lz=Lsin(initial_theta_of_L_vector))
    // 更简单：由于轨道是平面的，我们可以固定一个轨道平面。
    // 如果我们通过旋转坐标系使光子初始在 XY 平面 (theta=PI/2) 运动，
    // 且初始 dtheta/dlambda = 0，则光子将保持在 theta=PI/2。
    derivs.dtheta_dlambda = 0.0; // 基于此简化

    float term_L_r_potential = (L_const * L_const / r2) * (1.0 - SchwarzschildRadius / r);
    float dr_dlambda_sq = E_const * E_const - term_L_r_potential;

    if (dr_dlambda_sq < 0.0) {
        derivs.dr_dlambda = 0.0; // 光子无法到达此半径（经典转折点）
    } else {
        derivs.dr_dlambda = sqrt(dr_dlambda_sq);
        // dr/dλ 的符号需要在 RK4 步进中根据当前是向内还是向外运动来确定
    }

    // dt/dλ = E / (1 - Rs/r)  (如果需要计算坐标时)
    // derivs.dt_dlambda = E_const / (1.0 - SchwarzschildRadius / r);

    return derivs;
}

// RK4 步进函数，用于更新球坐标状态
// currentState: 当前的光子状态 (r, theta, phi)
// k_r_direction: 当前 dr/dλ 的符号 (+1 向外, -1 向内)
// E_const, L_const: 守恒量
// d_lambda: 仿射参数步长
// 返回: 更新后的光子状态，以及下一个 dr/dλ 的符号
struct StepResult {
    PhotonStateSpherical next_state;
    float next_k_r_direction;
};

StepResult light_step_geodesic_spherical(
    PhotonStateSpherical current_state,
    float k_r_direction_current,
    float E_const,
    float L_const,
    float d_lambda
) {
    StepResult result;
    result.next_k_r_direction = k_r_direction_current; // 默认保持

    PhotonStateSpherical s = current_state; // 当前状态

    // k1
    PhotonStateSpherical deriv1 = get_schwarzschild_geodesic_derivatives(s.r, s.theta, E_const, L_const);
    float dr1 = k_r_direction_current * deriv1.dr_dlambda;
    float dt1 = 0.0; // deriv1.dtheta_dlambda; // 简化为0
    float dp1 = deriv1.dphi_dlambda;

    // k2
    PhotonStateSpherical deriv2 = get_schwarzschild_geodesic_derivatives(s.r + 0.5 * d_lambda * dr1, s.theta + 0.5 * d_lambda * dt1, E_const, L_const);
    // 估算 k2 时的 k_r 符号（简化：假设不变，除非 dr1=0）
    float k_r_dir2 = k_r_direction_current; if(dr1==0.0 && deriv1.dr_dlambda != 0.0) k_r_dir2 = (deriv1.dr_dlambda > 0.0 ? 1.0: -1.0);
    float dr2 = k_r_dir2 * deriv2.dr_dlambda;
    float dt2 = 0.0; // deriv2.dtheta_dlambda;
    float dp2 = deriv2.dphi_dlambda;

    // k3
    PhotonStateSpherical deriv3 = get_schwarzschild_geodesic_derivatives(s.r + 0.5 * d_lambda * dr2, s.theta + 0.5 * d_lambda * dt2, E_const, L_const);
    float k_r_dir3 = k_r_dir2; if(dr2==0.0 && deriv2.dr_dlambda != 0.0) k_r_dir3 = (deriv2.dr_dlambda > 0.0 ? 1.0: -1.0);
    float dr3 = k_r_dir3 * deriv3.dr_dlambda;
    float dt3 = 0.0; // deriv3.dtheta_dlambda;
    float dp3 = deriv3.dphi_dlambda;

    // k4
    PhotonStateSpherical deriv4 = get_schwarzschild_geodesic_derivatives(s.r + d_lambda * dr3, s.theta + d_lambda * dt3, E_const, L_const);
    float k_r_dir4 = k_r_dir3; if(dr3==0.0 && deriv3.dr_dlambda != 0.0) k_r_dir4 = (deriv3.dr_dlambda > 0.0 ? 1.0: -1.0);
    float dr4 = k_r_dir4 * deriv4.dr_dlambda;
    float dt4 = 0.0; // deriv4.dtheta_dlambda;
    float dp4 = deriv4.dphi_dlambda;

    // 更新状态
    result.next_state.r = s.r + (d_lambda / 6.0) * (dr1 + 2.0 * dr2 + 2.0 * dr3 + dr4);
    result.next_state.theta = s.theta + (d_lambda / 6.0) * (dt1 + 2.0 * dt2 + 2.0 * dt3 + dt4); // theta 保持不变
    result.next_state.phi = s.phi + (d_lambda / 6.0) * (dp1 + 2.0 * dp2 + 2.0 * dp3 + dp4);

    // 更新下一个 dr/dλ 的符号
    // 如果 r 增加了，符号为正，如果 r 减小了，符号为负
    // 这是简化的，更鲁棒的方法是检查 get_schwarzschild_geodesic_derivatives 返回的 dr_dlambda_sq
    // 是否在新的 r 处为正，以及 r 相对于转折点的变化。
    float dr_total_step = (d_lambda / 6.0) * (dr1 + 2.0 * dr2 + 2.0 * dr3 + dr4);
    if (abs(dr_total_step) > 0) { // 只有当 r 实际变化时才更新符号
        result.next_k_r_direction = (dr_total_step > 0.0) ? 1.0 : -1.0;
    } else {
        // 如果 r 几乎没变（可能在转折点），我们需要更复杂的逻辑来决定下一个符号
        // 暂时保持当前符号，或者如果 deriv.dr_dlambda 为0，则下一个符号可能需要反转。
        // 如果 get_schwarzschild_geodesic_derivatives(result.next_state.r, ...) 的 dr_dlambda_sq < 0,
        // 那么我们可能已经过了经典转折点，需要反转。
        // 这里是一个非常简化的处理，实际应用需要更鲁棒的转折点检测和符号切换。
        PhotonStateSpherical final_derivs_check = get_schwarzschild_geodesic_derivatives(result.next_state.r, result.next_state.theta, E_const, L_const);
        if (final_derivs_check.dr_dlambda == 0.0 && deriv1.dr_dlambda != 0.0) { // 刚到达转折点
            result.next_k_r_direction = -k_r_direction_current; // 尝试反转
        }
    }


    return result;
}


void main()
{
    // --- 1. 计算初始射线 (世界坐标) ---
    vec2 uv = gl_FragCoord.xy / iResolution.xy;
    vec2 ndc = uv * 2.0 - 1.0;
    float aspectRatio = iResolution.x / iResolution.y;
    float focalLength = 1.0;
    vec4 viewRayDir = vec4(ndc.x * aspectRatio, ndc.y, -focalLength, 0.0);
    //摄像机看向的方向
    vec3 world_dir_initial = normalize((invViewMatrix * viewRayDir).xyz);
    vec3 world_pos_initial = (invViewMatrix * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

    // --- 2. 转换到以黑洞为中心的球坐标并计算守恒量 ---
    vec3 p_rel_initial_cart = world_pos_initial - blackholeCenterWorld;
    vec3 initial_sph_coords = cartesianToSpherical(p_rel_initial_cart); // 相对于黑洞的球坐标

    PhotonStateSpherical currentState;
    currentState.r = initial_sph_coords.x;
    currentState.theta = initial_sph_coords.y; // 我们将假设运动在 theta = PI/2 平面
                                             // 为了简化，我们需要将初始射线旋转到这个平面
    //currentState.phi = initial_sph_coords.z;//这是导致画面变形的原因（即使max_step是0）
    currentState.phi = 0;//这是导致画面变形的原因（即使max_step是0），但不是90度跳变的原因,但可以把它先设成0简化后面的计算再继续查问题


    // --- 简化：强行将运动限制在通过初始p_rel_initial_cart和原点定义的赤道面 ---
    // 这意味着我们需要重新计算一个等效的 L，并固定 theta = PI/2
    // 1. 计算轨道平面法线 (世界坐标，以黑洞为中心)
    vec3 L_vec_world = cross(p_rel_initial_cart, world_dir_initial);
    float L_const = length(L_vec_world); // 总角动量大小
    float E_const = 1.0; // 设定能量

    // 2. 设定 theta = PI/2 (赤道面)
    currentState.theta = PI / 2.0;
    // 3. 需要重新计算初始 phi，使得 p_rel_initial_cart 在这个选定的赤道面上的投影
    //    其方位角是 currentState.phi。
    //    这是一个复杂的步骤。为了简化，我们假设初始光线已经近似在 xz 平面（如果黑洞在原点），
    //    或者我们需要一个方法来找到光线在其自身轨道平面内的初始 (r, phi_in_plane)。
    //    一个更简单的（但有损通用性的）做法是：
    //    始终在以初始 p_rel_initial_cart 定义的“水平面”内积分 phi。
    //    这意味着我们需要一种方法来确定初始的 dr/dλ 和 dφ/dλ (在那个平面内)。

    // --- 让我们用更直接的方法设置初始导数的符号 ---
    // (dr/dλ) 的初始符号：如果光线射向黑洞中心，为负。dot是cos
    float k_r_direction = (dot(world_dir_initial, p_rel_initial_cart) < 0.0) ? -1.0 : 1.0;
    if (length(p_rel_initial_cart) < SchwarzschildRadius * 1.01) { // 如果起点就在视界内或非常近
        k_r_direction = 0.0; // 避免奇怪行为
    }


    // --- 3. 光线积分循环 ---
    float alpha = 1.0; // 标记是否落入
    vec3 final_escape_dir_world = world_dir_initial; // 默认逃逸方向

    for (int j = 0; j < 0; j++) {
        // 简单事件视界判断 (基于当前球坐标 r)
        if (currentState.r <= SchwarzschildRadius) {
            alpha = 0.0;
            break;
        }
        // ... (在 main() 函数的积分循环之后，逃逸分支内) ...
        if (currentState.r > MAX_R_TRACE * SchwarzschildRadius) {
            // --- 计算最终逃逸方向 (精确版本) ---
//            PhotonStateSpherical final_derivs = get_schwarzschild_geodesic_derivatives(currentState.r, PI/2.0, E_const, L_const); // theta = PI/2
//            float final_dr_dl = k_r_direction * final_derivs.dr_dlambda;
//            float final_dphi_dl = final_derivs.dphi_dlambda;
//
//            // 在轨道平面内的笛卡尔速度分量 (假设我们积分的 phi 是从某个平面内 x 轴开始)
//            vec2 k_orbit_plane_cart2D;
//            float sin_phi_final = sin(currentState.phi);
//            float cos_phi_final = cos(currentState.phi);
//            k_orbit_plane_cart2D.x = final_dr_dl * cos_phi_final - currentState.r * final_dphi_dl * sin_phi_final;
//            k_orbit_plane_cart2D.y = final_dr_dl * sin_phi_final + currentState.r * final_dphi_dl * cos_phi_final;
//
//            // --- 构建从轨道平面到世界的变换 ---
//            // 轨道平面的法向量 (世界坐标)
//            vec3 L_vector_at_start = cross(p_rel_initial_cart, world_dir_initial); // 初始角动量矢量
//            vec3 orbit_normal_w = vec3(0.0, 0.0, 1.0); // 默认，用于 L=0 情况
//            if (length(L_vector_at_start) > EPSILON) {
//                orbit_normal_w = normalize(L_vector_at_start);
//            }
//
//            // 如果 L_const 非常小 (近似径向运动)，最终方向就是最后的世界速度方向
//            // 或者从黑洞中心指向最终位置的方向。
//            // 之前我们用 v_world (牛顿近似) 或 k_world (测地线) 作为循环变量。
//            // 如果我们在循环中也维护一个笛卡尔世界速度 k_cart_world，并用测地线方程的
//            // 笛卡尔形式更新它（这很复杂），那么这里可以直接用 normalize(k_cart_world)。
//            // 既然我们是在球坐标积分，就需要从球坐标速度转换。
//
//            if (L_const < EPSILON) { // 近似径向逃逸
//                // 对于纯径向逃逸，方向应该是从黑洞中心指向当前位置
//                vec3 final_pos_rel_cart = sphericalToCartesian(currentState.r, PI/2.0, currentState.phi); // 得到相对于黑洞的笛卡尔位置
//                final_escape_dir_world = normalize(final_pos_rel_cart); // 这是在“轨道平面”内的方向，如果轨道平面就是世界平面
//                // 如果黑洞在原点，这个 final_pos_rel_cart 就是世界方向。
//                // 如果黑洞不在原点，我们需要一个更通用的方法。
//                // 实际上，对于 L=0，dphi/dlambda = 0，phi 应该不变。
//                // 逃逸方向应该沿着初始的 p_rel_initial_cart 方向（如果是向外的话）
//                // 或者其反方向（如果是从内向外）。
//                if (length(p_rel_initial_cart) > EPSILON) {
//                     final_escape_dir_world = normalize(p_rel_initial_cart); // 假设初始就在向外或已反转
//                     if (k_r_direction < 0.0 && dot(world_dir_initial, p_rel_initial_cart) < 0.0) {
//                         // 如果初始向内，但现在径向逃逸，说明反转了，方向应与初始相对位置相反？
//                         // 这很复杂，L=0 的情况应该更简单，直接是径向的。
//                         // 最终方向应该是沿着连接黑洞中心和光子最终位置的直线。
//                         vec3 final_p_world = sphericalToCartesian(currentState.r, currentState.theta, currentState.phi) + blackholeCenterWorld;
//                         final_escape_dir_world = normalize(final_p_world - blackholeCenterWorld);
//                    }
//                } 
//                else {
//                    final_escape_dir_world = world_dir_initial; // 如果初始就在中心，用初始方向
//                }
//
//            } else {
//                // 对于有角动量的情况，进行轨道平面到世界的旋转
//                // 定义轨道平面内的基向量 (u_plane, v_plane) 和法向量 (orbit_normal_w)
//                // u_plane 可以是初始 p_rel_initial_cart 在轨道平面上的投影方向
//                // (即 p_rel_initial_cart 本身，因为它就在轨道平面内)
//                vec3 u_plane_w = normalize(p_rel_initial_cart); // 轨道平面内的一个参考方向 (例如，phi=0对应的方向)
//                vec3 v_plane_w = normalize(cross(orbit_normal_w, u_plane_w)); // 与u_plane正交，在轨道平面内
//
//                // k_orbit_plane_cart2D.x 是沿着 u_plane_w 的分量
//                // k_orbit_plane_cart2D.y 是沿着 v_plane_w 的分量
//                final_escape_dir_world = normalize(
//                    k_orbit_plane_cart2D.x * u_plane_w +
//                    k_orbit_plane_cart2D.y * v_plane_w
//                );
//            }
            break; // 逃逸
        }

        if (k_r_direction == 0.0 && currentState.r > SchwarzschildRadius) { // 卡在转折点外面
             final_escape_dir_world = world_dir_initial; // 无法前进，视为直接逃逸
             break;
        }

        // 执行 RK4 步进
        StepResult step_res = light_step_geodesic_spherical(currentState, k_r_direction, E_const, L_const, D_LAMBDA);
        currentState = step_res.next_state;
        k_r_direction = step_res.next_k_r_direction;
    }

    // --- 4. 确定最终颜色 ---
    if (alpha <= 0.0) { // 或者 if (currentState.r <= SchwarzschildRadius)
        FragColor = vec4(0.0, 0.0, 0.0, 1.0); // 黑洞
    } 
    else {
        // 光线逃逸 (因为 alpha > 0.0，意味着它没有落入视界，
        // 并且循环因为 MAX_STEPS 或 MAX_R_TRACE_FACTOR * SchwarzschildRadius 结束)

        // --- 正确的逃逸方向计算 ---
        // 此时，currentState.r, currentState.phi 包含了光线在积分结束时的球坐标位置。
        // 我们需要的是光线在这一点的“速度”方向。
        // 这个速度方向可以通过最后一次调用 get_schwarzschild_geodesic_derivatives
        // (在最后一个有效的 k_r_direction 下) 得到球坐标速度分量，然后转换为笛卡尔。

        // 1. 获取最终的球坐标导数大小
        PhotonStateSpherical final_derivs_mag = get_schwarzschild_geodesic_derivatives(currentState.r, currentState.theta, E_const, L_const);
        // 2. 应用最后一次有效的径向速度符号 (这个 k_r_direction 是循环结束时的值)
        float final_dr_dl = k_r_direction * final_derivs_mag.dr_dlambda;
        //float final_dr_dl =  final_derivs_mag.dr_dlambda;
        float final_dphi_dl = final_derivs_mag.dphi_dlambda;
        // float final_dtheta_dl = 0.0; // 赤道面简化

        // 3. 将球坐标速度转换为在“轨道平面局部笛卡尔坐标系”下的速度 V = (dr/dλ) * e_r_hat + (r * dφ/dλ) * e_phi_hat
        //    这个局部坐标系的 x 轴通常对应 phi=0 的方向，y 轴对应 phi=PI/2 的方向。
        vec2 k_orbit_plane_cart2D;
        float sin_phi_final = sin(currentState.phi);
        float cos_phi_final = cos(currentState.phi);

        // 笛卡尔速度分量在轨道平面内：
        // (dr/dλ) 在笛卡尔的投影 + (r*dφ/dλ) 在笛卡尔的投影
        k_orbit_plane_cart2D.x = final_dr_dl * cos_phi_final - currentState.r * final_dphi_dl * sin_phi_final;
        k_orbit_plane_cart2D.y = final_dr_dl * sin_phi_final + currentState.r * final_dphi_dl * cos_phi_final;
        // z 分量为 0 (因为在轨道平面/赤道面)

        // 4. 将这个轨道平面内的 2D 速度向量，通过旋转，转换回世界坐标系下的 3D 方向向量。
        //    这需要知道轨道平面相对于世界坐标系的朝向。
        //    轨道平面的法向量是 L_vec_world = cross(p_rel_initial_cart, world_dir_initial)。
        //    我们需要构建一个从这个轨道平面基到世界坐标基的旋转。

        vec3 final_escape_dir_world_calculated = world_dir_initial;

        if (L_const < EPSILON) { // 近似径向逃逸 (L_const 是初始计算的角动量大小)
            // 对于纯径向运动，逃逸方向就是从黑洞中心指向光线最终位置的方向
             vec3 final_pos_rel_cart = sphericalToCartesian(currentState.r, currentState.theta, currentState.phi);
             if (length(final_pos_rel_cart) > EPSILON) {
                 final_escape_dir_world_calculated = normalize(final_pos_rel_cart);
             } else { // 几乎在中心 (虽然理论上此时应该 alpha=0)
                 final_escape_dir_world_calculated = world_dir_initial;
             }
        } else {
            // 构建轨道平面的世界坐标基：
            // orbit_normal_w 是轨道法向量 (已经计算过 L_vec_world)
            vec3 orbit_normal_w = normalize(L_vec_world);
            // u_plane_w: 轨道平面内的一个参考轴 (例如，初始 p_rel_initial_cart 的方向，如果它在平面内)
            //            或者，更通用地，选择一个与 orbit_normal_w 正交的向量，例如 p_rel_initial_cart 投影到平面上
            //            或者，更简单，选择一个固定的参考方向（如世界X轴）投影到平面上，
            //            只要能形成一个正交基。
            //            让我们尝试用 p_rel_initial_cart (归一化) 作为轨道平面内 phi=0 的方向近似
            vec3 u_plane_w;
            if (length(p_rel_initial_cart) > EPSILON) {
                u_plane_w = normalize(p_rel_initial_cart - dot(p_rel_initial_cart, orbit_normal_w) * orbit_normal_w); // 投影到平面并归一化
                if (length(u_plane_w) < EPSILON) { // 如果 p_rel_initial_cart 与法向量平行 (不太可能除非 L=0)
                    // 重新选择一个 u_plane_w
                    if (abs(orbit_normal_w.x) < 0.9) u_plane_w = normalize(cross(orbit_normal_w, vec3(1,0,0)));
                    else u_plane_w = normalize(cross(orbit_normal_w, vec3(0,1,0)));
                }
            } else { // 如果初始就在黑洞中心 (理论上不太可能且 L 应该为0)
                 u_plane_w = vec3(1,0,0); // 任意选择一个
                 if (abs(dot(u_plane_w, orbit_normal_w)) > 0.9) u_plane_w = vec3(0,1,0); // 确保正交
            }

            vec3 v_plane_w = normalize(cross(orbit_normal_w, u_plane_w)); // 轨道平面内的第二个基向量
            //k_orbit_plane_cart2D.x = dot(world_dir_initial, u_plane_w);
            k_orbit_plane_cart2D.y = dot(world_dir_initial, v_plane_w);
            // 将 k_orbit_plane_cart2D (它在 u_plane_w, v_plane_w 定义的平面内) 转换回世界坐标
            final_escape_dir_world_calculated = normalize(
                k_orbit_plane_cart2D.x * u_plane_w +  // 分量沿 u_plane_w
                k_orbit_plane_cart2D.y * v_plane_w    // 分量沿 v_plane_w
            );
        }
        FragColor = texture(skyboxSampler, final_escape_dir_world_calculated);
//        float L_val_norm = clamp(L_const / 10.0, 0.0, 1.0); // 归一化L_const, 10.0只是示例最大值，需调整
//        FragColor = vec4(L_val_norm, L_val_norm, L_val_norm, 1.0); // 可视化L_const
//        vec3 debug_vec = normalize(world_dir_initial);
//        FragColor = vec4(debug_vec * 0.5 + 0.5, 1.0); // 将 [-1,1] 映射到 [0,1]
    }
}

//// --- 牛顿近似下的光线步进 (基于原始讨论的加速度) ---
//
//// "加速度" 函数 (基于 1/r^4 势能修正项)
//// 注意：这缺少主要的牛顿项 -M*p/r^3
//// h2: 角动量平方 (L^2)
//// p_rel: 相对于黑洞中心的位置向量
//vec3 get_approx_accel(vec3 p_rel, float h2) {
//    float r2 = dot(p_rel, p_rel);
//    if (r2 < 1e-6) return vec3(0.0); // 避免除零
//    float r5 = pow(r2, 2.5);
//    // 使用原始讨论中的形式 (可能需要调整系数或符号以获得期望效果)
//    // 这个系数 1.5 可能与 M=0.5 (Rs=1.0) 相关
//    //return -1.5 * h2 * p_rel / r5; // 使用负号，可尝试正号看看效果
//
//    // --- 如果想加入牛顿项 (更接近物理，但仍非测地线) ---
//     float r3 = r2 * sqrt(r2);
//     vec3 newton_accel = -M * p_rel / r3;
//     return newton_accel - 1.5 * h2 * p_rel / r5; // 牛顿 + 修正
//}
//
//// RK4 积分器接口
//// p_rel: 相对于黑洞中心的位置 (当前步或子步)
//// v:   世界坐标系下的速度/方向 (当前步或子步)
//// h2:  角动量平方 (不变)
//// fp:  输出位置导数 (世界速度 v)
//// fv:  输出速度导数 (世界加速度 a)
//void RK4f_approx(vec3 p_rel, vec3 v, float h2, out vec3 fp, out vec3 fv) {
//    fp = v; // 位置导数是速度
//    fv = get_approx_accel(p_rel, h2); // 使用近似加速度
//}
//
//// 使用 RK4 步进光线 (牛顿近似)
//// world_pos: 输入/输出 世界坐标系下的光线位置
//// world_v:   输入/输出 世界坐标系下的光线速度/方向
//// h2:        角动量平方
//void light_step_approx(inout vec3 world_pos, inout vec3 world_v, float h2) {
//    float dt = STEP_TIME_TOTAL;
//    // 可选：根据到黑洞中心的距离调整步长
//    float dist_to_bh = length(world_pos - blackholeCenterWorld);
//    dt *= max(1.0, dist_to_bh / SchwarzschildRadius);
//
//    vec3 d_p, d_v;
//    vec3 kp1, kp2, kp3, kp4; // 世界速度的中间值
//    vec3 kv1, kv2, kv3, kv4; // 世界加速度的中间值
//
//    // --- RK4 的每个子步骤都需要计算当时的 p_rel ---
//    vec3 p_rel_k1 = world_pos - blackholeCenterWorld;
//    RK4f_approx(p_rel_k1, world_v, h2, kp1, kv1); // 使用 k1 时刻的 p_rel 和 v
//
//    // 计算 k2 子步的世界位置和世界速度
//    vec3 world_pos_k2 = world_pos + 0.5 * dt * kp1;
//    vec3 world_v_k2 = world_v + 0.5 * dt * kv1;
//    vec3 p_rel_k2 = world_pos_k2 - blackholeCenterWorld; // 计算 k2 子步的 p_rel
//    RK4f_approx(p_rel_k2, world_v_k2, h2, kp2, kv2); // 使用 k2 时刻的 p_rel 和 v
//
//    // 计算 k3 子步的世界位置和世界速度
//    vec3 world_pos_k3 = world_pos + 0.5 * dt * kp2;
//    vec3 world_v_k3 = world_v + 0.5 * dt * kv2;
//    vec3 p_rel_k3 = world_pos_k3 - blackholeCenterWorld; // 计算 k3 子步的 p_rel
//    RK4f_approx(p_rel_k3, world_v_k3, h2, kp3, kv3); // 使用 k3 时刻的 p_rel 和 v
//
//    // 计算 k4 子步的世界位置和世界速度
//    vec3 world_pos_k4 = world_pos + 1.0 * dt * kp3;
//    vec3 world_v_k4 = world_v + 1.0 * dt * kv3;
//    vec3 p_rel_k4 = world_pos_k4 - blackholeCenterWorld; // 计算 k4 子步的 p_rel
//    RK4f_approx(p_rel_k4, world_v_k4, h2, kp4, kv4); // 使用 k4 时刻的 p_rel 和 v
//
//    // --- 组合结果，更新世界坐标 ---
//    d_p = dt * (kp1 + 2.0 * kp2 + 2.0 * kp3 + kp4) / 6.0; // 世界位移增量
//    d_v = dt * (kv1 + 2.0 * kv2 + 2.0 * kv3 + kv4) / 6.0; // 世界速度增量
//
//    world_pos += d_p; // 更新世界位置
//    world_v += d_v; // 更新世界速度
//    world_v = normalize(world_v); // 保持方向归一化 (牛顿近似下可选)
//}
//
//// --- 事件视界判断 (简单版本，基于物理半径) ---
//// world_p: 当前光线的世界位置
//void get_event_horizon_simple(inout float alpha_remain, vec3 world_p) {
//    // 计算到黑洞中心的距离平方
//    vec3 vec_to_bh_center = world_p - blackholeCenterWorld;
//    if (dot(vec_to_bh_center, vec_to_bh_center) <= SchwarzschildRadius * SchwarzschildRadius) {
//        alpha_remain = 0.0;
//    }
//    // 注意：仍然没有线段穿越检测
//}
//
//// 更精确的事件视界判断 (线段-球体相交)
//// world_p: 当前光线的世界位置
//// old_world_p: 上一步光线的世界位置
//void get_event_horizon_accurate(inout float alpha_remain, vec3 world_p, vec3 old_world_p) {
//
//    // 1. 首先，还是检查当前点是否已经在内部 (快速排除)
//    vec3 vec_to_bh_center = world_p - blackholeCenterWorld;
//    if (dot(vec_to_bh_center, vec_to_bh_center) <= SchwarzschildRadius * SchwarzschildRadius) {
//        alpha_remain = 0.0;
//        return; // 已经在内部，无需后续判断
//    }
//
//    // 2. 检查连接 old_world_p 和 world_p 的线段是否穿过视界球体
//    vec3 step_vec = world_p - old_world_p;     // 计算步进向量
//    float step_len_sq = dot(step_vec, step_vec); // 步长平方
//
//    // 只有当步长不为零时才进行检测
//    if (step_len_sq > 1e-8) { // 避免步长过小或为零
//        float step_len = sqrt(step_len_sq);
//        vec3 norm_step_dir = step_vec / step_len; // 步进方向 (归一化)
//
//        // --- 使用射线-球体相交函数 ---
//        // 射线起点是上一步的位置 old_world_p
//        // 射线方向是步进方向 norm_step_dir
//        // 球心是黑洞中心 blackholeCenterWorld
//        // 球半径是 SchwarzschildRadius
//        float t = intersectSphere(old_world_p, norm_step_dir, blackholeCenterWorld, SchwarzschildRadius);
//
//        // --- 判断交点是否在线段内 ---
//        // t >= 0.0:      表示射线与球体有交点 (方向正确)
//        // t <= step_len: 表示交点位于从 old_world_p 出发，沿着步进方向，
//        //                不超过当前步长 step_len 的范围内。
//        //                即交点发生在 old_world_p 和 world_p 之间。
//        if (t >= 0.0 && t <= step_len) {
//            alpha_remain = 0.0; // 如果线段与视界相交，则标记为吸收
//        }
//    }
//    // 如果上面的条件都不满足，alpha_remain 保持不变
//}
//void main()
//{
//    // --- 1. 计算初始射线 (世界坐标) ---
//    vec2 uv = gl_FragCoord.xy / iResolution.xy;
//    vec2 ndc = uv * 2.0 - 1.0;
//    float aspectRatio = iResolution.x / iResolution.y;
//    vec4 viewRayDir = vec4(ndc.x * aspectRatio, ndc.y, -1.0, 0.0); // 视图空间方向
//    vec3 world_v = normalize((invViewMatrix * viewRayDir).xyz);  // 初始世界速度/方向 (v)
//    vec3 world_pos = (invViewMatrix * vec4(0.0, 0.0, 0.0, 1.0)).xyz; // 初始世界位置 (pos)
//
//    // --- 2. 初始化积分状态 ---
//    vec3 p_world = world_pos;
//    vec3 v_world = world_v; // 使用 v 作为速度/方向变量
//    float alpha = 1.0;
//
//    // 计算角动量平方 L^2 (h2)
//    vec3 r_vec_for_L = p_world - blackholeCenterWorld; // 用于计算 L2
//    vec3 h_vec = cross(r_vec_for_L, v_world);
//    float L2 = dot(h_vec, h_vec);
//
//    // --- 用于测试坐标转换的变量 ---
//    vec3 p_rel_before_conversion;
//    vec3 spherical_coords;
//    vec3 p_rel_after_conversion;
//    float conversion_error = 0.0;
//    bool test_conversion_this_pixel = (uv.x > 0.2 && uv.x < 0.8 && uv.y > 0.2 && uv.y < 0.8); // 只测试屏幕中心一小块区域
//
//    // --- 3. 光线步进循环 (牛顿近似) ---
//    for (int j = 0; j < MAX_STEPS; j++) {
//        vec3 old_p = p_world; // 保存旧位置（简单视界判断可能不用）
//
//        // 调用牛顿近似的步进函数
//        light_step_approx(p_world, v_world, L2); // 更新 p 和 v
//
//        // --- 在某一步（例如，第一步或最后一步，或每几步）测试坐标转换 ---
//        if (j == 0 || j == MAX_STEPS -1 ) { // 或者 if (mod(float(j), 10.0) == 0.0)
//            p_rel_before_conversion = p_world - blackholeCenterWorld;
//            spherical_coords = cartesianToSpherical(p_rel_before_conversion);
//            p_rel_after_conversion = sphericalToCartesian(spherical_coords.x, spherical_coords.y, spherical_coords.z);
//            conversion_error = length(p_rel_before_conversion - p_rel_after_conversion);
//        }
//
////        // 判断是否落入事件视界 (简单版本)
////        get_event_horizon_simple(alpha, p_world);
//         // 调用更精确的版本
//        get_event_horizon_accurate(alpha, p_world, old_p);
//        if (alpha <= 0.0) {
//            break; // 落入黑洞
//        }
//
//        // 检查是否离得太远，这一步与光子球有关：光线长时间在引力场附近徘徊
//        vec3 dist_vec_from_bh_center = p_world - blackholeCenterWorld;
//        if (dot(dist_vec_from_bh_center, dist_vec_from_bh_center) > MAX_DIST_SQ) {
//            break; // 逃逸
//        }
//    }
//
//   // --- 4. 确定最终颜色 ---
//    // --- 修改为可视化坐标转换的测试结果 ---
//    if (test_conversion_this_pixel) { // 如果希望只在特定区域显示测试结果
//        if (conversion_error < 1e-4) { // 误差很小，显示绿色
//            FragColor = vec4(0.0, 1.0, 0.0, 1.0);
//        } else if (conversion_error < 1e-2) { // 误差稍大，显示黄色
//             FragColor = vec4(1.0, 1.0, 0.0, 1.0);
//        }
//        else { // 误差较大，显示红色
//            FragColor = vec4(1.0, 0.0, 0.0, 1.0);
//        }
//        // 可以进一步输出 spherical_coords 的某个分量来检查其范围
//        // FragColor = vec4(spherical_coords.y / PI, 0.0, 0.0, 1.0); // 可视化 theta (0-1)
//        // FragColor = vec4(fract(spherical_coords.z / TWO_PI), 0.0, 0.0, 1.0); // 可视化 phi (0-1)
//    } else { // 其他像素正常渲染黑洞
//        if (alpha <= 0.0) {
//            FragColor = vec4(0.0, 0.0, 0.0, 1.0); // 黑洞
//        } else {
//            vec3 final_dir = v_world;
//            FragColor = texture(skyboxSampler, final_dir);
//        }
//    }
//    // --- 可视化结束 ---
//
//     // 可选：伽马校正
//     // FragColor = pow(FragColor, vec4(1.0/2.2));
//}




//// --- 临时的、简化的球坐标导数函数 (仅用于测试 RK4 球坐标积分) ---
//// 这个函数暂时不包含复杂的物理，可能只是让粒子以某种方式运动
//// 或者我们可以尝试将笛卡尔加速度近似地转换过来
//struct TempSphericalDerivatives {
//    float dr_dlambda;
//    float dtheta_dlambda;
//    float dphi_dlambda;
//};
//
//
//TempSphericalDerivatives get_temp_spherical_derivatives(
//    vec3 world_pos_current, // 当前世界位置，用于计算相对位置和角动量
//    vec3 world_v_current,   // 当前世界速度/方向
//    float h2_from_cartesian // 从初始笛卡尔状态计算的 h2
//) {
//    TempSphericalDerivatives derivs;
//
//    // 1. 计算相对于黑洞的笛卡尔位置
//    vec3 p_rel_cart = world_pos_current - blackholeCenterWorld;
//
//    // 2. 使用旧的 get_approx_accel 计算笛卡尔加速度
//    vec3 accel_cart = get_approx_accel(p_rel_cart, h2_from_cartesian);
//
//    // 3. 将笛卡尔加速度近似地投影到球坐标方向
//    //    这是一个非常粗略的近似，因为加速度是 d(velocity)/dλ，
//    //    而我们需要的是 d(d(coord)/dλ)/dλ。
//    //    但为了测试球坐标积分，我们可以暂时这么做。
//
//    // 获取当前球坐标 (r, theta, phi)
//    vec3 current_sph = cartesianToSpherical(p_rel_cart);
//    float r = current_sph.x;
//    float theta = current_sph.y;
//    float phi = current_sph.z;
//
//    if (r < 1e-5) { // 避免在原点计算
//        derivs.dr_dlambda = 0.0;
//        derivs.dtheta_dlambda = 0.0;
//        derivs.dphi_dlambda = 0.0;
//        return derivs;
//    }
//
//    // 球坐标系的单位向量 (在笛卡尔下表示)
//    vec3 r_hat = normalize(p_rel_cart); // 径向单位向量
//    vec3 theta_hat; // 极角增加方向的单位向量
//    theta_hat.x = cos(theta) * cos(phi);
//    theta_hat.z = cos(theta) * sin(phi); // 对应 atan(z,x)
//    theta_hat.y = -sin(theta);
//    vec3 phi_hat;   // 方位角增加方向的单位向量
//    phi_hat.x = -sin(phi);
//    phi_hat.z = cos(phi); // 对应 atan(z,x)
//    phi_hat.y = 0.0;
//
//    // 假设 accel_cart 是 d(world_v)/dλ 的近似
//    // 那么 d(dr/dλ)/dλ (即 k_r 的导数) 大致是 accel_cart 在 r_hat 上的投影
//    // d(dθ/dλ)/dλ (即 k_theta 的导数) 大致是 accel_cart 在 theta_hat 上的投影 / r
//    // d(dφ/dλ)/dλ (即 k_phi 的导数) 大致是 accel_cart 在 phi_hat 上的投影 / (r * sin(theta))
//    // 这仍然是二阶导数，我们需要的是一阶导数 dr/dλ, dθ/dλ, dφ/dλ。
//
//    // --- 为了测试球坐标 RK4，让我们做一个更简单的设定 ---
//    // 假设光线以某个恒定的角速度绕行，同时径向速度受某个简单力的影响
//    // 这完全是为了测试球坐标积分流程
//
//    // 例如：简单的螺旋线向内或向外
//    derivs.dr_dlambda = -0.1; // 让它慢慢向内 (或用 +0.1 向外)
//    derivs.dtheta_dlambda = 0.0; // 保持在赤道面
//    derivs.dphi_dlambda = 0.5 / max(r, 0.1); // 角速度随半径减小
//
//    // 或者，我们可以让它尝试保持初始的世界速度方向，然后看球坐标如何变化
//    // 这需要将 world_v_current 转换到球坐标速度分量，这是一个复杂步骤。
//
//    // --- 最简单的测试：恒定球坐标速度分量 (直线运动，除非原点在路径上) ---
//    // derivs.dr_dlambda = 0.1;
//    // derivs.dtheta_dlambda = 0.01; // 如果想测试 theta 变化
//    // derivs.dphi_dlambda = 0.05;
//
//    return derivs;
//}
//// 新的 RK4 步进函数 (在球坐标下)
//PhotonStateSpherical light_step_spherical_RK4(
//    PhotonStateSpherical current_s,
//    float h2_for_temp_derivs, // 传递给临时导数函数的参数
//    vec3 initial_world_v,      // 传递给临时导数函数的参数 (如果需要)
//    float d_lambda             // 仿射参数步长
//) {
//    PhotonStateSpherical next_s = current_s;
//
//    // --- k1 ---
//    // 需要将 current_s (球坐标) 转换回当前世界坐标，以便 get_temp_spherical_derivatives 使用
//    vec3 current_world_pos_rel = sphericalToCartesian(current_s.r, current_s.theta, current_s.phi);
//    vec3 current_world_pos = current_world_pos_rel + blackholeCenterWorld;
//    // 假设 current_world_v 也是随步进更新的，或者用一个简化的近似
//    // 为了测试，get_temp_spherical_derivatives 暂时不强依赖精确的 current_world_v
//    TempSphericalDerivatives deriv1 = get_temp_spherical_derivatives(current_world_pos, initial_world_v, h2_for_temp_derivs); // 使用简化的参数
//
//    // --- k2 ---
//    PhotonStateSpherical s_k2 = current_s;
//    s_k2.r     += 0.5 * d_lambda * deriv1.dr_dlambda;
//    s_k2.theta += 0.5 * d_lambda * deriv1.dtheta_dlambda;
//    s_k2.phi   += 0.5 * d_lambda * deriv1.dphi_dlambda;
//    // 将 s_k2 转回世界坐标
//    vec3 world_pos_k2_rel = sphericalToCartesian(s_k2.r, s_k2.theta, s_k2.phi);
//    vec3 world_pos_k2 = world_pos_k2_rel + blackholeCenterWorld;
//    TempSphericalDerivatives deriv2 = get_temp_spherical_derivatives(world_pos_k2, initial_world_v, h2_for_temp_derivs);
//
//    // --- k3 ---
//    PhotonStateSpherical s_k3 = current_s;
//    s_k3.r     += 0.5 * d_lambda * deriv2.dr_dlambda;
//    s_k3.theta += 0.5 * d_lambda * deriv2.dtheta_dlambda;
//    s_k3.phi   += 0.5 * d_lambda * deriv2.dphi_dlambda;
//    vec3 world_pos_k3_rel = sphericalToCartesian(s_k3.r, s_k3.theta, s_k3.phi);
//    vec3 world_pos_k3 = world_pos_k3_rel + blackholeCenterWorld;
//    TempSphericalDerivatives deriv3 = get_temp_spherical_derivatives(world_pos_k3, initial_world_v, h2_for_temp_derivs);
//
//    // --- k4 ---
//    PhotonStateSpherical s_k4 = current_s;
//    s_k4.r     += d_lambda * deriv3.dr_dlambda;
//    s_k4.theta += d_lambda * deriv3.dtheta_dlambda;
//    s_k4.phi   += d_lambda * deriv3.dphi_dlambda;
//    vec3 world_pos_k4_rel = sphericalToCartesian(s_k4.r, s_k4.theta, s_k4.phi);
//    vec3 world_pos_k4 = world_pos_k4_rel + blackholeCenterWorld;
//    TempSphericalDerivatives deriv4 = get_temp_spherical_derivatives(world_pos_k4, initial_world_v, h2_for_temp_derivs);
//
//    // --- 更新球坐标状态 ---
//    next_s.r     += (d_lambda / 6.0) * (deriv1.dr_dlambda + 2.0 * deriv2.dr_dlambda + 2.0 * deriv3.dr_dlambda + deriv4.dr_dlambda);
//    next_s.theta += (d_lambda / 6.0) * (deriv1.dtheta_dlambda + 2.0 * deriv2.dtheta_dlambda + 2.0 * deriv3.dtheta_dlambda + deriv4.dtheta_dlambda);
//    next_s.phi   += (d_lambda / 6.0) * (deriv1.dphi_dlambda + 2.0 * deriv2.dphi_dlambda + 2.0 * deriv3.dphi_dlambda + deriv4.dphi_dlambda);
//
//    // 确保角度在合理范围 (phi 环绕)
//    next_s.phi = mod(next_s.phi, TWO_PI);
//    if (next_s.phi < 0.0) next_s.phi += TWO_PI;
//    // theta 通常在 [0, PI]，如果积分可能超出需要 clamp 或特殊处理
//
//    return next_s;
//}
//void main()
//{
//    // --- 1. 计算初始射线 (世界坐标) ---
//    vec2 uv = gl_FragCoord.xy / iResolution.xy;
//    vec2 ndc = uv * 2.0 - 1.0;
//    float aspectRatio = iResolution.x / iResolution.y;
//    float focalLength = 1.0;
//    vec4 viewRayDir = vec4(ndc.x * aspectRatio, ndc.y, -focalLength, 0.0);
//    vec3 world_v_initial = normalize((invViewMatrix * viewRayDir).xyz);
//    vec3 world_pos_initial = (invViewMatrix * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
//
//    // --- 2. 初始化状态 ---
//    // 将初始世界坐标转换为相对于黑洞中心的球坐标
//    vec3 p_rel_initial_cart = world_pos_initial - blackholeCenterWorld;
//    vec3 initial_sph_coords = cartesianToSpherical(p_rel_initial_cart); // 直接传入相对向量
//
//    PhotonStateSpherical current_sph_state;
//    current_sph_state.r = initial_sph_coords.x;
//    current_sph_state.theta = initial_sph_coords.y;
//    current_sph_state.phi = initial_sph_coords.z;
//
//    float alpha = 1.0;
//
//    // 计算一个用于临时导数函数的 h2 (基于初始笛卡尔状态)
//    vec3 h_vec_cart = cross(p_rel_initial_cart, world_v_initial);
//    float h2_for_temp = dot(h_vec_cart, h_vec_cart);
//
//    // --- 3. 光线步进循环 (使用球坐标 RK4) ---
//    vec3 final_escape_dir_world = world_v_initial; // 默认逃逸方向
//
//    for (int j = 0; j < MAX_STEPS; j++) {
//        PhotonStateSpherical old_sph_state = current_sph_state;
//
//        // 调用新的球坐标 RK4 步进函数
//        current_sph_state = light_step_spherical_RK4(current_sph_state, h2_for_temp, world_v_initial, STEP_TIME_TOTAL); // STEP_TIME_TOTAL 作为 d_lambda
//
//        // --- 将当前球坐标转换回世界坐标以进行判断 ---
//        vec3 current_p_rel_cart = sphericalToCartesian(current_sph_state.r, current_sph_state.theta, current_sph_state.phi);
//        vec3 current_p_world = current_p_rel_cart + blackholeCenterWorld;
//        // old_p_world 也可以类似转换，如果 get_event_horizon_accurate 需要
//        vec3 old_p_rel_cart = sphericalToCartesian(old_sph_state.r, old_sph_state.theta, old_sph_state.phi);
//        vec3 old_p_world_for_event_horizon = old_p_rel_cart + blackholeCenterWorld;
//
//
//        get_event_horizon_accurate(alpha, current_p_world, old_p_world_for_event_horizon);
//
//        if (alpha <= 0.0) {
//            break;
//        }
//
//        if (current_sph_state.r * current_sph_state.r > MAX_DIST_SQ) { // 直接用球坐标 r 判断
//            // --- 计算最终逃逸方向 (关键且复杂) ---
//            // 当光线逃逸时，我们需要其最终的世界方向。
//            // 这需要从最终的球坐标状态和球坐标速度分量转换回来。
//            // 由于 get_temp_spherical_derivatives 非常简化，最终方向的计算也会不准确。
//            // 暂时，我们用从黑洞中心指向最终球坐标位置的方向作为近似。
//            if (length(current_p_rel_cart) > 1e-5) {
//                 final_escape_dir_world = normalize(current_p_rel_cart);
//            } else {
//                 final_escape_dir_world = world_v_initial; // 如果在中心附近，用初始方向
//            }
//            break;
//        }
//    }
//
//    // --- 4. 确定最终颜色 ---
//    if (alpha <= 0.0) {
//        FragColor = vec4(0.0, 0.0, 0.0, 1.0); // 黑洞
//    } else {
//        FragColor = texture(skyboxSampler, final_escape_dir_world);
//    }
//}
