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
const int MAX_STEPS = 1200;              // 积分步数 (根据效果和性能调整)
const int MAX_R = 30; 
const float STEP_TIME_TOTAL = 0.001;   // 基础步长因子 (需要调整!)
const float PI = 3.14159265359;
const float TWO_PI = 2.0 * PI;

const float D_LAMBDA = 0.005;        // 仿射参数步长 dλ (需要仔细调整)
const float MAX_R_TRACE = 5000.0;     // 最大追踪半径 (倍数于 Rs，或绝对值)
const float EPSILON = 1e-5; // 或者 1e-4, 1e-6，取决于你需要的精度和场景尺度
float D_LAMBDA_MIN = 0.005;
float D_LAMBDA_MAX = 0.01;
float R_CLOSE_TO_BH = SchwarzschildRadius * 3.0; // 定义一个“靠近黑洞”的区域，例如3倍史瓦西半径
float R_FAR_FROM_BH = SchwarzschildRadius * 30.0; // 定义一个“远离黑洞”的区域
float D_LAMBDA_BASE = D_LAMBDA;

const int NUM_SUB_RAYS = 3; // 每个像素发射的光线数量 (可以设为 uniform 从 C++ 控制)
const float JITTER_STRENGTH = 0.5; // 抖动强度，0.5 表示在当前像素的 [-0.5, 0.5] 范围内抖动
// --- 工具函数 ---
// --- 一个简单的伪随机数生成器 ---
// 输入一个 vec2 的种子 (例如基于 gl_FragCoord 和循环索引)
// 输出一个 [0,1) 范围的伪随机浮点数
float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

// 生成一个 vec2 的随机数 [0,1) x [0,1)
vec2 rand2(vec2 co) {
    return vec2(rand(co), rand(co + vec2(1.234, 5.678))); // 轻微改变种子以获得不同的随机数
}

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
    float L_const, // L_const 是总角动量大小
    float L_z_for_dphi
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
    derivs.dphi_dlambda = L_z_for_dphi  / (r2 * sin2_theta); // 如果假设赤道面，sin2_theta = 1

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
    PhotonStateSpherical currentState,
    float k_r_direction_current,
    float E_const,
    float L_const,
    float d_lambda,
    float L_z_effective
) {
    StepResult result;
    result.next_k_r_direction = k_r_direction_current; // 默认保持

    PhotonStateSpherical s = currentState; // 当前状态

    // k1
    PhotonStateSpherical deriv1 = get_schwarzschild_geodesic_derivatives(s.r, s.theta, E_const, L_const,L_z_effective);
    float dr1 = k_r_direction_current * deriv1.dr_dlambda;
    float dt1 = 0.0; // deriv1.dtheta_dlambda; // 简化为0
    float dp1 = deriv1.dphi_dlambda;

    // k2
    PhotonStateSpherical deriv2 = get_schwarzschild_geodesic_derivatives(s.r + 0.5 * d_lambda * dr1, s.theta, E_const, L_const,L_z_effective);
    // 估算 k2 时的 k_r 符号（简化：假设不变，除非 dr1=0）
    //float k_r_dir2 = k_r_direction_current; if(dr1==0.0 && deriv1.dr_dlambda != 0.0) k_r_dir2 = (deriv1.dr_dlambda > 0.0 ? 1.0: -1.0);
    float dr2 = k_r_direction_current * deriv2.dr_dlambda;
    float dp2 = deriv2.dphi_dlambda;

    // k3
    PhotonStateSpherical deriv3 = get_schwarzschild_geodesic_derivatives(s.r + 0.5 * d_lambda * dr2, s.theta, E_const, L_const,L_z_effective);
    //float k_r_dir3 = k_r_dir2; if(dr2==0.0 && deriv2.dr_dlambda != 0.0) k_r_dir3 = (deriv2.dr_dlambda > 0.0 ? 1.0: -1.0);
    float dr3 = k_r_direction_current * deriv3.dr_dlambda;
    float dp3 = deriv3.dphi_dlambda;

    // k4
    PhotonStateSpherical deriv4 = get_schwarzschild_geodesic_derivatives(s.r + d_lambda * dr3, s.theta, E_const, L_const,L_z_effective);
    //float k_r_dir4 = k_r_dir3; if(dr3==0.0 && deriv3.dr_dlambda != 0.0) k_r_dir4 = (deriv3.dr_dlambda > 0.0 ? 1.0: -1.0);
    float dr4 = k_r_direction_current * deriv4.dr_dlambda;
    float dp4 = deriv4.dphi_dlambda;

    // 更新状态
    result.next_state.r = s.r + (d_lambda / 6.0) * (dr1 + 2.0 * dr2 + 2.0 * dr3 + dr4);
    result.next_state.theta = s.theta; // theta 保持不变
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
        PhotonStateSpherical final_derivs_check = get_schwarzschild_geodesic_derivatives(result.next_state.r, result.next_state.theta, E_const, L_const,L_z_effective);
        if (final_derivs_check.dr_dlambda == 0.0 && deriv1.dr_dlambda != 0.0) { // 刚到达转折点
            result.next_k_r_direction = -k_r_direction_current; // 尝试反转
        }
    }


    return result;
}


