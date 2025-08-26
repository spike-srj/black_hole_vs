# 黑洞光线步进（测地线追踪）算法说明

> 本文面向实时/离线图形与物理模拟开发者，系统说明黑洞时空中光线（零测地线）的步进与渲染算法。内容覆盖 Schwarzschild 与 Kerr（骨架级），重点给出坐标变换、常数构造、步长与符号逻辑（robust_step、wrap_angle）、终止与命中、数值稳定与性能优化策略，并与本仓库当前实现做对照与可演进路径。

---

## 1. 目标与适用范围

- 目标：从相机像素出发，反向追踪光子测地线，判断是否捕获于事件视界、与发光体（吸积盘/体发）交互或逃向无穷远；对逃逸光线计算引力透镜偏折与频移后合成颜色。
- 适用：
  - Schwarzschild（非自旋，球对称）：可将轨迹约化到包含相机与黑洞中心的一条轨道面（2D）内，代价低、实现简洁。
  - Kerr（带自旋）：需在 3D（r,θ,φ）内积分零测地线，常用米诺时间分离 ODE（具 Carter 常数），实现复杂度高但精确。

---

## 2. 符号与单位约定

- 几何单位：G = c = M = 1（可令质量 M 归一化，易于无量纲化与数值稳定）。
- 记号：x^μ = (t, r, θ, φ)。采用 Boyer–Lindquist（BL）坐标描述 Kerr/Schwarzschild；近视界为避免退化可使用（ingoing）Kerr–Schild。

---

## 3. 坐标与度规

### 3.1 Schwarzschild（a = 0）
- 度规（球对称）：ds² = −(1 − 2/r) dt² + (1 − 2/r)⁻¹ dr² + r²(dθ² + sin²θ dφ²)。
- 事件视界：r₊ = 2（在本文单位下）。
- 由于球对称，光子轨迹必定处于某一固定平面内（“轨道面”），可将 3D 问题约化到 2D 极坐标 (r, φ)。

### 3.2 Kerr（|a| < 1）
- 常用量：Σ = r² + a² cos²θ；Δ = r² − 2r + a²；A = (r² + a²)² − a² Δ sin²θ。
- BL 度规分量：
  - g_tt = −(1 − 2r/Σ)，g_tφ = −2 a r sin²θ / Σ，g_rr = Σ/Δ，g_θθ = Σ，g_φφ = A sin²θ/Σ。
- 视界：r₊ = 1 + √(1 − a²)；拖拽角速度 ω = −g_tφ/g_φφ = 2 a r / A；lapse α = √(Σ Δ / A)。

---

## 4. 观察者、屏幕与局域正交标架（Tetrad）

### 4.1 ZAMO 标架（推荐）
- 观察者四速度：u^μ = α⁻¹ (1, 0, 0, ω)。
- 空间正交基：e_(r) = √(Δ/Σ) ∂_r，e_(θ) = 1/√Σ ∂_θ，e_(φ) = √(Σ/(A sin²θ)) ∂_φ。
- 时间基：e_(t) = u^μ。
- 相机姿态：以 {e_(r), e_(θ), e_(φ)} 为初始三轴，在局域欧式 3×3 空间内施加 yaw/pitch/roll 得到 {x_cam, y_cam, z_cam}，通常 z_cam 指向 −e_(r)。

### 4.2 本仓库实现现状（与上法的对照）
- 使用视图矩阵的逆 `invViewMatrix` 将屏幕射线从视空间变换到世界空间：
  - NDC → view：`(ndc.x, ndc.y, -1, 0)`；view → world：`dir = normalize(invView * viewRay)`。
  - 相机位置：`pos = (invView * (0,0,0,1)).xyz`。
- 在 Schwarzschild 下，以欧式 3D 量近似保守量与轨道面：
  - E 取 1；L ≈ |(pos−BH) × dir|；轨道面法向 `n = normalize(cross(r, dir))`。
- 更精确方案：构造 tetrad 于相机处，将局域光子四动量 p^(a) 变到坐标基 p^μ，然后据此求 E = −p_t、Lz = p_φ（Schwarzschild 时 L ≈ Lz）。

