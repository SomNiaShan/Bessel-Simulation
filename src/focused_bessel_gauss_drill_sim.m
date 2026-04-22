% focused_bessel_gauss_drill_sim.m
% 这个脚本用于生成并验证一个聚焦的有限长度 Bessel-Gauss 型 SLM hologram。
% 当前版本只做空气中的线性传播仿真，不模拟 KBr、烧蚀、碎屑、等离子体或非线性效应。

clear                                   % 清空工作区变量，避免旧变量影响本次仿真。
tic                                     % 开始计时，用于查看整段脚本运行耗时。

%% ==================== 用户参数区：通常只需要修改这里 ====================
% 这一段集中放置所有常用输入参数。
% 如果你要改目标孔径、目标长度、采样精度、倍率、波长、输出位置，优先在这里改。

cfg = struct();                          % 用结构体保存全部配置参数，便于传给后续函数。

% ---------- SLM / 光学系统参数 ----------
cfg.N = 1081;                            % SLM/仿真网格点数，当前为 1081 x 1081。
cfg.slm_size_mm = 8.64;                  % SLM 有效口径尺寸，单位 mm，对应约 8 um/pixel。
cfg.lambda_mm = 1.03e-3;                % 激光波长，单位 mm；1.03e-3 mm = 1030 nm。
cfg.medium_n = 1;                        % 传播介质折射率；当前只做空气仿真，所以 n = 1。
cfg.M = 20 / 200;                        % SLM 到样品侧的等效缩小倍率，当前来自 f2/f1 = 20/200。

% ---------- 目标光束参数 ----------
cfg.target_core_diameter_um = 10;        % 目标中心亮斑直径，单位 um，按强度 FWHM 定义。
cfg.target_length_mm = 0.4;                % 目标轴向高强度长度，单位 mm，也是按 FWHM 近似控制。
cfg.core_metric = "fwhm";                % 横向焦斑尺寸的定义，目前只支持强度 FWHM。
cfg.j0_intensity_half_arg = 1.126;       % J0 型 Bessel 中心瓣强度降到一半时的无量纲半径。

% ---------- 聚焦 Bessel-Gauss 调节参数 ----------
cfg.axial_waist_scale = 1.4;             % 轴向长度校正系数，用来让实际轴向 FWHM 接近 1 mm。
cfg.focus_distance_sample_mm = 30;       % 样品侧弱聚焦二次相位的等效焦距，单位 mm。

% ---------- 局部传播仿真参数 ----------
cfg.z_start_mm = 0.05;                   % 局部传播扫描起点，单位 mm；避开 z=0 的初始面。
cfg.z_span_mm = 2.0;                     % 局部传播扫描范围，单位 mm。
cfg.dz_um = 10;                          % z 方向采样间隔，单位 um。
cfg.metric_z_min_mm = 0.10;              % 寻找峰值时忽略过近的 z 平面，避免初始面伪峰。
cfg.roi_radius_um = 80;                  % 输出诊断图时截取中心区域半径，单位 um。

% ---------- 输出路径参数 ----------
script_dir = fileparts(mfilename('fullpath')); % 获取当前脚本所在文件夹，也就是 src 文件夹。
repo_root = fileparts(script_dir);       % 获取项目根目录，也就是 drill-beam-matlab 文件夹。
cfg.output_root_dir = fullfile(repo_root, 'outputs', 'focused_bessel_gauss'); % 新仿真的专用输出根目录。

%% ==================== 主程序：一般不需要修改下面内容 ====================
metrics = run_focused_bessel_gauss_sim(cfg); % 使用这些参数运行完整仿真，并返回关键结果。

fprintf('Measured transverse FWHM: %.3f um\n', metrics.transverse_fwhm_um); % 在命令行输出横向焦斑 FWHM。
fprintf('Measured axial FWHM: %.3f mm\n', metrics.axial_fwhm_mm);           % 在命令行输出轴向高强度长度 FWHM。
fprintf('Peak plane: %.3f mm after local propagation start\n', metrics.peak_z_mm); % 输出峰值平面相对局部传播起点的位置。
fprintf('Run folder: %s\n', metrics.run_dir);                              % 输出本次结果所在文件夹。
fprintf('Readme written: %s\n', metrics.readme_path);                      % 输出中文说明文件路径。
fprintf('SLM phase written: %s\n', metrics.slm_path);                      % 输出 SLM 相位图路径。
fprintf('Diagnostics written: %s\n', metrics.diagnostics_path);            % 输出诊断图路径。
fprintf('Metrics written: %s\n', metrics.metrics_path);                    % 输出文字版指标摘要路径。