vec3 traceSingleRay(
    vec3 world_pos_initial,
    vec3 world_dir_initial,
    float E_const_val, // 能量
    vec3 L_vec_world_val, // 角动量矢量 (用于计算 L_const 和 L_z_effective)
    vec3 orbit_normal_w_basis_for_Lz_sign, // 用于计算Lz符号的参考法线
    // --- 其他需要传入的uniforms或常量 ---
    float current_SchwarzschildRadius,
    vec3 current_blackholeCenterWorld,
    samplerCube current_skyboxSampler
)
{
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
    float L_const = length(L_vec_world); // 总角动量大小，在dot(world_dir_initial, p_rel_initial_cart)=0处是连续的
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

    vec3 orbit_normal_w_for_basis;

    if (L_const > EPSILON) {
        orbit_normal_w_for_basis = normalize(L_vec_world);
       
    } else {
        // L=0，纯径向，orbit_normal_w_for_basis 方向不重要，因为 dphi/dlambda 会是0
        // 但为了后续 u_plane_w, v_plane_w 计算不失败，给一个默认值
        orbit_normal_w_for_basis = vec3(0.0, 1.0, 0.0); // 任意选择
        if (length(p_rel_initial_cart) > EPSILON && abs(dot(normalize(p_rel_initial_cart), orbit_normal_w_for_basis)) > 0.99) {
                orbit_normal_w_for_basis = vec3(1.0, 0.0, 0.0); // 避免与p_rel_initial_cart平行
        }
    }
    float L_z_effective = dot(L_vec_world, orbit_normal_w_for_basis);
    // --- 3. 光线积分循环 ---
    float alpha = 1.0; // 标记是否落入
    vec3 final_escape_dir_world = world_dir_initial; // 默认逃逸方向

    for (int j = 0; j < MAX_STEPS; j++) {
        // 简单事件视界判断 (基于当前球坐标 r)
        if (currentState.r <= SchwarzschildRadius) {
            alpha = 0.0;
            break;
        }
//        else if(currentState.r < MAX_R)
//        {
//            j = MAX_STEPS-2;
//        }
        // ... (在 main() 函数的积分循环之后，逃逸分支内) ...
        if (currentState.r > MAX_R_TRACE * SchwarzschildRadius) {
            break; // 逃逸
        }
        

        if (k_r_direction == 0.0 && currentState.r > SchwarzschildRadius) { // 卡在转折点外面
             final_escape_dir_world = world_dir_initial; // 无法前进，视为直接逃逸
             break;
        }
        float scale_factor_based_on_r;
        float next_d_lambda;
        //自适应步长：
        {
            if (currentState.r < R_CLOSE_TO_BH) {
                // 非常靠近黑洞，使用接近最小的步长
                // 可以线性插值，或者直接设为较小值
                scale_factor_based_on_r = D_LAMBDA_MIN / D_LAMBDA_BASE; // D_LAMBDA_BASE 是一个基础步长
                                                                    // 或者直接 next_d_lambda = D_LAMBDA_MIN;
                // 更平滑的过渡：
                // float t = clamp((currentState.r - SchwarzschildRadius) / (R_CLOSE_TO_BH - SchwarzschildRadius), 0.0, 1.0);
                // next_d_lambda = mix(D_LAMBDA_MIN, D_LAMBDA_BASE * 0.5, t); // 在 Rs 和 R_CLOSE_TO_BH 之间插值
                next_d_lambda = D_LAMBDA_MIN; // 简单粗暴版

            } else if (currentState.r > R_FAR_FROM_BH) {
                // 远离黑洞，可以使用接近最大的步长
                next_d_lambda = D_LAMBDA_MAX;
            } else {
                // 在中间区域，可以进行线性或非线性插值
                // 线性插值示例:
                float t = (currentState.r - R_CLOSE_TO_BH) / (R_FAR_FROM_BH - R_CLOSE_TO_BH);
                // 目标步长可以从 D_LAMBDA_MIN (或一个略大一点的值) 插值到 D_LAMBDA_MAX (或一个略小一点的值)
                next_d_lambda = mix(D_LAMBDA_MIN * 2.0, D_LAMBDA_MAX * 0.8, t); // 示例插值
            }

            next_d_lambda = clamp(next_d_lambda, D_LAMBDA_MIN, D_LAMBDA_MAX);
        }
        // 执行 RK4 步进
        StepResult step_res = light_step_geodesic_spherical(currentState, k_r_direction, E_const, L_const, next_d_lambda,L_z_effective);
        currentState = step_res.next_state;
        k_r_direction = step_res.next_k_r_direction;
    }

    // --- 4. 确定最终颜色 ---
    if (alpha <= 0.0) { // 或者 if (currentState.r <= SchwarzschildRadius)
        return vec3(0.0, 0.0, 0.0); // 黑洞
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
        
        PhotonStateSpherical final_derivs_mag = get_schwarzschild_geodesic_derivatives(currentState.r, currentState.theta, E_const, L_const,L_z_effective);
        // 2. 应用最后一次有效的径向速度符号 (这个 k_r_direction 是循环结束时的值)
        float final_dr_dl = k_r_direction*final_derivs_mag.dr_dlambda;
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
        } 
        else 
        {
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
//            k_orbit_plane_cart2D.y = dot(world_dir_initial, v_plane_w);
//            k_orbit_plane_cart2D.x = dot(world_dir_initial, u_plane_w);
            // 将 k_orbit_plane_cart2D (它在 u_plane_w, v_plane_w 定义的平面内) 转换回世界坐标
            final_escape_dir_world_calculated = normalize(
                k_orbit_plane_cart2D.x * u_plane_w +  // 分量沿 u_plane_w
                k_orbit_plane_cart2D.y * v_plane_w    // 分量沿 v_plane_w
            );
        }
        return texture(current_skyboxSampler, final_escape_dir_world_calculated).rgb;
    }
}

