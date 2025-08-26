#version 330 core // 或更高版本
out vec4 FragColor;

// --- Uniforms ---
uniform vec3 iResolution;         // 视口分辨率 (x, y = width, height)
uniform float iTime;              // 时间 (秒) - 这个示例中未使用，但保留接口
uniform mat4 invViewMatrix;       // 逆视图矩阵 (相机世界矩阵 V^-1)
uniform float SchwarzschildRadius; // 黑洞的史瓦西半径 (用于视界判断)
uniform float M; // // 黑洞质量 (如果加速度公式需要)
uniform samplerCube skyboxSampler;  // 天空盒纹理采样器

// --- 常量 ---
const int MAX_STEPS = 200;              // 积分步数 (根据效果和性能调整)
const float STEP_TIME_TOTAL = 0.01;   // 基础步长因子 (需要调整!)
const float MAX_DIST_SQ = 10000.0;   // 最大追踪距离平方

// --- 工具函数 ---
// 如果需要精确视界判断中的 ray_sphere_intersect，需要在此定义或包含

// --- 牛顿近似下的光线步进 (基于原始讨论的加速度) ---

// "加速度" 函数 (基于 1/r^4 势能修正项)
// 注意：这缺少主要的牛顿项 -M*p/r^3
// h2: 角动量平方 (L^2)
// p: 当前位置
vec3 get_approx_accel(vec3 p, float h2) {
    float r2 = dot(p, p);
    if (r2 < 1e-6) return vec3(0.0); // 避免除零
    float r5 = pow(r2, 2.5);
    // 使用原始讨论中的形式 (可能需要调整系数或符号以获得期望效果)
    // 这个系数 1.5 可能与 M=0.5 (Rs=1.0) 相关
    return -1.5 * h2 * p / r5; // 使用负号，可尝试正号看看效果

    // --- 如果想加入牛顿项 (更接近物理，但仍非测地线) ---
    // float r3 = r2 * sqrt(r2);
    // vec3 newton_accel = -M * p / r3;
    // return newton_accel - 1.5 * h2 * p / r5; // 牛顿 + 修正
}

// RK4 积分器接口
// h2: 角动量平方
// fp: 输出位置导数 (速度 v)
// fv: 输出速度导数 (加速度 a)
// p:  当前位置
// v:  当前速度/方向
void RK4f_approx(vec3 p, vec3 v, float h2, out vec3 fp, out vec3 fv) {
    fp = v; // 位置导数是速度
    fv = get_approx_accel(p, h2); // 使用近似加速度
}

// 使用 RK4 步进光线 (牛顿近似)
// pos: 输入/输出 光线位置
// v:   输入/输出 光线速度/方向
// h2:  角动量平方
void light_step_approx(inout vec3 pos, inout vec3 v, float h2) {
    float dt = STEP_TIME_TOTAL;
    // 可选：根据距离调整步长
    // dt *= max(1.0, length(pos) / SchwarzschildRadius);

    vec3 d_p, d_v;

    vec3 kp1, kp2, kp3, kp4; // 位置导数的中间值
    vec3 kv1, kv2, kv3, kv4; // 速度导数的中间值

    RK4f_approx(pos,                v,                h2, kp1, kv1);
    RK4f_approx(pos + 0.5 * dt * kp1, v + 0.5 * dt * kv1, h2, kp2, kv2);
    RK4f_approx(pos + 0.5 * dt * kp2, v + 0.5 * dt * kv2, h2, kp3, kv3);
    RK4f_approx(pos + 1.0 * dt * kp3, v + 1.0 * dt * kv3, h2, kp4, kv4);

    d_p = dt * (kp1 + 2.0 * kp2 + 2.0 * kp3 + kp4) / 6.0;
    d_v = dt * (kv1 + 2.0 * kv2 + 2.0 * kv3 + kv4) / 6.0;

    pos += d_p;
    v += d_v;

    // 在牛顿近似下，通常保持方向归一化比较直观，
    // 尽管严格来说速度大小也会变。这里选择归一化方向。
    // 如果不归一化，需要调整 get_approx_accel 对速度大小的依赖（如果需要）。
    v = normalize(v);
}

// --- 事件视界判断 (简单版本，基于物理半径) ---
void get_event_horizon_simple(inout float alpha_remain, vec3 pos) {
    // 只判断当前点是否在史瓦西半径内
    if (dot(pos, pos) <= SchwarzschildRadius * SchwarzschildRadius) {
        alpha_remain = 0.0;
    }
    // 注意：没有检查线段穿越，可能在步长较大时穿过视界而不被检测到
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
    vec3 p = world_pos;
    vec3 v = world_v; // 使用 v 作为速度/方向变量
    float alpha = 1.0;

    // 计算角动量平方 L^2 (h2)
    vec3 h_vec = cross(p, v);
    float h2 = dot(h_vec, h_vec);

    // --- 3. 光线步进循环 (牛顿近似) ---
    for (int j = 0; j < MAX_STEPS; j++) {
        vec3 old_p = p; // 保存旧位置（简单视界判断可能不用）

        // 调用牛顿近似的步进函数
        light_step_approx(p, v, h2); // 更新 p 和 v

        // 判断是否落入事件视界 (简单版本)
        get_event_horizon_simple(alpha, p);

        if (alpha <= 0.0) {
            break; // 落入黑洞
        }

        // 检查是否离得太远
        if (dot(p, p) > MAX_DIST_SQ) {
            break; // 逃逸
        }
    }

    // --- 4. 确定最终颜色 ---
    if (alpha <= 0.0) {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0); // 黑洞
    } else {
        // 光线逃逸，使用最终方向采样天空盒
        vec3 final_dir = normalize(v); // v 已经是归一化的方向
        FragColor = texture(skyboxSampler, final_dir);
    }

     // 可选：伽马校正
     // FragColor = pow(FragColor, vec4(1.0/2.2));
}