toc                                     % 结束计时，并在命令行显示总耗时。

function metrics = run_focused_bessel_gauss_sim(cfg)
% run_focused_bessel_gauss_sim
% 这是主仿真函数，完成从目标光束参数到 SLM 相位图、传播仿真、指标计算、文件输出的全过程。

if ~exist(cfg.output_root_dir, 'dir')          % 如果输出根目录还不存在。
    mkdir(cfg.output_root_dir);                % 创建 outputs/focused_bessel_gauss 文件夹。
end                                           % 输出目录检查结束。

lambda_mm = cfg.lambda_mm;                    % 从配置中取出波长，单位 mm。
k = 2*pi*cfg.medium_n/lambda_mm;              % 计算介质中的波数 k = 2*pi*n/lambda，单位 rad/mm。
target_core_diameter_mm = cfg.target_core_diameter_um * 1e-3; % 把目标直径从 um 转为 mm。
target_core_radius_mm = target_core_diameter_mm / 2;          % 目标中心区域半径，后面用于计算功率占比。

if strcmpi(cfg.core_metric, "fwhm")            % 如果用户选择用强度 FWHM 定义中心瓣直径。
    kr_target = 2 * cfg.j0_intensity_half_arg / target_core_diameter_mm; % 由 FWHM 反推横向波矢 kr。
else                                          % 如果将来填了其它定义，比如 first_zero。
    error('Unsupported core_metric "%s". First version supports "fwhm".', cfg.core_metric); % 当前先报错。
end                                           % 横向尺寸定义判断结束。

if kr_target >= k                             % 检查横向波矢是否超过总波矢。
    error('Target core is too small for lambda %.4g mm and n %.4g.', lambda_mm, cfg.medium_n); % 超过则物理上不可实现。
end                                           % 可实现性检查结束。

beta_sample = asin(kr_target / k);            % 样品侧 Bessel 锥角，满足 kr = k*sin(beta)。
beta_slm = atan(cfg.M * tan(beta_sample));    % 按缩小倍率把样品侧锥角映射回 SLM 侧锥角。

% 用高斯入射包络限制 Bessel 区域长度；scale 是经验校正，让实际轴向 FWHM 更接近目标。
sample_waist_mm = cfg.axial_waist_scale * cfg.target_length_mm * tan(beta_sample) / ...
    (2 * sqrt(log(2) / 2));                   % 样品侧等效高斯半径，单位 mm。
slm_waist_mm = sample_waist_mm / cfg.M;       % 把样品侧高斯半径按倍率映射回 SLM 侧。

slm_axis_mm = linspace(-cfg.slm_size_mm/2, cfg.slm_size_mm/2, cfg.N); % SLM 面 x/y 坐标轴，单位 mm。
[x_slm, y_slm] = meshgrid(slm_axis_mm, slm_axis_mm);                  % 生成 SLM 面二维坐标网格。
r_slm = hypot(x_slm, y_slm);                 % SLM 面径向坐标 r = sqrt(x^2 + y^2)，单位 mm。

sample_axis_mm = cfg.M * slm_axis_mm;        % 样品侧坐标轴，由 SLM 坐标轴乘以等效缩小倍率得到。
[x_sample, y_sample] = meshgrid(sample_axis_mm, sample_axis_mm);      % 生成样品侧二维坐标网格。
r_sample = hypot(x_sample, y_sample);        % 样品侧径向坐标，单位 mm。
sample_size_mm = cfg.M * cfg.slm_size_mm;    % 样品侧计算窗口总尺寸，单位 mm。
dx_sample_um = (sample_axis_mm(2) - sample_axis_mm(1)) * 1e3; % 样品侧横向采样间隔，单位 um/pixel。

phase_axicon_slm = -k * tan(beta_slm) .* r_slm; % SLM 面的锥透镜相位，用于产生 Bessel 锥角。
phase_lens_slm = zeros(size(r_slm), 'like', r_slm);     % 预分配 SLM 面弱聚焦二次相位，默认全 0。
phase_lens_sample = zeros(size(r_sample), 'like', r_sample); % 预分配样品侧弱聚焦二次相位，默认全 0。

if isfinite(cfg.focus_distance_sample_mm)     % 如果配置里给了有限焦距。
    focus_distance_slm_mm = cfg.focus_distance_sample_mm / cfg.M^2; % 按倍率平方把焦距映射回 SLM 侧。
    phase_lens_slm = -k .* r_slm.^2 ./ (2 * focus_distance_slm_mm);  % SLM 面二次透镜相位。
    phase_lens_sample = -k .* r_sample.^2 ./ (2 * cfg.focus_distance_sample_mm); % 样品侧等效二次透镜相位。