void main()
{
    // 原始的相机射线原点 (对于所有子光线通常是相同的，如果是针孔相机模型)
    vec3 world_pos_pinhole = (invViewMatrix * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

    vec3 accumulated_color = vec3(0.0);
    float aspectRatio = iResolution.x / iResolution.y;
    float focalLength = 1.0;

    for (int i = 0; i < NUM_SUB_RAYS; i++) {
        // 1. 为当前子光线生成随机偏移 (抖动像素坐标)
        //    使用 gl_FragCoord 和循环索引 i 作为随机种子，确保每个子光线偏移不同
        vec2 random_seed = gl_FragCoord.xy + vec2(float(i) * 0.137, float(i) * 0.793); // 改变种子
        vec2 offset = (rand2(random_seed) - 0.5) * JITTER_STRENGTH * 2.0; // 偏移范围 [-JITTER_STRENGTH, JITTER_STRENGTH]
                                                                      // 如果 JITTER_STRENGTH = 0.5, 范围是 [-0.5, 0.5] 像素

        // 2. 计算被扰动过的子光线的NDC坐标
        vec2 jittered_frag_coord = gl_FragCoord.xy + offset;
        vec2 sub_uv = jittered_frag_coord / iResolution.xy;
        vec2 sub_ndc = sub_uv * 2.0 - 1.0;

        // 3. 计算子光线的初始方向
        vec4 viewRayDir_sub = vec4(sub_ndc.x * aspectRatio, sub_ndc.y, -focalLength, 0.0);
        vec3 world_dir_sub = normalize((invViewMatrix * viewRayDir_sub).xyz);

        // 4. 计算该子光线的初始角动量和相关守恒量 (这些对每条子光线都可能不同)
        vec3 p_rel_initial_cart_sub = world_pos_pinhole - blackholeCenterWorld; // 相对于黑洞的初始位置矢量
        vec3 L_vec_world_sub = cross(p_rel_initial_cart_sub, world_dir_sub);

        // 稳定化轨道法线并计算Lz符号的参考 (对每条子光线)
        vec3 orbit_normal_w_basis_sub;
        if (length(L_vec_world_sub) > EPSILON) {
            orbit_normal_w_basis_sub = normalize(L_vec_world_sub);
            // 可选的稳定化 (例如，让Y分量为正)
            if (orbit_normal_w_basis_sub.y < -1e-4) orbit_normal_w_basis_sub *= -1.0;
            else if (abs(orbit_normal_w_basis_sub.y) < 1e-4 && orbit_normal_w_basis_sub.z < -1e-4) orbit_normal_w_basis_sub *= -1.0;
            // ... (更完整的稳定化)
        } else {
            // 默认法线 (当L=0时，phi的旋转不重要，但基向量需要定义)
             if (length(p_rel_initial_cart_sub) > EPSILON) {
                vec3 temp_up = vec3(0.0, 1.0, 0.0);
                if (abs(dot(normalize(p_rel_initial_cart_sub), temp_up)) > 0.99) temp_up = vec3(1.0, 0.0, 0.0);
                orbit_normal_w_basis_sub = normalize(cross(normalize(p_rel_initial_cart_sub), temp_up));
            } else orbit_normal_w_basis_sub = vec3(0.0, 0.0, 1.0);
        }


        // 5. 调用追踪函数
        vec3 sub_ray_color = traceSingleRay(
                                world_pos_pinhole,
                                world_dir_sub,
                                1, // 通常是1.0
                                L_vec_world_sub, // 传递整个矢量
                                orbit_normal_w_basis_sub, // 传递用于Lz符号的参考法线
                                SchwarzschildRadius,
                                blackholeCenterWorld,
                                skyboxSampler
                            );

        accumulated_color += sub_ray_color;
    }

    FragColor = vec4(accumulated_color / float(NUM_SUB_RAYS), 1.0);
}
