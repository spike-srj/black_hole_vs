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

// --- 新增：吸积盘参数 ---
const float ACCRETION_DISK_INNER_RADIUS = 3.0;  // 吸积盘内半径（以史瓦西半径为单位）
const float ACCRETION_DISK_OUTER_RADIUS = 12.0; // 吸积盘外半径（以史瓦西半径为单位）
const float ACCRETION_DISK_THICKNESS = 2.0;     // 吸积盘厚度（以史瓦西半径为单位）
const int ACCRETION_SAMPLES = 64;                // 吸积盘积分采样数
const float DISK_TEMPERATURE_SCALE = 5000.0;    // 温度缩放因子
const vec3 DISK_BASE_COLOR = vec3(1.0, 0.6, 0.2); // 吸积盘基础颜色（橙红色）

// --- 常量 ---
const int MAX_STEPS = 2000;              // 增加步数确保光线能到达视界
const float MAX_DIST_SQ = 200.0;   // 最大追踪距离平方
const float PI = 3.14159265359;
const float TWO_PI = 2.0 * PI;

// 新的自适应步长参数
const float D_LAMBDA_MIN = 0.002;     // 适当增大最小步长以提高效率
const float D_LAMBDA_MAX = 0.1;       // 增大最大步长
const float MAX_R_TRACE = 1000.0;     // 减小最大追踪半径，提高效率

// 新增：k_r_direction 稳定化参数
const float TURNING_EPS = 1e-4;       // 转折点检测阈值
const int FREEZE_STEPS = 2;           // 减少冻结步数
const float EPSILON = 1e-5;

// --- 新增：吸积盘相关函数 ---

// 检查某个位置是否在吸积盘内
bool isInAccretionDisk(vec3 pos_relative_to_blackhole) {
    // 吸积盘在赤道面上（y=0 为中心），有一定厚度
    float disk_inner_r = ACCRETION_DISK_INNER_RADIUS * SchwarzschildRadius;
    float disk_outer_r = ACCRETION_DISK_OUTER_RADIUS * SchwarzschildRadius;
    float disk_half_thickness = ACCRETION_DISK_THICKNESS * SchwarzschildRadius * 0.5;
    
    // 计算径向距离（在xz平面内）
    float r_disk = sqrt(pos_relative_to_blackhole.x * pos_relative_to_blackhole.x + 
                       pos_relative_to_blackhole.z * pos_relative_to_blackhole.z);
    
    // 检查是否在径向范围内
    if (r_disk < disk_inner_r || r_disk > disk_outer_r) return false;
    
    // 检查是否在厚度范围内
    if (abs(pos_relative_to_blackhole.y) > disk_half_thickness) return false;
    
    return true;
}

// 计算吸积盘在某点的辐射强度
float getDiskEmission(vec3 pos_relative_to_blackhole) {
    // 计算径向距离（在xz平面内，这是吸积盘的物理半径）
    float r_disk = sqrt(pos_relative_to_blackhole.x * pos_relative_to_blackhole.x + 
                       pos_relative_to_blackhole.z * pos_relative_to_blackhole.z);
    
    float disk_inner_r = ACCRETION_DISK_INNER_RADIUS * SchwarzschildRadius;
    float disk_outer_r = ACCRETION_DISK_OUTER_RADIUS * SchwarzschildRadius;
    
    if (r_disk < disk_inner_r || r_disk > disk_outer_r) return 0.0;
    
    // 基于距离的温度模型：越靠近黑洞越热（使用盘半径而不是3D距离）
    float temperature_factor = disk_inner_r / r_disk;
    temperature_factor = pow(temperature_factor, 0.75); // 调整温度梯度
    
    // 基于高度的密度衰减 - 调整衰减更慢，让盘更厚实
    float height_factor = exp(-abs(pos_relative_to_blackhole.y) / (ACCRETION_DISK_THICKNESS * SchwarzschildRadius * 0.8));
    
    return temperature_factor * height_factor * DISK_TEMPERATURE_SCALE;
}