else                                          % 如果焦距是 Inf。
    focus_distance_slm_mm = Inf;              % 记录 SLM 侧焦距也是 Inf，即不额外聚焦。
end                                           % 弱聚焦相位计算结束。

phase_slm = phase_axicon_slm + phase_lens_slm; % 最终写给 SLM 的相位 = 锥相位 + 弱聚焦相位。
slm_phase_8bit = phase_to_uint8(phase_slm);    % 把连续相位包裹并映射成 0-255 的 8-bit 灰度图。

phase_axicon_sample = -k * tan(beta_sample) .* r_sample; % 样品侧等效锥透镜相位，用于局部传播仿真。
input_amplitude_sample = exp(-(r_sample ./ sample_waist_mm).^2); % 样品侧等效高斯入射振幅包络。
E_sample0 = input_amplitude_sample .* exp(1i * (phase_axicon_sample + phase_lens_sample)); % 初始复电场。

z_values_mm = cfg.z_start_mm:(cfg.dz_um * 1e-3):(cfg.z_start_mm + cfg.z_span_mm); % z 扫描位置数组，单位 mm。
num_z = numel(z_values_mm);                   % z 平面数量。
center_idx = floor(cfg.N/2) + 1;              % 中心像素索引，N 为奇数时正好对应坐标 0。

freq_axis = ((0:cfg.N-1) - floor(cfg.N/2)) ./ sample_size_mm; % 空间频率坐标轴，单位 cycles/mm。
[fx, fy] = meshgrid(freq_axis, freq_axis);     % 生成二维空间频率网格。
kx = 2*pi*fx;                                  % x 方向波矢分量，单位 rad/mm。
ky = 2*pi*fy;                                  % y 方向波矢分量，单位 rad/mm。
kz = sqrt(complex(k^2 - kx.^2 - ky.^2, 0));    % z 方向波矢；complex 防止倏逝波开方出 NaN。
F0 = fftshift(fft2(E_sample0));                % 初始场的角谱，用于后续角谱传播。

xz_slice = zeros(cfg.N, num_z, 'single');      % 存储中心 XZ 剖面，避免保存完整 3D 体数据。
on_axis = zeros(1, num_z);                     % 存储轴上强度 I(x=0,y=0,z)。
peak_xy = [];                                  % 用于保存峰值平面的中心 ROI 强度图。
peak_center_row = [];                          % 用于保存峰值平面中心横截线，计算横向 FWHM。
peak_z_mm = NaN;                               % 峰值平面的 z 位置，初始化为 NaN。
peak_idx = NaN;                                % 峰值平面在 z 数组中的索引，初始化为 NaN。
peak_on_axis = -Inf;                           % 当前找到的最大轴上强度，初始化为负无穷。
target_mask = r_sample <= target_core_radius_mm; % 目标半径内的像素 mask，用于统计中心功率占比。
peak_power_in_core = NaN;                      % 峰值平面目标半径内功率占比，初始化为 NaN。

roi_radius_mm = cfg.roi_radius_um * 1e-3;      % 把诊断图 ROI 半径从 um 转为 mm。
roi_idx = find(abs(sample_axis_mm) <= roi_radius_mm); % 找到中心 ROI 对应的像素索引。

fprintf('Focused Bessel-Gauss scan: %d z planes, %.3f um/pixel, %.1f um dz.\n', ...
    num_z, dx_sample_um, cfg.dz_um);           % 在命令行打印扫描规模，方便判断运行量。

for iz = 1:num_z                               % 遍历每一个 z 平面。
    H = exp(1i * z_values_mm(iz) .* kz);       % 当前 z 距离对应的角谱传播传递函数。
    E_z = ifft2(ifftshift(F0 .* H));           % 把角谱传播回实空间，得到该 z 平面的复电场。
    I_z = abs(E_z).^2;                         % 计算强度 I = |E|^2。

    xz_slice(:, iz) = single(I_z(center_idx, :)).'; % 保存 y=0 中心横截线，形成 XZ 剖面。
    on_axis(iz) = I_z(center_idx, center_idx);      % 保存轴上中心点强度。

    if z_values_mm(iz) >= cfg.metric_z_min_mm && on_axis(iz) > peak_on_axis % 只在有效 z 范围内寻找峰值。
        peak_on_axis = on_axis(iz);             % 更新当前最大轴上强度。
        peak_idx = iz;                          % 记录峰值平面索引。
        peak_z_mm = z_values_mm(iz);            % 记录峰值平面 z 位置。
        peak_xy = single(I_z(roi_idx, roi_idx)); % 保存峰值平面中心 ROI 的 XY 强度图。
        peak_center_row = double(I_z(center_idx, :)); % 保存峰值平面中心横截线。
        peak_power_in_core = sum(I_z(target_mask), 'all') / sum(I_z, 'all'); % 计算目标半径内功率占比。
    end                                        % 峰值更新判断结束。