---

## 5. 像素 → 初始条件

1) 屏幕像素 → 射线方向：
- `ndc = (fragCoord / iResolution) * 2 − 1`，校正宽高比；
- `viewRay = (ndc.x, ndc.y, -1, 0)`；`ray_dir_world = normalize(invView * viewRay)`；
- `ray_pos_world = (invView * (0,0,0,1)).xyz`；`r0_vec = ray_pos_world − BH_center`，r₀ = |r0_vec|。

2) 保守量（Schwarzschild）
- 近似：E = 1；L = |r0_vec × ray_dir_world|（适用于远场静止观察者）。
- 精确：若有 tetrad，令局域 p^(t)=1、p^(i)=n_cam^i（|n|=1，零测地线），变到坐标后 E = −p_t、L = p_φ。

3) 轨道面正交基（世界坐标内）
- u_plane = normalize(r0_vec)；v_plane = normalize(n × u_plane)；若退化（L≈0），用辅助向量构造任意正交面。

---

## 6. 测地线方程

### 6.1 Schwarzschild 的 2D 约化
- 有效势：V_eff(r) = (L²/r²) (1 − 2/r)。
- 一阶 ODE（仿射参数 λ）：
  - dφ/dλ = L / r²；
  - dr/dλ = s_r √(E² − V_eff(r))，s_r ∈ {±1} 由初始径向动量符号确定。
- 转向点：E² − V_eff(r) = 0（近似光子球 r≈3/2·Rs）。
- 临界冲击参数（远处阴影半径）：b_c = L/E = (3√3/2)·Rs。

### 6.2 Kerr（骨架，米诺时间 λ̃）
- Carter 常数：Q = p_θ² + cos²θ (a² E² − Lz²/sin²θ)。
- 势：R(r) = [(r²+a²)E − a Lz]² − Δ[Q + (Lz − aE)²]；Θ(θ) = Q + a²(E²−Lz²/sin²θ)cos²θ。
- 一阶 ODE：
  - dr/dλ̃ = s_r √R(r)；dθ/dλ̃ = s_θ √Θ(θ)；
  - dφ/dλ̃ = a((r²+a²)E − aLz)/Δ + Lz csc²θ − aE；
  - dt/dλ̃ = ((r²+a²)((r²+a²)E − aLz))/Δ + a(Lz − aE sin²θ)。
- s_r、s_θ 在各自势为零时翻转号，步长需约束以避免越界。

---

## 7. 步进策略（核心实践）

### 7.1 步长控制（自适应）
- 以 Schwarzschild 2D 为例：
  - 由当前导数计算候选步长，限制每步最大径向变化 `|Δr| ≤ f_r·max(r, Rs)` 与角变化 `|Δφ| ≤ f_φ`；
  - 近转向点预压缩：若 dr² = E² − V_eff(r) < τ_turn，则将 dλ *= κ（如 0.5）。
- 远场放宽：r > r_far（如 8–10·Rs）时增大 dλ_max、MAX_DPHI，降低步数。

### 7.2 robust_step（回退细化）的意义与用法
- 目的：避免“先越界再回退”的不稳定，保证每次推进落在物理可达域内并远离奇点/视界退化。
- 实现：对一次 RK 试步进行校验（dr²≥0，非 NaN/Inf，必要时远离视界），不满足则 dλ ← dλ/2 重试，至多 M 次。
- 建议：
  - 将“近视界”从无条件拒收改为“若向外才拒收；向内则允许并在步内做根查找（见 7.4）”，避免出现“永远逼近不捕获”。
  - 结合 7.1 的预压缩，降低回退触发频率，提高效率。

### 7.3 角度规范 wrap_angle 的意义
- 定义：将 φ 约束回 [−π, π]（或 [0, 2π)），便于三角函数稳定与小角差比较。
- 性能：`mod`/分支在 GPU 上较贵，不宜每步调用。
- 建议：仅在需要 `sin/cos(φ)` 时（例如末端合成方向）调用一次，或每 N 步（如 64）调用一次即可。

