#version 330 core // ����߰汾
out vec4 FragColor;

// --- Uniforms ---
uniform vec3 iResolution;         // �ӿڷֱ��� (x, y = width, height)
uniform float iTime;              // ʱ�� (��) - ���ʾ����δʹ�ã��������ӿ�
uniform mat4 invViewMatrix;       // ����ͼ���� (���������� V^-1)
uniform float SchwarzschildRadius; // �ڶ���ʷ�����뾶 (�����ӽ��ж�)
uniform float M; // // �ڶ����� (������ٶȹ�ʽ��Ҫ)
uniform vec3 blackholeCenterWorld;
uniform samplerCube skyboxSampler;  // ��պ����������

// --- ������������� (������ C++ ����Ϊ uniform ���룬����Ӳ����) ---
uniform vec3 sphereCenter;      // ����������������
uniform float sphereRadius;     // ����뾶
const vec3 sphereColor = vec3(1.0, 1.0, 0.0); // ��ɫ

// --- ���� ---
const int MAX_STEPS = 2000;              // ���ֲ��� (����Ч�������ܵ���)
const float STEP_TIME_TOTAL = 0.001;   // ������������ (��Ҫ����!)
const float MAX_DIST_SQ = 200.0;   // ���׷�پ���ƽ��

// --- ���ߺ��� ---
float intersectSphere(vec3 rayOrigin, vec3 rayDir, vec3 sCenter, float sRadius) {
    vec3 oc = rayOrigin - sCenter;
    float b = dot(oc, rayDir);
    float c = dot(oc, oc) - sRadius * sRadius;
    float h = b * b - c;
    if (h < 0.0) return -1.0; // ���ཻ
    // ������Ҫ������Ǹ����������
    float t = -b - sqrt(h);
    // ������������ڲ������ t �����Ǹ��ģ��������ӽ紩Խ��
    // ����ͨ�����ĵ��Ǵ��ⲿ�����ڲ��ĵ�һ����ײ������ t>=0 �Ƚ���Ҫ��
    // ���������ڲ���������Ȼ�����ϲ������뿪�ӽ磩����Ҫ���� t2 = -b + sqrt(h)��
    // �������Ӧ�ó�����ֻ���� t >= 0 ��������㹻�ˡ�
    return t;
}
// --- ţ�ٽ����µĹ��߲��� (����ԭʼ���۵ļ��ٶ�) ---

// "���ٶ�" ���� (���� 1/r^4 ����������)
// ע�⣺��ȱ����Ҫ��ţ���� -M*p/r^3
// h2: �Ƕ���ƽ�� (L^2)
// p_rel: ����ںڶ����ĵ�λ������
vec3 get_approx_accel(vec3 p_rel, float h2) {
    float r2 = dot(p_rel, p_rel);
    if (r2 < 1e-6) return vec3(0.0); // �������
    float r5 = pow(r2, 2.5);
    // ʹ��ԭʼ�����е���ʽ (������Ҫ����ϵ��������Ի������Ч��)
    // ���ϵ�� 1.5 ������ M=0.5 (Rs=1.0) ���
    //return -1.5 * h2 * p_rel / r5; // ʹ�ø��ţ��ɳ������ſ���Ч��

    // --- ��������ţ���� (���ӽ��������Էǲ����) ---
     float r3 = r2 * sqrt(r2);
     vec3 newton_accel = -M * p_rel / r3;
     return newton_accel - 1.5 * h2 * p_rel / r5; // ţ�� + ����
}

// RK4 �������ӿ�
// p_rel: ����ںڶ����ĵ�λ�� (��ǰ�����Ӳ�)
// v:   ��������ϵ�µ��ٶ�/���� (��ǰ�����Ӳ�)
// h2:  �Ƕ���ƽ�� (����)
// fp:  ���λ�õ��� (�����ٶ� v)
// fv:  ����ٶȵ��� (������ٶ� a)
void RK4f_approx(vec3 p_rel, vec3 v, float h2, out vec3 fp, out vec3 fv) {
    fp = v; // λ�õ������ٶ�
    fv = get_approx_accel(p_rel, h2); // ʹ�ý��Ƽ��ٶ�
}