end                                           % z 扫描循环结束。

if isempty(peak_xy)                            % 如果没有找到峰值平面，说明配置不合理。
    error('No peak plane found. Reduce metric_z_min_mm or increase z_span_mm.'); % 给出调整建议。
end                                           % 峰值平面存在性检查结束。

metric_mask = z_values_mm >= cfg.metric_z_min_mm; % 指标计算时忽略初始附近的 z 平面。
transverse_fwhm_um = fwhm_1d(sample_axis_mm * 1e3, peak_center_row); % 计算峰值平面的横向 FWHM，单位 um。
axial_fwhm_mm = fwhm_1d(z_values_mm(metric_mask), on_axis(metric_mask)); % 计算轴上强度的轴向 FWHM，单位 mm。
z_relative_mm = z_values_mm - peak_z_mm;       % 把 z 坐标平移成相对峰值平面的位置，便于画图。

% 结果目录名只包含关键参数，不包含时间；同一组参数重复运行会覆盖同一目录内的结果。
run_name = sprintf('D%gum_L%gmm__dx%gum_dz%gum__M%g', ...
    cfg.target_core_diameter_um, cfg.target_length_mm, ...
    dx_sample_um, cfg.dz_um, cfg.M);           % 根据目标尺寸、采样和倍率生成目录名。
run_name = strrep(run_name, '.', 'p');         % Windows 路径里小数点太多不易读，用 p 代替小数点。
run_dir = fullfile(cfg.output_root_dir, run_name); % 拼出本次参数对应的输出文件夹。
if ~exist(run_dir, 'dir')                      % 如果该参数文件夹不存在。
    mkdir(run_dir);                            % 创建该参数文件夹。
end                                           % 输出文件夹检查结束。

readme_path = fullfile(run_dir, '00_README_what_is_this.txt');        % 中文说明文件，建议最先看。
slm_path = fullfile(run_dir, '01_SLM_phase_upload_to_SLM.bmp');       % 给 SLM 用的 8-bit 相位图。
diag_path = fullfile(run_dir, '02_beam_diagnostics_XY_XZ_axis.png');  % 光束形状诊断图。
metrics_path = fullfile(run_dir, '03_metrics_summary.txt');           % 人类可读的关键指标摘要。
mat_path = fullfile(run_dir, '04_metrics_data_for_MATLAB.mat');       % MATLAB 可读的结构体数据。

imwrite(slm_phase_8bit, slm_path);             % 把 SLM 相位图写成 bmp 文件。
write_diagnostics(cfg, slm_phase_8bit, sample_axis_mm, roi_idx, peak_xy, ...
    xz_slice, z_relative_mm, on_axis, peak_idx, diag_path); % 生成综合诊断图。