### 7.4 符号逻辑（s_r、s_θ）与翻转滞回
- 判据：若本步 `r_new > r_old` 与期望（s_r>0 表示外向）不符，或 `dr²(r_new)≈0`，则翻转 s_r。
- 滞回：记录上次翻转半径 r_flip，只有 |r − r_flip| > ε·max(r,Rs) 时才允许再次翻转，避免数值噪声导致“乒乓”。
- 步内根查找：若本步跨越事件（如 r 由 >Rs 跨到 ≤Rs），做二分/弦截定位交点，获得精确命中时间并稳定分类。

---

## 8. 终止与命中判定

- 捕获：r ≤ r₊ + ε（Schwarzschild：r₊=Rs），向内运动（s_r<0）时判定捕获。
- 逃逸：r > R_max（远场边界，典型 50·Rs–100·Rs）。
- 盘面命中：薄盘位于 θ=π/2（或自定义曲面/体），检测穿越符号变化并做步内根查找，验证 r ∈ [r_in, r_out]。 

---

## 9. 频移与辐射（简述）

- 频移因子 g = (p_μ u_obs^μ)/(p_μ u_em^μ)；不变量 I_ν/ν³ ⇒ I_obs = g³ I_em（ν_obs = g ν_em）。
- 体发/吸收（不变量形式）：令 Ĩ = I_ν/ν³，ĵ = j_ν/ν²，α̂ = α_ν·ν，有 dĨ/dλ = ĵ − α̂ Ĩ，步内用指数解或二阶法。
- 薄盘：在盘共动系各向同性辐射，按 T(r) 与谱模型取 I_em，再乘 g³ 与投影余弦因子。

---

## 10. 伪代码（Schwarzschild 2D & Kerr 骨架）

### 10.1 Schwarzschild（本仓库主线）
```pseudo
input: fragCoord, iResolution, invView, BH_center, Rs, params
ray_dir = normalize((invView * (ndc.x, ndc.y, -1, 0)).xyz)
ray_pos = (invView * (0,0,0,1)).xyz
r_vec   = ray_pos - BH_center
r       = length(r_vec)
E=1; L = length(cross(r_vec, ray_dir))

// 轨道面基
n = normalize(cross(r_vec, ray_dir))
u = normalize(r_vec)
v = normalize(cross(n, u))
phi = 0; s_r = sign(dot(ray_dir, r_vec))

for step in [0..MAX_STEPS):
  if r <= Rs and s_r<0: return BLACK
  if r > R_max: break
  // 导数与步长
  dphi = L / (r*r)
  dr2  = E*E - (L*L/(r*r))*(1 - Rs/r)
  drdl = s_r * sqrt(max(dr2,0))
  dλ   = choose_step(|drdl|, |dphi|, r)
  // 预压缩 + 回退
  if dr2 < τ_turn: dλ *= κ
  (r_try, phi_try) = RK4_step(r, phi, s_r, dλ)
  if invalid(r_try) or E²−V(r_try)<0: dλ/=2; retry (≤MAX_REFINES)
  // 翻转与滞回
  if (r_try<r) == (s_r>0) or near_turning(r_try): s_r = -s_r (with hysteresis)
  // 提交
  r = r_try; phi = phi_try (optionally wrap every N steps)
endfor

// 逃逸：求终态世界方向
vr = s_r*sqrt(max(E²−V(r),0))
vθ = r*(L/(r*r))
r_hat = cos(phi)*u + sin(phi)*v
θ_hat = -sin(phi)*u + cos(phi)*v
final_dir = normalize(vr*r_hat + vθ*θ_hat) (fallbacks if degenerate)
return sample_skybox(final_dir)
```

