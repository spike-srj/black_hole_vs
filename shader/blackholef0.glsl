#version 330 core // ����߰汾
out vec4 FragColor;

// --- Uniforms ---
uniform vec3 iResolution;         // �ӿڷֱ��� (x, y = width, height)
uniform float iTime;              // ʱ�� (��) - ���ʾ����δʹ�ã��������ӿ�
uniform mat4 invViewMatrix;       // ����ͼ���� (���������� V^-1)
uniform float SchwarzschildRadius; // �ڶ���ʷ�����뾶 (�����ӽ��ж�)
uniform float M; // // �ڶ����� (������ٶȹ�ʽ��Ҫ)
uniform samplerCube skyboxSampler;  // ��պ����������

// --- ���� ---
const int MAX_STEPS = 200;              // ���ֲ��� (����Ч�������ܵ���)
const float STEP_TIME_TOTAL = 0.01;   // ������������ (��Ҫ����!)
const float MAX_DIST_SQ = 10000.0;   // ���׷�پ���ƽ��

// --- ���ߺ��� ---
// �����Ҫ��ȷ�ӽ��ж��е� ray_sphere_intersect����Ҫ�ڴ˶�������

// --- ţ�ٽ����µĹ��߲��� (����ԭʼ���۵ļ��ٶ�) ---

// "���ٶ�" ���� (���� 1/r^4 ����������)
// ע�⣺��ȱ����Ҫ��ţ���� -M*p/r^3
// h2: �Ƕ���ƽ�� (L^2)
// p: ��ǰλ��
vec3 get_approx_accel(vec3 p, float h2) {
    float r2 = dot(p, p);
    if (r2 < 1e-6) return vec3(0.0); // �������
    float r5 = pow(r2, 2.5);
    // ʹ��ԭʼ�����е���ʽ (������Ҫ����ϵ��������Ի������Ч��)
    // ���ϵ�� 1.5 ������ M=0.5 (Rs=1.0) ���
    return -1.5 * h2 * p / r5; // ʹ�ø��ţ��ɳ������ſ���Ч��

    // --- ��������ţ���� (���ӽ��������Էǲ����) ---
    // float r3 = r2 * sqrt(r2);
    // vec3 newton_accel = -M * p / r3;
    // return newton_accel - 1.5 * h2 * p / r5; // ţ�� + ����
}

// RK4 �������ӿ�
// h2: �Ƕ���ƽ��
// fp: ���λ�õ��� (�ٶ� v)
// fv: ����ٶȵ��� (���ٶ� a)
// p:  ��ǰλ��
// v:  ��ǰ�ٶ�/����
void RK4f_approx(vec3 p, vec3 v, float h2, out vec3 fp, out vec3 fv) {
    fp = v; // λ�õ������ٶ�
    fv = get_approx_accel(p, h2); // ʹ�ý��Ƽ��ٶ�
}

// ʹ�� RK4 �������� (ţ�ٽ���)
// pos: ����/��� ����λ��
// v:   ����/��� �����ٶ�/����
// h2:  �Ƕ���ƽ��
void light_step_approx(inout vec3 pos, inout vec3 v, float h2) {
    float dt = STEP_TIME_TOTAL;
    // ��ѡ�����ݾ����������
    // dt *= max(1.0, length(pos) / SchwarzschildRadius);

    vec3 d_p, d_v;

    vec3 kp1, kp2, kp3, kp4; // λ�õ������м�ֵ
    vec3 kv1, kv2, kv3, kv4; // �ٶȵ������м�ֵ

    RK4f_approx(pos,                v,                h2, kp1, kv1);
    RK4f_approx(pos + 0.5 * dt * kp1, v + 0.5 * dt * kv1, h2, kp2, kv2);
    RK4f_approx(pos + 0.5 * dt * kp2, v + 0.5 * dt * kv2, h2, kp3, kv3);
    RK4f_approx(pos + 1.0 * dt * kp3, v + 1.0 * dt * kv3, h2, kp4, kv4);

    d_p = dt * (kp1 + 2.0 * kp2 + 2.0 * kp3 + kp4) / 6.0;
    d_v = dt * (kv1 + 2.0 * kv2 + 2.0 * kv3 + kv4) / 6.0;

    pos += d_p;
    v += d_v;

    // ��ţ�ٽ����£�ͨ�����ַ����һ���Ƚ�ֱ�ۣ�
    // �����ϸ���˵�ٶȴ�СҲ��䡣����ѡ���һ������
    // �������һ������Ҫ���� get_approx_accel ���ٶȴ�С�������������Ҫ����
    v = normalize(v);
}

// --- �¼��ӽ��ж� (�򵥰汾����������뾶) ---
void get_event_horizon_simple(inout float alpha_remain, vec3 pos) {
    // ֻ�жϵ�ǰ���Ƿ���ʷ�����뾶��
    if (dot(pos, pos) <= SchwarzschildRadius * SchwarzschildRadius) {
        alpha_remain = 0.0;
    }
    // ע�⣺û�м���߶δ�Խ�������ڲ����ϴ�ʱ�����ӽ��������⵽
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
    vec3 p = world_pos;
    vec3 v = world_v; // ʹ�� v ��Ϊ�ٶ�/�������
    float alpha = 1.0;

    // ����Ƕ���ƽ�� L^2 (h2)
    vec3 h_vec = cross(p, v);
    float h2 = dot(h_vec, h_vec);

    // --- 3. ���߲���ѭ�� (ţ�ٽ���) ---
    for (int j = 0; j < MAX_STEPS; j++) {
        vec3 old_p = p; // �����λ�ã����ӽ��жϿ��ܲ��ã�

        // ����ţ�ٽ��ƵĲ�������
        light_step_approx(p, v, h2); // ���� p �� v

        // �ж��Ƿ������¼��ӽ� (�򵥰汾)
        get_event_horizon_simple(alpha, p);

        if (alpha <= 0.0) {
            break; // ����ڶ�
        }

        // ����Ƿ����̫Զ
        if (dot(p, p) > MAX_DIST_SQ) {
            break; // ����
        }
    }

    // --- 4. ȷ��������ɫ ---
    if (alpha <= 0.0) {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0); // �ڶ�
    } else {
        // �������ݣ�ʹ�����շ��������պ�
        vec3 final_dir = normalize(v); // v �Ѿ��ǹ�һ���ķ���
        FragColor = texture(skyboxSampler, final_dir);
    }

     // ��ѡ��٤��У��
     // FragColor = pow(FragColor, vec4(1.0/2.2));
}