metrics = struct();                            % 新建结果结构体，集中保存参数和计算结果。
metrics.beam_mode = "focused_bessel_gauss";    % 标记当前仿真类型。
metrics.run_name = string(run_name);           % 保存输出目录名。
metrics.run_dir = string(run_dir);             % 保存输出目录完整路径。
metrics.target_core_diameter_um = cfg.target_core_diameter_um; % 保存目标横向直径。
metrics.target_length_mm = cfg.target_length_mm;               % 保存目标轴向长度。
metrics.core_metric = cfg.core_metric;         % 保存横向尺寸定义。
metrics.medium_n = cfg.medium_n;               % 保存传播介质折射率。
metrics.lambda_mm = cfg.lambda_mm;             % 保存激光波长。
metrics.M = cfg.M;                             % 保存等效缩小倍率。
metrics.N = cfg.N;                             % 保存网格点数。
metrics.slm_size_mm = cfg.slm_size_mm;         % 保存 SLM 有效口径。
metrics.sample_size_mm = sample_size_mm;       % 保存样品侧计算窗口尺寸。
metrics.sample_dx_um = dx_sample_um;           % 保存样品侧横向采样间隔。
metrics.dz_um = cfg.dz_um;                     % 保存 z 方向采样间隔。
metrics.transverse_fwhm_um = transverse_fwhm_um; % 保存计算得到的横向 FWHM。
metrics.axial_fwhm_mm = axial_fwhm_mm;         % 保存计算得到的轴向 FWHM。
metrics.peak_z_mm = peak_z_mm;                 % 保存峰值平面 z 位置。
metrics.beta_sample_deg = rad2deg(beta_sample); % 保存样品侧锥角，单位 deg。
metrics.beta_slm_deg = rad2deg(beta_slm);      % 保存 SLM 侧等效锥角，单位 deg。
metrics.kr_target_rad_per_mm = kr_target;      % 保存目标横向波矢，单位 rad/mm。
metrics.axial_waist_scale = cfg.axial_waist_scale; % 保存轴向长度经验校正系数。
metrics.input_waist_sample_um = sample_waist_mm * 1e3; % 保存样品侧高斯包络半径，单位 um。
metrics.input_waist_slm_mm = slm_waist_mm;     % 保存 SLM 侧高斯包络半径，单位 mm。
metrics.focus_distance_sample_mm = cfg.focus_distance_sample_mm; % 保存样品侧等效焦距。
metrics.focus_distance_slm_mm = focus_distance_slm_mm;           % 保存 SLM 侧等效焦距。
metrics.power_fraction_inside_target_core = peak_power_in_core;  % 保存目标半径内功率占比。
metrics.slm_phase_min_uint8 = double(min(slm_phase_8bit(:)));    % 保存 SLM 图最小灰度。
metrics.slm_phase_max_uint8 = double(max(slm_phase_8bit(:)));    % 保存 SLM 图最大灰度。
metrics.readme_path = string(readme_path);      % 保存 README 输出路径。
metrics.slm_path = string(slm_path);            % 保存 SLM 图输出路径。
metrics.diagnostics_path = string(diag_path);   % 保存诊断图输出路径。
metrics.metrics_path = string(metrics_path);    % 保存指标摘要输出路径。
metrics.mat_path = string(mat_path);            % 保存 MAT 数据输出路径。

save(mat_path, 'metrics');                      % 保存 MATLAB 数据文件，供后续脚本读取。
write_metrics_text(metrics_path, metrics);      % 写人类可读的指标摘要。
write_run_readme_text(readme_path, metrics);    % 写中文说明文件。
end                                           % 主仿真函数结束。

function phase_8bit = phase_to_uint8(phase_rad)
% phase_to_uint8
% SLM 通常只能加载 8-bit 灰度图；这里把任意实数相位包裹到 [-pi, pi] 后映射到 [0, 255]。

phase_wrapped = angle(exp(1i * phase_rad));    % 用 exp(i*phase) 再取 angle，实现相位包裹。
phase_norm = (phase_wrapped + pi) ./ (2*pi);   % 把 [-pi, pi] 线性映射到 [0, 1]。
phase_8bit = uint8(round(255 * phase_norm));   % 把 [0, 1] 映射到 8-bit 灰度 [0, 255]。
end                                           % 相位转换函数结束。

function width = fwhm_1d(axis_values, values)
% fwhm_1d
% 计算一维曲线的 full width at half maximum，即半高全宽。
% 输入 axis_values 是坐标轴，values 是该坐标轴上的强度曲线。

axis_values = double(axis_values(:));          % 把坐标轴转成 double 列向量，方便统一处理。
values = double(values(:));                    % 把强度值转成 double 列向量。
valid = isfinite(axis_values) & isfinite(values); % 找出坐标和值都为有限数的点。
axis_values = axis_values(valid);              % 删除 NaN 或 Inf 坐标点。
values = values(valid);                        % 删除 NaN 或 Inf 强度点。

if numel(values) < 3 || max(values) <= 0       % 如果有效点太少或曲线没有正峰值。
    width = NaN;                               % 返回 NaN，表示无法计算 FWHM。
    return                                     % 直接退出函数。
end                                           % 基本有效性检查结束。

[peak_value, peak_idx] = max(values);          % 找到最大值及其索引。
half_value = peak_value / 2;                   % 半高值 = 峰值的一半。

left_idx = find(values(1:peak_idx) <= half_value, 1, 'last'); % 峰值左侧最后一个低于半高的点。
right_idx = peak_idx - 1 + find(values(peak_idx:end) <= half_value, 1, 'first'); % 峰值右侧第一个低于半高的点。