// 将温度转换为颜色（简化的黑体辐射）
vec3 temperatureToColor(float temperature) {
    // 归一化温度
    float t_norm = clamp(temperature / DISK_TEMPERATURE_SCALE, 0.0, 1.0);
    
    // 简化的黑体辐射颜色映射
    vec3 cold_color = vec3(1.0, 0.3, 0.1);   // 红色（低温）
    vec3 warm_color = vec3(1.0, 0.8, 0.4);   // 橙色（中温）  
    vec3 hot_color = vec3(0.8, 0.9, 1.0);    // 蓝白色（高温）
    
    vec3 color;
    if (t_norm < 0.5) {
        color = mix(cold_color, warm_color, t_norm * 2.0);
    } else {
        color = mix(warm_color, hot_color, (t_norm - 0.5) * 2.0);
    }
    
    return color * t_norm * 1.5; // 亮度也随温度增加
}

// --- 工具函数 ---

// 更严谨的自适应步长函数
float geodesicStepSize(float r) {
    float rs = SchwarzschildRadius;
    
    // ① 视界附近：极小步长
    if (r < 2.0 * rs) {
        return D_LAMBDA_MIN;
    }
    // ② 光子球 ~ 外层势阱：中等步长，依据距离衰减
    else if (r < 10.0 * rs) {
        float t = (r - 2.0 * rs) / (8.0 * rs);
        return mix(D_LAMBDA_MIN, 0.02, t);
    }
    // ③ 远场：最大步长
    else {
        return D_LAMBDA_MAX;
    }
}

// --- 结构体：光子在球坐标下的状态 ---
struct PhotonStateSpherical {
    float r;     // 径向坐标 (相对于黑洞中心)
    float theta; // 极角 (0 到 PI, 通常我们假设运动在赤道面 theta=PI/2)
    float phi;   // 方位角 (0 到 2*PI)

    // 四维速度的球坐标空间分量 (或者直接用 dr/dλ, dθ/dλ, dφ/dλ)
    float dr_dlambda;
    float dtheta_dlambda;
    float dphi_dlambda;
};

// --- 坐标转换函数 ---
vec3 cartesianToSpherical(vec3 p_cart_relative) {
    float r = length(p_cart_relative);
    if (r < 1e-6) return vec3(0.0, 0.0, 0.0);
    float theta = acos(clamp(p_cart_relative.y / r, -1.0, 1.0));
    float phi = atan(p_cart_relative.z, p_cart_relative.x);
    if (phi < 0.0) phi += TWO_PI;
    return vec3(r, theta, phi);
}

vec3 sphericalToCartesian(float r, float theta, float phi) {
    vec3 p_cart_relative;
    p_cart_relative.x = r * sin(theta) * cos(phi);
    p_cart_relative.z = r * sin(theta) * sin(phi);
    p_cart_relative.y = r * cos(theta);
    return p_cart_relative;
}

// --- 史瓦西度规下的光子一阶 ODE 系统 ---
PhotonStateSpherical get_schwarzschild_geodesic_derivatives(
    float r,
    float theta,
    float E_const,
    float L_const,
    float L_z_for_dphi
) {
    PhotonStateSpherical derivs;
    derivs.r = 0.0; derivs.theta = 0.0; derivs.phi = 0.0;
    derivs.dr_dlambda = 0.0; derivs.dtheta_dlambda = 0.0; derivs.dphi_dlambda = 0.0;

    if (r <= SchwarzschildRadius * 1.001 || r < 1e-5) {
        return derivs;
    }

    float r2 = r * r;
    float sin_theta = sin(theta);
    float sin2_theta = sin_theta * sin_theta;

    if (abs(sin2_theta) < 1e-6) {
        sin2_theta = 1e-6;
    }

    // dφ/dλ = L / (r² sin²θ)
    derivs.dphi_dlambda = L_z_for_dphi / (r2 * sin2_theta);

    // 简化：赤道面运动
    derivs.dtheta_dlambda = 0.0;

    float term_L_r_potential = (L_const * L_const / r2) * (1.0 - SchwarzschildRadius / r);
    float dr_dlambda_sq = E_const * E_const - term_L_r_potential;

    if (dr_dlambda_sq < 0.0) {
        derivs.dr_dlambda = 0.0;
    } else {
        derivs.dr_dlambda = sqrt(dr_dlambda_sq);
    }

    return derivs;
}

// 修改后的 StepResult 结构体，包含实际的 dr/dλ 值
struct StepResult {
    PhotonStateSpherical next_state;
    float next_k_r_direction;
    float dr_dlambda_actual;  // 新增：实际的 dr/dλ 值（无符号）
};