// ʹ�� RK4 �������� (ţ�ٽ���)
// world_pos: ����/��� ��������ϵ�µĹ���λ��
// world_v:   ����/��� ��������ϵ�µĹ����ٶ�/����
// h2:        �Ƕ���ƽ��
void light_step_approx(inout vec3 world_pos, inout vec3 world_v, float h2) {
    float dt = STEP_TIME_TOTAL;
    // ��ѡ�����ݵ��ڶ����ĵľ����������
    float dist_to_bh = length(world_pos - blackholeCenterWorld);
    dt *= max(1.0, dist_to_bh / SchwarzschildRadius);

    vec3 d_p, d_v;
    vec3 kp1, kp2, kp3, kp4; // �����ٶȵ��м�ֵ
    vec3 kv1, kv2, kv3, kv4; // ������ٶȵ��м�ֵ

    // --- RK4 ��ÿ���Ӳ��趼��Ҫ���㵱ʱ�� p_rel ---
    vec3 p_rel_k1 = world_pos - blackholeCenterWorld;
    RK4f_approx(p_rel_k1, world_v, h2, kp1, kv1); // ʹ�� k1 ʱ�̵� p_rel �� v

    // ���� k2 �Ӳ�������λ�ú������ٶ�
    vec3 world_pos_k2 = world_pos + 0.5 * dt * kp1;
    vec3 world_v_k2 = world_v + 0.5 * dt * kv1;
    vec3 p_rel_k2 = world_pos_k2 - blackholeCenterWorld; // ���� k2 �Ӳ��� p_rel
    RK4f_approx(p_rel_k2, world_v_k2, h2, kp2, kv2); // ʹ�� k2 ʱ�̵� p_rel �� v

    // ���� k3 �Ӳ�������λ�ú������ٶ�
    vec3 world_pos_k3 = world_pos + 0.5 * dt * kp2;
    vec3 world_v_k3 = world_v + 0.5 * dt * kv2;
    vec3 p_rel_k3 = world_pos_k3 - blackholeCenterWorld; // ���� k3 �Ӳ��� p_rel
    RK4f_approx(p_rel_k3, world_v_k3, h2, kp3, kv3); // ʹ�� k3 ʱ�̵� p_rel �� v

    // ���� k4 �Ӳ�������λ�ú������ٶ�
    vec3 world_pos_k4 = world_pos + 1.0 * dt * kp3;
    vec3 world_v_k4 = world_v + 1.0 * dt * kv3;
    vec3 p_rel_k4 = world_pos_k4 - blackholeCenterWorld; // ���� k4 �Ӳ��� p_rel
    RK4f_approx(p_rel_k4, world_v_k4, h2, kp4, kv4); // ʹ�� k4 ʱ�̵� p_rel �� v

    // --- ��Ͻ���������������� ---
    d_p = dt * (kp1 + 2.0 * kp2 + 2.0 * kp3 + kp4) / 6.0; // ����λ������
    d_v = dt * (kv1 + 2.0 * kv2 + 2.0 * kv3 + kv4) / 6.0; // �����ٶ�����

    world_pos += d_p; // ��������λ��
    world_v += d_v; // ���������ٶ�
    world_v = normalize(world_v); // ���ַ����һ�� (ţ�ٽ����¿�ѡ)
}

// --- �¼��ӽ��ж� (�򵥰汾����������뾶) ---
// world_p: ��ǰ���ߵ�����λ��
void get_event_horizon_simple(inout float alpha_remain, vec3 world_p) {
    // ���㵽�ڶ����ĵľ���ƽ��
    vec3 vec_to_bh_center = world_p - blackholeCenterWorld;
    if (dot(vec_to_bh_center, vec_to_bh_center) <= SchwarzschildRadius * SchwarzschildRadius) {
        alpha_remain = 0.0;
    }
    // ע�⣺��Ȼû���߶δ�Խ���
}