if isempty(left_idx) || isempty(right_idx) || right_idx <= left_idx % 如果左右半高交点不存在。
    width = NaN;                               % 返回 NaN，说明曲线没有完整半高宽。
    return                                     % 直接退出函数。
end                                           % 半高交点检查结束。

x_left = interp1(values(left_idx:left_idx+1), axis_values(left_idx:left_idx+1), ...
    half_value, 'linear', 'extrap');           % 线性插值得到左侧半高交点坐标。
x_right = interp1(values(right_idx-1:right_idx), axis_values(right_idx-1:right_idx), ...
    half_value, 'linear', 'extrap');           % 线性插值得到右侧半高交点坐标。
width = abs(x_right - x_left);                 % FWHM = 两个半高交点的距离。
end                                           % FWHM 函数结束。

function write_diagnostics(cfg, slm_phase_8bit, sample_axis_mm, roi_idx, peak_xy, ...
    xz_slice, z_relative_mm, on_axis, peak_idx, diag_path)
% write_diagnostics
% 生成一张 2x2 诊断图，方便快速判断这个 hologram 是否形成了期望光束。

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 800]); % 创建不可见图窗，用于后台保存图片。
tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');       % 使用 2x2 紧凑布局。

nexttile;                                % 第 1 幅子图：SLM 相位图。
imagesc(slm_phase_8bit);                 % 显示 8-bit SLM 相位灰度图。
axis image;                              % 保持 x/y 比例一致，避免图像变形。
colormap(gca, gray);                     % 当前子图使用灰度色图，更接近 SLM bmp。
colorbar;                                % 显示灰度条。
title('SLM phase uint8');                % 子图标题：SLM 相位。
xlabel('SLM pixel');                     % x 轴单位是 SLM 像素。
ylabel('SLM pixel');                     % y 轴单位是 SLM 像素。

roi_axis_um = sample_axis_mm(roi_idx) * 1e3; % ROI 坐标轴从 mm 转换为 um。
nexttile;                                % 第 2 幅子图：峰值平面 XY 强度。
imagesc(roi_axis_um, roi_axis_um, peak_xy); % 显示峰值平面中心 ROI 的二维强度。
axis image;                              % 保持 x/y 比例一致。
colorbar;                                % 显示强度色条。
title('Peak-plane XY intensity');        % 子图标题：峰值平面 XY 强度。
xlabel('x (um)');                        % x 轴单位 um。
ylabel('y (um)');                        % y 轴单位 um。

xz_radius_mm = cfg.roi_radius_um * 1e-3; % XZ 剖面显示半径，从 um 转为 mm。
xz_idx = find(abs(sample_axis_mm) <= xz_radius_mm); % 找到 XZ 剖面中需要显示的横向范围。
nexttile;                                % 第 3 幅子图：中心 XZ 剖面。
imagesc(z_relative_mm, sample_axis_mm(xz_idx) * 1e3, xz_slice(xz_idx, :)); % 显示 x-z 强度分布。
axis xy;                                 % 让 y 轴向上为正，符合常规坐标显示。
colorbar;                                % 显示强度色条。
title('Center XZ intensity');            % 子图标题：中心 XZ 强度。
xlabel('z - peak z (mm)');               % 横轴是相对峰值平面的 z 坐标。
ylabel('x (um)');                        % 纵轴是横向 x 坐标，单位 um。

nexttile;                                % 第 4 幅子图：轴上强度曲线。
plot(z_relative_mm, on_axis ./ max(on_axis), 'LineWidth', 1.2); % 画归一化轴上强度。
hold on;                                 % 保持当前坐标轴，继续叠加峰值点和半高线。
plot(z_relative_mm(peak_idx), on_axis(peak_idx) ./ max(on_axis), 'ro'); % 用红点标出峰值位置。
yline(0.5, 'k:');                        % 画半高参考线，用于肉眼估计轴向 FWHM。
grid on;                                 % 打开网格，方便读数。
title('Normalized on-axis intensity');   % 子图标题：归一化轴上强度。
xlabel('z - peak z (mm)');               % 横轴是相对峰值平面的 z 坐标。
ylabel('I / max(I)');                    % 纵轴是归一化强度。

export_figure(fig, diag_path);           % 把诊断图保存到文件。
close(fig);                              % 关闭后台图窗，释放资源。
end                                      % 诊断图函数结束。

function export_figure(fig, output_path)
% export_figure
% 优先使用 exportgraphics 保存高质量图片；如果 MATLAB 版本或环境不支持，则退回 saveas。