### 10.2 Kerr（骨架：米诺时间 + 常数）
```pseudo
input: pixel, tetrad_at_camera, (a, Rs)
// 局域 → 坐标四动量
k^(a) = (1, n_cam)
p^μ = e^μ_(a) k^(a)
E = -p_t; Lz = p_φ; Q = p_θ^2 + cos²θ (a²E² - Lz²/sin²θ)

r, θ, φ, t = r0, θ0, φ0, t0
s_r = sign(p_r); s_θ = sign(p_θ)
while steps:
  if r<=r₊: capture
  if r>=R_max: escape
  // 计算 R(r), Θ(θ) 与导数，选择 dλ̃
  dλ̃ = choose_step_mino(R, Θ, r, θ)
  (r_try, θ_try, φ_try, t_try) = RK / DP step
  // turning 处理：若 R<0 或 Θ<0 则减步并翻转 s_r/s_θ（带滞回）
  commit
end
// 逃逸：投影到远处方向用于背景/辐射取样
```

---

## 11. 数值稳定与性能优化

- 步长：限制 `|Δr|` 与 `|Δφ|`；近转向压缩；远场放宽；必要时切换 RK4 → RK2/Heun。
- robust_step：仅拒绝 NaN/Inf 与 `dr²<0`；向内可允许跨视界并做步内根查找；降低 `MAX_REFINES`（3–4）。
- wrap_angle：从每步调用改为“末端一次”或“每 N 步一次”。
- 远场弱场近似：b 大于阈值时用闭式偏折角 `Δφ ≈ 2Rs/b + (15π/16)(Rs/b)²` 直接旋转，跳过积分。
- LUT：预计算 `Δφ(b)` 1D 纹理，在 b_c 附近对数加密采样，片元仅查纹理；可将主循环移除。
- 线程发散：统一分支（如固定检查频率）、控制回退次数；必要时改为计算着色器做批量控制。

---

## 12. 验证与调试

- 阴影半径：远处静止观察者下应为 `b_c = (3√3/2)·Rs`。
- 不变量监测：Schwarzschild 2D 保持 `E² − V_eff(r) ≥ 0`（除阈值内）；Kerr 监测 (E, Lz, Q) 漂移。
- 事件逼近：跨过捕获/盘面/边界时做步内根查找，避免“越界后回退”带来的分类不稳。
- 渲染可视：近光子球区域闪烁多由回退/翻转抖动导致，可通过滞回与预压缩缓解。

---

## 13. 常见陷阱

- 每步 wrap 角度：高昂且无必要，容易引入发散。
- 视界拒收：始终拒收会造成“逼近不捕获”；应结合方向与步内根查找。
- 平面基退化：L≈0 时 u、v 共线需降级处理；末端方向近零长度需兜底到主导分量/初始方向。
- 手性/坐标系：相机右手系与轨道面基向量顺序错误会翻转自旋/盘面朝向。

---

## 14. 与本仓库实现的对照

- `get_geodesic_derivatives(r,E,L)`：实现了 Schwarzschild 2D 的 `dr/dλ` 与 `dφ/dλ`（含有效势）。
- `advance_rk4`：标准 RK4 单步。
- `robust_step`：回退细化（建议按 7.2 调整近视界处理与回退上限）。
- `compute_adaptive_step_size`：按 `Δr`/`Δφ` 限制步长（可加入“近转向预压缩”）。
- `wrap_angle`：建议移出主循环或降频调用。
- `getFinalDirection`：将末端极坐标导数合成为世界方向，含退化兜底。

---

## 15. 升级路线（建议优先级）

1) 低风险快赢：
- 移除循环内每步 `wrap_angle`；
- 降低 `MAX_REFINES`，加入“近转向预压缩”；
- 远场放宽步长与角增量阈值；
- 弱场快速路径（b 大阈值下闭式偏折）。

2) 架构提升：
- LUT 化 `Δφ(b)`，片元直接查表；
- 计算着色器化，统一步进预算与回退策略；
- Schwarzschild 精确 tetrad→(E,L)；Kerr 骨架（E,Lz,Q + 米诺时间）。

---

> 参考名录（概念导向）：Carter（分离与常数），Chandrasekhar（黑洞数学理论），Bardeen/Press/Teukolsky（Kerr 性质），以及大量图形学实现（GPU ray tracing in curved spacetime）。如需，我可补充更具体的推导与数值实现细节笔记。