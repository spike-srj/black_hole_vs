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

// --- 工具函数 ---
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
// --- 牛顿近似下的光线步进 (基于原始讨论的加速度) ---

// "加速度" 函数 (基于 1/r^4 势能修正项)
// 注意：这缺少主要的牛顿项 -M*p/r^3
// h2: 角动量平方 (L^2)
// p_rel: 相对于黑洞中心的位置向量
vec3 get_approx_accel(vec3 p_rel, float h2) {
    float r2 = dot(p_rel, p_rel);
    if (r2 < 1e-6) return vec3(0.0); // 避免除零
    float r5 = pow(r2, 2.5);
    // 使用原始讨论中的形式 (可能需要调整系数或符号以获得期望效果)
    // 这个系数 1.5 可能与 M=0.5 (Rs=1.0) 相关
    //return -1.5 * h2 * p_rel / r5; // 使用负号，可尝试正号看看效果

    // --- 如果想加入牛顿项 (更接近物理，但仍非测地线) ---
     float r3 = r2 * sqrt(r2);
     vec3 newton_accel = -M * p_rel / r3;
     return newton_accel - 1.5 * h2 * p_rel / r5; // 牛顿 + 修正
}

// RK4 积分器接口
// p_rel: 相对于黑洞中心的位置 (当前步或子步)
// v:   世界坐标系下的速度/方向 (当前步或子步)
// h2:  角动量平方 (不变)
// fp:  输出位置导数 (世界速度 v)
// fv:  输出速度导数 (世界加速度 a)
void RK4f_approx(vec3 p_rel, vec3 v, float h2, out vec3 fp, out vec3 fv) {
    fp = v; // 位置导数是速度
    fv = get_approx_accel(p_rel, h2); // 使用近似加速度
}

// 使用 RK4 步进光线 (牛顿近似)
// world_pos: 输入/输出 世界坐标系下的光线位置
// world_v:   输入/输出 世界坐标系下的光线速度/方向
// h2:        角动量平方
void light_step_approx(inout vec3 world_pos, inout vec3 world_v, float h2) {
    float dt = STEP_TIME_TOTAL;
    // 可选：根据到黑洞中心的距离调整步长
    float dist_to_bh = length(world_pos - blackholeCenterWorld);
    dt *= max(1.0, dist_to_bh / SchwarzschildRadius);

    vec3 d_p, d_v;
    vec3 kp1, kp2, kp3, kp4; // 世界速度的中间值
    vec3 kv1, kv2, kv3, kv4; // 世界加速度的中间值

    // --- RK4 的每个子步骤都需要计算当时的 p_rel ---
    vec3 p_rel_k1 = world_pos - blackholeCenterWorld;
    RK4f_approx(p_rel_k1, world_v, h2, kp1, kv1); // 使用 k1 时刻的 p_rel 和 v

    // 计算 k2 子步的世界位置和世界速度
    vec3 world_pos_k2 = world_pos + 0.5 * dt * kp1;
    vec3 world_v_k2 = world_v + 0.5 * dt * kv1;
    vec3 p_rel_k2 = world_pos_k2 - blackholeCenterWorld; // 计算 k2 子步的 p_rel
    RK4f_approx(p_rel_k2, world_v_k2, h2, kp2, kv2); // 使用 k2 时刻的 p_rel 和 v

    // 计算 k3 子步的世界位置和世界速度
    vec3 world_pos_k3 = world_pos + 0.5 * dt * kp2;
    vec3 world_v_k3 = world_v + 0.5 * dt * kv2;
    vec3 p_rel_k3 = world_pos_k3 - blackholeCenterWorld; // 计算 k3 子步的 p_rel
    RK4f_approx(p_rel_k3, world_v_k3, h2, kp3, kv3); // 使用 k3 时刻的 p_rel 和 v

    // 计算 k4 子步的世界位置和世界速度
    vec3 world_pos_k4 = world_pos + 1.0 * dt * kp3;
    vec3 world_v_k4 = world_v + 1.0 * dt * kv3;
    vec3 p_rel_k4 = world_pos_k4 - blackholeCenterWorld; // 计算 k4 子步的 p_rel
    RK4f_approx(p_rel_k4, world_v_k4, h2, kp4, kv4); // 使用 k4 时刻的 p_rel 和 v

    // --- 组合结果，更新世界坐标 ---
    d_p = dt * (kp1 + 2.0 * kp2 + 2.0 * kp3 + kp4) / 6.0; // 世界位移增量
    d_v = dt * (kv1 + 2.0 * kv2 + 2.0 * kv3 + kv4) / 6.0; // 世界速度增量

    world_pos += d_p; // 更新世界位置
    world_v += d_v; // 更新世界速度
    world_v = normalize(world_v); // 保持方向归一化 (牛顿近似下可选)
}