try                                      % 尝试使用较新的导出接口。
    exportgraphics(fig, output_path, 'Resolution', 160); % 以 160 dpi 保存图像。
catch                                    % 如果 exportgraphics 失败。
    saveas(fig, output_path);            % 使用兼容性更好的 saveas 保存。
end                                      % 导出异常处理结束。
end                                      % 图片导出函数结束。

function write_metrics_text(metrics_path, metrics)
% write_metrics_text
% 写一个给人看的中文结果摘要，同时把原始字段也列出来，方便检查参数。

fid = fopen(metrics_path, 'w', 'n', 'UTF-8'); % 用 UTF-8 打开文本文件，确保中文正常保存。
if fid < 0                                  % 如果文件打开失败。
    error('Unable to write metrics file: %s', metrics_path); % 报错并指出目标路径。
end                                         % 文件打开检查结束。
cleanup = onCleanup(@() fclose(fid));       % 无论函数如何退出，都自动关闭文件句柄。

fprintf(fid, '聚焦有限长度 Bessel-Gauss 光束仿真结果\n'); % 写标题。
fprintf(fid, '====================================\n\n'); % 写标题分隔线。

fprintf(fid, '先看这几个结果：\n');          % 写关键结果区标题。
fprintf(fid, '- 横向焦斑直径 FWHM: %.3f um\n', metrics.transverse_fwhm_um); % 写横向 FWHM。
fprintf(fid, '- 轴向高强度长度 FWHM: %.3f mm\n', metrics.axial_fwhm_mm);    % 写轴向 FWHM。
fprintf(fid, '- 峰值位置: %.3f mm after local propagation start\n', metrics.peak_z_mm); % 写峰值 z。
fprintf(fid, '- 样品侧锥角: %.3f deg\n', metrics.beta_sample_deg);          % 写样品侧锥角。
fprintf(fid, '- SLM侧等效锥角: %.3f deg\n', metrics.beta_slm_deg);          % 写 SLM 侧锥角。
fprintf(fid, '- 目标半径内功率占比: %.4f\n\n', metrics.power_fraction_inside_target_core); % 写中心功率占比。

fprintf(fid, '这个文件夹里的文件：\n');      % 写输出文件说明区标题。
fprintf(fid, '- 00_README_what_is_this.txt: 每个输出文件的中文说明。\n');        % 说明 README。
fprintf(fid, '- 01_SLM_phase_upload_to_SLM.bmp: 给 SLM 用的 8-bit 相位图，不是光强图。\n'); % 说明 SLM 图。
fprintf(fid, '- 02_beam_diagnostics_XY_XZ_axis.png: 快速检查光束形状的诊断图。\n');      % 说明诊断图。
fprintf(fid, '- 03_metrics_summary.txt: 当前这个文字摘要。\n');                 % 说明本文件。
fprintf(fid, '- 04_metrics_data_for_MATLAB.mat: MATLAB 结构体数据，方便之后脚本读取。\n\n'); % 说明 MAT 文件。

fprintf(fid, '重要限制：\n');                % 写限制说明区标题。
fprintf(fid, '- 这是空气中的线性传播仿真。\n'); % 说明当前物理模型。
fprintf(fid, '- 这里还没有 KBr 界面、折射率不连续、非线性吸收、等离子体、冲击波或碎屑散射模型。\n'); % 说明未包含效应。
fprintf(fid, '- 这个结果只能说明 hologram 的光场形状是否接近目标，不能直接证明排屑效果。\n\n'); % 说明结果边界。

fprintf(fid, '原始字段：\n');                % 写原始字段区标题。
fields = fieldnames(metrics);               % 取出 metrics 结构体的全部字段名。
for i = 1:numel(fields)                     % 遍历每一个字段。
    name = fields{i};                       % 当前字段名。
    value = metrics.(name);                 % 当前字段值。
    if isstring(value) || ischar(value)      % 如果字段是字符串。
        fprintf(fid, '%s: %s\n', name, char(value)); % 按字符串格式写入。
    elseif isnumeric(value) && isscalar(value) % 如果字段是数值标量。
        fprintf(fid, '%s: %.12g\n', name, value);    % 按高精度数值写入。
    else                                    % 如果字段是其它类型或数组。
        fprintf(fid, '%s: %s\n', name, mat2str(value)); % 尝试用 mat2str 写入。
    end                                     % 字段类型判断结束。
end                                         % 字段遍历结束。
end                                         % 指标摘要写入函数结束。