// 修改后的 RK4 步进函数
StepResult light_step_geodesic_spherical(
    PhotonStateSpherical currentState,
    float k_r_direction_current,
    float E_const,
    float L_magnitude_const,
    float d_lambda,
    float L_z_effective
) {
    StepResult result;
    result.next_k_r_direction = k_r_direction_current;

    PhotonStateSpherical s = currentState;

    // k1
    PhotonStateSpherical deriv1 = get_schwarzschild_geodesic_derivatives(s.r, s.theta, E_const, L_magnitude_const, L_z_effective);
    float dr1 = k_r_direction_current * deriv1.dr_dlambda;
    float dt1 = 0.0;
    float dp1 = deriv1.dphi_dlambda;

    // k2
    PhotonStateSpherical deriv2 = get_schwarzschild_geodesic_derivatives(s.r + 0.5 * d_lambda * dr1, s.theta, E_const, L_magnitude_const, L_z_effective);
    float dr2 = k_r_direction_current * deriv2.dr_dlambda;
    float dt2 = 0.0;
    float dp2 = deriv2.dphi_dlambda;

    // k3
    PhotonStateSpherical deriv3 = get_schwarzschild_geodesic_derivatives(s.r + 0.5 * d_lambda * dr2, s.theta, E_const, L_magnitude_const, L_z_effective);
    float dr3 = k_r_direction_current * deriv3.dr_dlambda;
    float dt3 = 0.0;
    float dp3 = deriv3.dphi_dlambda;

    // k4
    PhotonStateSpherical deriv4 = get_schwarzschild_geodesic_derivatives(s.r + d_lambda * dr3, s.theta, E_const, L_magnitude_const, L_z_effective);
    float dr4 = k_r_direction_current * deriv4.dr_dlambda;
    float dt4 = 0.0;
    float dp4 = deriv4.dphi_dlambda;

    // 更新状态
    result.next_state.r = s.r + (d_lambda / 6.0) * (dr1 + 2.0 * dr2 + 2.0 * dr3 + dr4);
    result.next_state.theta = s.theta;
    result.next_state.phi = s.phi + (d_lambda / 6.0) * (dp1 + 2.0 * dp2 + 2.0 * dp3 + dp4);

    // 计算最终位置的实际 dr/dλ（无符号）
    PhotonStateSpherical final_derivs = get_schwarzschild_geodesic_derivatives(
        result.next_state.r, result.next_state.theta, E_const, L_magnitude_const, L_z_effective);
    result.dr_dlambda_actual = final_derivs.dr_dlambda;

    // 修复的 k_r_direction 更新逻辑
    float r_new = result.next_state.r;
    float r_old = s.r;
    
    // 强制视界内向内
    if (r_new < SchwarzschildRadius * 1.01) {
        result.next_k_r_direction = -1.0;
    }
    // 恢复必要的转折点检测
    else {
        // 计算有效势能
        float r2_new = r_new * r_new;
        float term_L_r_potential = (L_magnitude_const * L_magnitude_const / r2_new) * (1.0 - SchwarzschildRadius / r_new);
        float dr_dlambda_sq = E_const * E_const - term_L_r_potential;
        
        // 检查是否在禁止区域（转折点）
        if (dr_dlambda_sq < -1e-6) {
            // 明确在禁止区域，必须反转
            result.next_k_r_direction = -k_r_direction_current;
        }
        else if (abs(dr_dlambda_sq) < 1e-6) {
            // 在转折点附近，反转方向
            result.next_k_r_direction = -k_r_direction_current;
        }
        else {
            // 在允许区域，根据实际运动方向微调
            float r_change = r_new - r_old;
            if (abs(r_change) > 1e-8) {
                float suggested_direction = (r_change > 0.0) ? 1.0 : -1.0;
                result.next_k_r_direction = suggested_direction;
            } else {
                // r变化很小，保持当前方向
                result.next_k_r_direction = k_r_direction_current;
            }
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
    vec3 world_dir_initial = normalize((invViewMatrix * viewRayDir).xyz);
    vec3 world_pos_initial = (invViewMatrix * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

    // --- 2. 转换到以黑洞为中心的球坐标并计算守恒量 ---
    vec3 p_rel_initial_cart = world_pos_initial - blackholeCenterWorld;
    vec3 initial_sph_coords = cartesianToSpherical(p_rel_initial_cart);

    PhotonStateSpherical currentState;
    currentState.r = initial_sph_coords.x;
    currentState.theta = PI / 2.0;  // 赤道面
    currentState.phi = 0.0;

    // 计算守恒量
    vec3 L_vec_world = cross(p_rel_initial_cart, world_dir_initial);
    float L_const = length(L_vec_world);
    float E_const = 1.0;

    vec3 orbit_normal_w_for_basis;
    if (L_const > EPSILON) {
        orbit_normal_w_for_basis = normalize(L_vec_world);
    } else {
        orbit_normal_w_for_basis = vec3(0.0, 1.0, 0.0);
        if (length(p_rel_initial_cart) > EPSILON && 
            abs(dot(normalize(p_rel_initial_cart), orbit_normal_w_for_basis)) > 0.99) {
            orbit_normal_w_for_basis = vec3(1.0, 0.0, 0.0);
        }
    }
    float L_z_effective = dot(L_vec_world, orbit_normal_w_for_basis);

    // 改进的初始 k_r_direction 计算
    float k_r_direction;
    if (L_const < EPSILON) {
        // 纯径向运动
        k_r_direction = (dot(world_dir_initial, p_rel_initial_cart) < 0.0) ? -1.0 : 1.0;
    } else {
        // 有角动量的情况，使用更稳定的判断
        float dot_product = dot(world_dir_initial, p_rel_initial_cart);
        if (abs(dot_product) < 0.1) {
            // 接近切向运动，基于势能判断
            float r2 = currentState.r * currentState.r;
            float V_eff = (L_const * L_const / r2) * (1.0 - SchwarzschildRadius / currentState.r);
            float dr_sq = E_const * E_const - V_eff;
            k_r_direction = (dr_sq > 0.0) ? 1.0 : -1.0;  // 默认向外
        } else {
            k_r_direction = (dot_product < 0.0) ? -1.0 : 1.0;
        }
    }

    if (currentState.r < SchwarzschildRadius * 1.01) {
        k_r_direction = -1.0;  // 视界附近强制向内
    }

    // --- 3. 光线积分循环（带迟滞机制和吸积盘积分） ---
    float alpha = 1.0;
    vec3 final_escape_dir_world = world_dir_initial;
    vec3 accumulated_disk_emission = vec3(0.0); // 累积的吸积盘辐射
    
    // 新增：迟滞和冻结机制变量
    float prev_dr_dl = 0.0;
    int freeze_counter = 0;
    bool first_step = true;

    for (int j = 0; j < MAX_STEPS; j++) {
        // 视界判断
        if (currentState.r <= SchwarzschildRadius + 1e-3) {
            alpha = 0.0;
            break;
        }
        
        // 逃逸判断
        if (currentState.r > MAX_R_TRACE * SchwarzschildRadius) {
            break;
        }
        
        // 卡住判断
        if (k_r_direction == 0.0 && currentState.r > SchwarzschildRadius) {
            final_escape_dir_world = world_dir_initial;
            break;
        }
        
        // 使用改进的自适应步长
        float next_d_lambda = geodesicStepSize(currentState.r);
        
        // 执行 RK4 步进
        StepResult step_res = light_step_geodesic_spherical(
            currentState, k_r_direction, E_const, L_const, next_d_lambda, L_z_effective);
        
        // 检查当前位置是否在吸积盘内，如果是则累积辐射
        vec3 current_pos_cart = sphericalToCartesian(currentState.r, currentState.theta, currentState.phi);
        if (isInAccretionDisk(current_pos_cart)) {
            float emission = getDiskEmission(current_pos_cart);
            if (emission > 0.0) {
                vec3 emission_color = temperatureToColor(emission);
                // 使用步长作为积分权重，模拟体积元
                accumulated_disk_emission += emission_color * next_d_lambda * 0.05;
            }
        }
        
        currentState = step_res.next_state;
        
        // 新的 k_r_direction 更新逻辑（带迟滞）
        if (!first_step && freeze_counter <= 0) {
            // 检查是否真正穿越了转折点
            float new_sign = sign(prev_dr_dl * step_res.dr_dlambda_actual);
            
            if (abs(step_res.dr_dlambda_actual) < TURNING_EPS && new_sign < -0.5) {
                // 确实在转折点附近且符号相反
                k_r_direction = -k_r_direction;
                freeze_counter = FREEZE_STEPS;
            } else if (abs(step_res.dr_dlambda_actual) < TURNING_EPS) {
                // 在转折点但不确定，保持当前方向
                // k_r_direction 不变
            } else {
                // 正常运动，根据实际径向变化微调方向
                float r_change = currentState.r - (currentState.r - (next_d_lambda / 6.0) * 
                    (step_res.dr_dlambda_actual * k_r_direction * 4.0)); // 简化估算
                if (abs(r_change) > 1e-6) {
                    float suggested_direction = (r_change > 0.0) ? 1.0 : -1.0;
                    // 只有在建议方向与当前方向差异很大时才考虑更改
                    if (suggested_direction * k_r_direction < 0.0 && 
                        abs(step_res.dr_dlambda_actual) > TURNING_EPS * 10.0) {
                        k_r_direction = suggested_direction;
                        freeze_counter = FREEZE_STEPS / 2;  // 较短的冻结期
                    }
                }
            }
        }
        
        // 更新状态
        prev_dr_dl = step_res.dr_dlambda_actual * k_r_direction;
        if (freeze_counter > 0) freeze_counter--;
        first_step = false;
        
        // 强制视界检查（覆盖上面的逻辑）
        if (currentState.r < SchwarzschildRadius * 1.01) {
            k_r_direction = -1.0;
            freeze_counter = 0;  // 清除冻结
        }
    }

    // --- 4. 确定最终颜色 ---
    vec3 final_color = vec3(0.0);
    
    if (alpha <= 0.0) {
        // 光线掉入黑洞
        final_color = vec3(0.0, 0.0, 0.0);
    } else {
        // 光线逃逸，计算最终方向并获取天空盒颜色
        PhotonStateSpherical final_derivs_mag = get_schwarzschild_geodesic_derivatives(
            currentState.r, currentState.theta, E_const, L_const, L_z_effective);
        
        float final_dr_dl = k_r_direction * final_derivs_mag.dr_dlambda;
        float final_dphi_dl = final_derivs_mag.dphi_dlambda;

        vec2 k_orbit_plane_cart2D;
        float sin_phi_final = sin(currentState.phi);
        float cos_phi_final = cos(currentState.phi);

        k_orbit_plane_cart2D.x = final_dr_dl * cos_phi_final - currentState.r * final_dphi_dl * sin_phi_final;
        k_orbit_plane_cart2D.y = final_dr_dl * sin_phi_final + currentState.r * final_dphi_dl * cos_phi_final;

        vec3 final_escape_dir_world_calculated = world_dir_initial;

        if (L_const < EPSILON) {
            // 纯径向逃逸
            vec3 final_pos_rel_cart = sphericalToCartesian(currentState.r, currentState.theta, currentState.phi);
            if (length(final_pos_rel_cart) > EPSILON) {
                final_escape_dir_world_calculated = normalize(final_pos_rel_cart);
            } else {
                final_escape_dir_world_calculated = world_dir_initial;
            }
        } else {
            // 有角动量的情况
            vec3 orbit_normal_w = normalize(L_vec_world);
            vec3 u_plane_w;
            if (length(p_rel_initial_cart) > EPSILON) {
                u_plane_w = normalize(p_rel_initial_cart - dot(p_rel_initial_cart, orbit_normal_w) * orbit_normal_w);
                if (length(u_plane_w) < EPSILON) {
                    if (abs(orbit_normal_w.x) < 0.9) u_plane_w = normalize(cross(orbit_normal_w, vec3(1,0,0)));
                    else u_plane_w = normalize(cross(orbit_normal_w, vec3(0,1,0)));
                }
            } else {
                u_plane_w = vec3(1,0,0);
                if (abs(dot(u_plane_w, orbit_normal_w)) > 0.9) u_plane_w = vec3(0,1,0);
            }

            vec3 v_plane_w = normalize(cross(orbit_normal_w, u_plane_w));
            final_escape_dir_world_calculated = normalize(
                k_orbit_plane_cart2D.x * u_plane_w +
                k_orbit_plane_cart2D.y * v_plane_w
            );
        }
        
        // 获取天空盒颜色
        final_color = texture(skyboxSampler, final_escape_dir_world_calculated).rgb;
    }
    
    // 合成最终颜色：天空盒背景 + 吸积盘辐射
    final_color += accumulated_disk_emission;
    
    FragColor = vec4(final_color, 1.0);
}