// ����ȷ���¼��ӽ��ж� (�߶�-�����ཻ)
// world_p: ��ǰ���ߵ�����λ��
// old_world_p: ��һ�����ߵ�����λ��
void get_event_horizon_accurate(inout float alpha_remain, vec3 world_p, vec3 old_world_p) {

    // 1. ���ȣ����Ǽ�鵱ǰ���Ƿ��Ѿ����ڲ� (�����ų�)
    vec3 vec_to_bh_center = world_p - blackholeCenterWorld;
    if (dot(vec_to_bh_center, vec_to_bh_center) <= SchwarzschildRadius * SchwarzschildRadius) {
        alpha_remain = 0.0;
        return; // �Ѿ����ڲ�����������ж�
    }

    // 2. ������� old_world_p �� world_p ���߶��Ƿ񴩹��ӽ�����
    vec3 step_vec = world_p - old_world_p;     // ���㲽������
    float step_len_sq = dot(step_vec, step_vec); // ����ƽ��

    // ֻ�е�������Ϊ��ʱ�Ž��м��
    if (step_len_sq > 1e-8) { // ���ⲽ����С��Ϊ��
        float step_len = sqrt(step_len_sq);
        vec3 norm_step_dir = step_vec / step_len; // �������� (��һ��)

        // --- ʹ������-�����ཻ���� ---
        // �����������һ����λ�� old_world_p
        // ���߷����ǲ������� norm_step_dir
        // �����Ǻڶ����� blackholeCenterWorld
        // ��뾶�� SchwarzschildRadius
        float t = intersectSphere(old_world_p, norm_step_dir, blackholeCenterWorld, SchwarzschildRadius);

        // --- �жϽ����Ƿ����߶��� ---
        // t >= 0.0:      ��ʾ�����������н��� (������ȷ)
        // t <= step_len: ��ʾ����λ�ڴ� old_world_p ���������Ų�������
        //                ��������ǰ���� step_len �ķ�Χ�ڡ�
        //                �����㷢���� old_world_p �� world_p ֮�䡣
        if (t >= 0.0 && t <= step_len) {
            alpha_remain = 0.0; // ����߶����ӽ��ཻ������Ϊ����
        }
    }
    // �������������������㣬alpha_remain ���ֲ���
}



void main()
{
    // --- 1. �����ʼ���� (��������) ---
    vec2 uv = gl_FragCoord.xy / iResolution.xy;
    vec2 ndc = uv * 2.0 - 1.0;
    float aspectRatio = iResolution.x / iResolution.y;
    vec4 viewRayDir = vec4(ndc.x * aspectRatio, ndc.y, -1.0, 0.0); // ��ͼ�ռ䷽��
    vec3 world_v = normalize((invViewMatrix * viewRayDir).xyz);  // ��ʼ�����ٶ�/���� (v)
    vec3 world_pos = (invViewMatrix * vec4(0.0, 0.0, 0.0, 1.0)).xyz; // ��ʼ����λ�� (pos)

    // --- 2. ��ʼ������״̬ ---
    vec3 p_world = world_pos;
    vec3 v_world = world_v; // ʹ�� v ��Ϊ�ٶ�/�������
    float alpha = 1.0;

    // ����Ƕ���ƽ�� L^2 (h2)
    vec3 r_vec_for_L = p_world - blackholeCenterWorld; // ���ڼ��� L2
    vec3 h_vec = cross(r_vec_for_L, v_world);
    float L2 = dot(h_vec, h_vec);

    // --- 3. ���߲���ѭ�� (ţ�ٽ���) ---
    for (int j = 0; j < MAX_STEPS; j++) {
        vec3 old_p = p_world; // �����λ�ã����ӽ��жϿ��ܲ��ã�

        // ����ţ�ٽ��ƵĲ�������
        light_step_approx(p_world, v_world, L2); // ���� p �� v

//        // �ж��Ƿ������¼��ӽ� (�򵥰汾)
//        get_event_horizon_simple(alpha, p_world);
         // ���ø���ȷ�İ汾
        get_event_horizon_accurate(alpha, p_world, old_p);
        if (alpha <= 0.0) {
            break; // ����ڶ�
        }

        // ����Ƿ����̫Զ����һ����������йأ����߳�ʱ���������������ǻ�
        vec3 dist_vec_from_bh_center = p_world - blackholeCenterWorld;
        if (dot(dist_vec_from_bh_center, dist_vec_from_bh_center) > MAX_DIST_SQ) {
            break; // ����
        }
    }

    // --- 4. ȷ��������ɫ ---
    if (alpha <= 0.0) {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0); // �ڶ�
    } else {
        // �������ݣ�ʹ�����շ��������պ�
        vec3 final_dir = normalize(v_world); // v �Ѿ��ǹ�һ���ķ���
        FragColor = texture(skyboxSampler, final_dir);
    }

     // ��ѡ��٤��У��
     // FragColor = pow(FragColor, vec4(1.0/2.2));
}