function write_run_readme_text(readme_path, metrics)
% write_run_readme_text
% 写一个最先阅读的中文说明文件，解释这个输出文件夹中每个文件是什么。

fid = fopen(readme_path, 'w', 'n', 'UTF-8'); % 用 UTF-8 创建 README 文本文件。
if fid < 0                                  % 如果文件打开失败。
    error('Unable to write readme file: %s', readme_path); % 报错并指出目标路径。
end                                         % 文件打开检查结束。
cleanup = onCleanup(@() fclose(fid));       % 函数退出时自动关闭文件。

fprintf(fid, '这个文件夹是什么？\n');        % 写 README 第一节标题。
fprintf(fid, '==================\n\n');      % 写标题分隔线。
fprintf(fid, '这是一次 focused Bessel-Gauss drilling beam 仿真输出。\n'); % 说明文件夹用途。
fprintf(fid, '文件夹名记录了这次仿真的关键输入参数：\n'); % 说明目录名含义。
fprintf(fid, '- D%gum: 目标横向焦斑直径约 %g um，按强度 FWHM 定义。\n', ...
    metrics.target_core_diameter_um, metrics.target_core_diameter_um); % 解释 D。
fprintf(fid, '- L%gmm: 目标轴向高强度长度约 %g mm。\n', ...
    metrics.target_length_mm, metrics.target_length_mm);               % 解释 L。
fprintf(fid, '- dx%gum: 样品面横向采样约 %.3g um/pixel。\n', ...
    metrics.sample_dx_um, metrics.sample_dx_um);                       % 解释 dx。
fprintf(fid, '- dz%gum: z 方向采样 %g um/step。\n', ...
    metrics.dz_um, metrics.dz_um);                                     % 解释 dz。
fprintf(fid, '- M%g: SLM 到样品面的等效缩小倍率 %g。\n\n', ...
    metrics.M, metrics.M);                                             % 解释 M。

fprintf(fid, '应该先看哪个文件？\n');      % 写阅读顺序标题。
fprintf(fid, '==================\n\n');    % 写标题分隔线。
fprintf(fid, '1. 先看 02_beam_diagnostics_XY_XZ_axis.png\n'); % 第一优先级是诊断图。
fprintf(fid, '   这个图告诉你光束到底长什么样：SLM相位、峰值平面XY强度、中心XZ剖面、轴上强度曲线。\n\n'); % 解释诊断图。
fprintf(fid, '2. 再看 03_metrics_summary.txt\n'); % 第二优先级是指标摘要。
fprintf(fid, '   这里有最重要的数字，比如横向FWHM、轴向FWHM、峰值位置、锥角。\n\n'); % 解释指标摘要。
fprintf(fid, '3. 真正要放到SLM上的文件是 01_SLM_phase_upload_to_SLM.bmp\n'); % 第三说明 SLM 文件。
fprintf(fid, '   这是 8-bit phase-only hologram。灰度值表示相位，不表示光强。\n\n'); % 解释相位图含义。
fprintf(fid, '4. 04_metrics_data_for_MATLAB.mat 是给后续 MATLAB 脚本读的，不是给人工直接看的。\n\n'); % 解释 MAT 文件。

fprintf(fid, '这次运行的核心结果\n');       % 写核心结果标题。
fprintf(fid, '==================\n\n');     % 写标题分隔线。
fprintf(fid, '- 横向焦斑直径 FWHM: %.3f um\n', metrics.transverse_fwhm_um); % 写横向 FWHM。
fprintf(fid, '- 轴向高强度长度 FWHM: %.3f mm\n', metrics.axial_fwhm_mm);    % 写轴向 FWHM。
fprintf(fid, '- 峰值位置: %.3f mm after local propagation start\n', metrics.peak_z_mm); % 写峰值位置。
fprintf(fid, '- 样品侧锥角: %.3f deg\n', metrics.beta_sample_deg);          % 写样品侧锥角。
fprintf(fid, '- SLM侧等效锥角: %.3f deg\n\n', metrics.beta_slm_deg);        % 写 SLM 侧锥角。

fprintf(fid, '注意\n');                    % 写注意事项标题。
fprintf(fid, '====\n\n');                  % 写标题分隔线。
fprintf(fid, '这个版本只是在空气中看光场形状，还没有模拟 KBr 内部加工、烧蚀、冲击波、裂纹、碎屑或者散射。\n'); % 说明模型限制。
fprintf(fid, '所以它适合用来判断 SLM hologram 能不能形成目标光束，不适合直接判断排屑是否成功。\n'); % 说明使用边界。
end                                        % README 写入函数结束。