// --- 事件视界判断 (简单版本，基于物理半径) ---
// world_p: 当前光线的世界位置
void get_event_horizon_simple(inout float alpha_remain, vec3 world_p) {
    // 计算到黑洞中心的距离平方
    vec3 vec_to_bh_center = world_p - blackholeCenterWorld;
    if (dot(vec_to_bh_center, vec_to_bh_center) <= SchwarzschildRadius * SchwarzschildRadius) {
        alpha_remain = 0.0;
    }
    // 注意：仍然没有线段穿越检测
}

// 更精确的事件视界判断 (线段-球体相交)
// world_p: 当前光线的世界位置
// old_world_p: 上一步光线的世界位置
void get_event_horizon_accurate(inout float alpha_remain, vec3 world_p, vec3 old_world_p) {

    // 1. 首先，还是检查当前点是否已经在内部 (快速排除)
    vec3 vec_to_bh_center = world_p - blackholeCenterWorld;
    if (dot(vec_to_bh_center, vec_to_bh_center) <= SchwarzschildRadius * SchwarzschildRadius) {
        alpha_remain = 0.0;
        return; // 已经在内部，无需后续判断
    }

    // 2. 检查连接 old_world_p 和 world_p 的线段是否穿过视界球体
    vec3 step_vec = world_p - old_world_p;     // 计算步进向量
    float step_len_sq = dot(step_vec, step_vec); // 步长平方

    // 只有当步长不为零时才进行检测
    if (step_len_sq > 1e-8) { // 避免步长过小或为零
        float step_len = sqrt(step_len_sq);
        vec3 norm_step_dir = step_vec / step_len; // 步进方向 (归一化)

        // --- 使用射线-球体相交函数 ---
        // 射线起点是上一步的位置 old_world_p
        // 射线方向是步进方向 norm_step_dir
        // 球心是黑洞中心 blackholeCenterWorld
        // 球半径是 SchwarzschildRadius
        float t = intersectSphere(old_world_p, norm_step_dir, blackholeCenterWorld, SchwarzschildRadius);

        // --- 判断交点是否在线段内 ---
        // t >= 0.0:      表示射线与球体有交点 (方向正确)
        // t <= step_len: 表示交点位于从 old_world_p 出发，沿着步进方向，
        //                不超过当前步长 step_len 的范围内。
        //                即交点发生在 old_world_p 和 world_p 之间。
        if (t >= 0.0 && t <= step_len) {
            alpha_remain = 0.0; // 如果线段与视界相交，则标记为吸收
        }
    }
    // 如果上面的条件都不满足，alpha_remain 保持不变
}



void main()
{
    // --- 1. 计算初始射线 (世界坐标) ---
    vec2 uv = gl_FragCoord.xy / iResolution.xy;
    vec2 ndc = uv * 2.0 - 1.0;
    float aspectRatio = iResolution.x / iResolution.y;
    vec4 viewRayDir = vec4(ndc.x * aspectRatio, ndc.y, -1.0, 0.0); // 视图空间方向
    vec3 world_v = normalize((invViewMatrix * viewRayDir).xyz);  // 初始世界速度/方向 (v)
    vec3 world_pos = (invViewMatrix * vec4(0.0, 0.0, 0.0, 1.0)).xyz; // 初始世界位置 (pos)

    // --- 2. 初始化积分状态 ---
    vec3 p_world = world_pos;
    vec3 v_world = world_v; // 使用 v 作为速度/方向变量
    float alpha = 1.0;

    // 计算角动量平方 L^2 (h2)
    vec3 r_vec_for_L = p_world - blackholeCenterWorld; // 用于计算 L2
    vec3 h_vec = cross(r_vec_for_L, v_world);
    float L2 = dot(h_vec, h_vec);

    // --- 3. 光线步进循环 (牛顿近似) ---
    for (int j = 0; j < MAX_STEPS; j++) {
        vec3 old_p = p_world; // 保存旧位置（简单视界判断可能不用）

        // 调用牛顿近似的步进函数
        light_step_approx(p_world, v_world, L2); // 更新 p 和 v

//        // 判断是否落入事件视界 (简单版本)
//        get_event_horizon_simple(alpha, p_world);
         // 调用更精确的版本
        get_event_horizon_accurate(alpha, p_world, old_p);
        if (alpha <= 0.0) {
            break; // 落入黑洞
        }

        // 检查是否离得太远，这一步与光子球有关：光线长时间在引力场附近徘徊
        vec3 dist_vec_from_bh_center = p_world - blackholeCenterWorld;
        if (dot(dist_vec_from_bh_center, dist_vec_from_bh_center) > MAX_DIST_SQ) {
            break; // 逃逸
        }
    }

    // --- 4. 确定最终颜色 ---
    if (alpha <= 0.0) {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0); // 黑洞
    } else {
        // 光线逃逸，使用最终方向采样天空盒
        vec3 final_dir = normalize(v_world); // v 已经是归一化的方向
        FragColor = texture(skyboxSampler, final_dir);
    }

     // 可选：伽马校正
     // FragColor = pow(FragColor, vec4(1.0/2.2));
}