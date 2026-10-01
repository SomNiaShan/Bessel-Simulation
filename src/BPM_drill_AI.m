% BPM_drill_AI 主脚本
% 这个脚本的目标是：
% 1. 先定义一组默认的仿真参数；
% 2. 根据这些参数构造入射光场和相位；
% 3. 使用 FFT-BPM 方法沿 z 方向传播光场；
% 4. 计算传播后的强度、功率密度等后处理结果；
% 5. 绘图并按需要导出 3D 强度和相位文件。
%
% 如果你想在“不改源码”的前提下临时改参数，
% 可以在 MATLAB 工作区先定义一个 struct，名字叫：
% BPM_drill_AI_overrides
% 然后再运行这个脚本。
%
% 如果你想系统了解每个参数的物理意义、调大/调小的效果和使用建议，
% 可以配合阅读：
% ../docs/BPM_drill_AI_参数说明.md

tic; % 启动计时器，用来统计整份脚本从开始到结束的总耗时

params = localBuildDefaultParams(); % 先生成一份完整的默认参数结构体
if exist('BPM_drill_AI_overrides', 'var') % 如果工作区里存在同名覆盖参数
    params = localApplyWorkspaceOverrides(params, BPM_drill_AI_overrides); % 就用外部参数覆盖默认参数
end
params.output.outputDir = localEnsureOutputDirectory(); % 确保输出目录存在，并把路径写回参数结构体
if params.output.writeProgressLog
    params.output.progressLogFile = localEnsureProgressLogFile(params.output); % 准备进度日志文件路径，方便 VS Code 里确认程序还在运行
else
    params.output.progressLogFile = '';
end

results = localRunSimulation(params); % 按照参数执行完整仿真，并把所有结果收进 results 结构体

% 下面这几个变量保留下来，是为了兼容你之前直接在工作区里查看变量的习惯。
E = results.inputField; % 输入到传播模块之前的复振幅场
F = results.angularSpectrum; % 输入场对应的角谱
E_3D_BPM = results.propagation.E3D; % BPM 传播得到的三维复场
phase_all = results.phase.all; % 叠加后的总相位
phase_helical = results.phase.helical; % 单独的 helical 相位
phase_checkerboard_bessel = results.phase.checkerboardBessel; % 棋盘 Bessel vortex 相位
aperture_mask = results.aperture.mask; % SLM 平面的圆形振幅孔径 mask
aperture_transmission = results.aperture.transmission; % 孔径后/孔径前的功率比
output_dir = params.output.outputDir; % 输出目录，保留成工作区变量方便你查看

if params.output.plotFigures % 如果允许绘图
    localPlotResults(results, params); % 就把主要结果画出来
end

localExportResults(results, params); % 按导出开关决定是否保存 3D 强度图和相位图
toc; % 输出脚本总运行时间

function params = localBuildDefaultParams()
% localBuildDefaultParams
% 作用：构造整份脚本使用的默认参数。
% 这里把参数分成 simulation / laser / beam / phase / optics / material / output 七组，
% 这样后面读代码时更容易知道每个参数属于哪一块。

params = struct(); % 新建最外层参数结构体

params.simulation = struct( ... % 与数值仿真网格和传播步进有关的参数
    'N', 1080, ... % 横向采样点数，即 x-y 平面是 N x N 的网格
    'sizeMm', 8.64, ... % 横向计算窗口的物理尺寸，单位 mm
    'zRangeMm', 1000, ... % 沿 z 方向总共传播多远，单位 mm
    'dzMm', 5, ... % 沿 z 方向每一步传播多远，单位 mm
    'useBPM', true); % 是否启用 BPM 传播；若为 false，则只返回输入场

params.laser = struct( ... % 与激光源自身有关的参数
    'wavelengthMm', double(1.030e-3), ... % 激光波长，单位 mm；1.030e-3 mm = 1030 nm
    'powerW', 40, ... % 平均功率，单位 W
    'repetitionRateHz', 100e3, ... % 重复频率，单位 Hz
    'pulseWidthS', 275e-15); % 脉宽，单位 s

params.beam = struct( ... % 与入射光束横向包络有关的参数
    'waistRadiusMm', 2.5, ... % 高斯光束腰半径，单位 mm
    'fieldAmplitude', 1); % 输入场的幅值系数

params.phase = struct( ... % 与相位构造有关的参数
    'airyStrength', 0, ... % Airy 三次相位的强度系数；0 表示关闭
    'airyScaleMm', 1, ... % Airy 相位里的尺度参数，单位 mm
    'apertureRadiusMm', 0, ... % Circular amplitude-aperture radius at the SLM plane; 0 means fully open
    'axiconGeometry', 'circular', ... % circular / linear1D; circular preserves the original radial axicon
    'axiconOrientationDeg', 0, ... % Normal direction of the 1D axicon phase; 0 deg means variation along x
    'axiconMode', 'radialCycles', ... % axicon 定义方式：coneAngle / radialPeriodMm / radialPeriodPx / radialCycles / physicalEquivalent
    'axiconConeAngleDeg', 0.428775541709431, ... % SLM 全息 axicon 的有效出射锥角 beta，单位度
    'axiconRadialPeriodMm', 0.13763659070689, ... % SLM 径向 2pi 相位周期，单位 mm
    'axiconRadialPeriodPx', 17.2045738383613, ... % SLM 径向 2pi 相位周期，单位为当前仿真像素
    'axiconRadialCycles', 10, ... % 中心到归一化半径 rho=1 处的 axicon 径向 2pi 周期数
    'axiconIndex', 1.4287, ... % axicon 材料折射率
    'axiconAngleDeg', 1, ... % axicon 底角，单位度
    'curvedMaxShiftXMm', 0, ... % 曲线 Bessel 末端期望 x 方向横向偏移量，单位 mm
    'curvedMaxShiftYMm', 0, ... % 曲线 Bessel 末端期望 y 方向横向偏移量，单位 mm
    'compensationPhase', 0, ... % 额外补偿相位，目前默认关闭
    'vortexCharge', 0, ... % 涡旋相位的拓扑荷数 l
    'checkerboardBesselEnabled', false, ... % Enable checkerboard-multiplexed Bessel vortex phase.
    'checkerboardTileSizePx', 50, ... % Checkerboard tile size in generated phase-map pixels.
    'checkerboardTc1', 1, ... % Topological charge of checkerboard Bessel vortex beam 1.
    'checkerboardTc2', -1, ... % Topological charge of checkerboard Bessel vortex beam 2.
    'checkerboardBeta1Deg', 0.428775541709431, ... % Axicon cone angle beta_1 for checkerboard beam 1, in degrees.
    'checkerboardBeta2Deg', 0.428775541709431, ... % Axicon cone angle beta_2 for checkerboard beam 2, in degrees.
    'helicalGamma', 1.3, ... % helical 相位的调制度
    'helicalOrder', 1, ... % helical 相位中的角向频率阶数 m
    'helicalPhaseOffset', 0, ... % helical 相位的初始相位偏置，单位度；代入公式前会转换为弧度
    'omegaInner', 5, ... % 径向 chirp 在中心处的频率参数
    'omegaOuter', 5); % 径向 chirp 在边缘处的频率参数

params.optics = struct( ... % 与传播过程中可能加入的透镜/样品有关的参数
    'lens1FocalLengthMm', 200, ... % 第一片透镜焦距，单位 mm
    'lens2FocalLengthMm', 40, ... % 第二片透镜焦距，单位 mm
    'lens1PositionMm', 400, ... % 第一片透镜放置位置，单位 mm
    'lens2PositionMm', 640, ... % 第二片透镜放置位置，单位 mm
    'samplePositionMm', 660, ... % 样品在 z 轴上的绝对位置，单位 mm
    'lens1Enabled', true, ... % 是否真的在传播中加入第一片透镜
    'lens2Enabled', true, ... % 是否真的在传播中加入第二片透镜
    'sampleEnabled', true); % 是否真的在传播中切换到样品折射率

params.material = struct( ... % 与介质本身有关的参数
    'backgroundIndex', 1, ... % 背景介质折射率；默认取空气 n=1
    'sampleIndex', 1.7551, ... % 样品折射率；这里沿用原来的 sapphire 数值
    'damageThresholdWPerM2', 7.2e17); % 材料损伤阈值，单位 W/m^2；对应实验值 7.2e13 W/cm^2

params.output = struct( ... % 与绘图和导出有关的参数
    'write3DIntensity', false, ... % 是否导出三维强度切片 tif
    'writeAllPhase', false, ... % 是否导出总 SLM 相位 bmp
    'writeHelicalPhase', false, ... % 是否导出单独的 helical 相位 bmp
    'writeHelicalOffsetSlmBatch', false, ... % 是否批量扫描 helicalPhaseOffset 并导出总 SLM 相位 bmp
    'helicalOffsetStartDeg', 0, ... % helicalPhaseOffset 批量扫描的起始角度，单位度
    'helicalOffsetEndDeg', 359, ... % helicalPhaseOffset 批量扫描的结束角度，单位度
    'helicalOffsetStepDeg', 1, ... % helicalPhaseOffset 批量扫描的步长，单位度
    'helicalOffsetSlmSubfolder', 'SLM_phase_helical_offset_0_to_359', ... % helicalPhaseOffset 批量 SLM 图保存到 outputs 下面的这个子文件夹
    'writeRotatedSlmBatch', false, ... % 是否几何旋转已生成的 bitmap；这不是当前需要的物理扫描，默认关闭
    'rotatedSlmStartAngleDeg', 0, ... % 批量旋转导出的起始角度，单位度
    'rotatedSlmEndAngleDeg', 359, ... % 批量旋转导出的结束角度，单位度
    'rotatedSlmStepDeg', 1, ... % 批量旋转导出的角度步长，单位度
    'rotatedSlmClockwise', false, ... % true 表示顺时针旋转；false 表示逆时针旋转
    'rotatedSlmSubfolder', 'SLM_phase_rotated_0_to_359', ... % 批量旋转 SLM 图单独保存到 outputs 下面的这个子文件夹
    'plotFigures', false, ... % 是否绘制图窗
    'cropHalfWidthPixels', 100, ... % 导出 3D 强度时，围绕中心裁剪的半宽像素数
    'referenceSliceIndex', 30, ... % 用于做功率密度归一化参考的 z 切片编号
    'printProgress', false, ... % 是否在 MATLAB/VS Code 终端里打印 BPM 进度
    'progressIntervalSeconds', 5, ... % 每隔多少秒打印一次进度
    'writeProgressLog', false, ... % 是否把 BPM 进度同步写入 outputs 里的 log 文件
    'progressLogFile', '', ... % 进度日志文件路径；留空时程序自动放到 outputs/BPM_drill_AI_progress.log
    'outputDir', ''); % 输出目录；稍后由程序自动填入
end

function params = localApplyWorkspaceOverrides(params, overrides)
% localApplyWorkspaceOverrides
% 作用：把工作区传进来的 overrides 结构体合并到默认参数里。
% 用法适合临时改一小部分参数，而不必去手改主文件。

if ~isstruct(overrides) % 如果用户传入的覆盖参数不是结构体
    error('BPM_drill_AI_overrides must be a struct.'); % 就报错，提醒输入格式不对
end

if isfield(overrides, 'optics') && isstruct(overrides.optics) && ...
        isfield(overrides.optics, 'sampleOffsetFromLens2Mm') && ...
        ~isfield(overrides.optics, 'samplePositionMm')
    lens2PositionMm = params.optics.lens2PositionMm;
    if isfield(overrides.optics, 'lens2PositionMm')
        lens2PositionMm = overrides.optics.lens2PositionMm;
    end
    overrides.optics.samplePositionMm = lens2PositionMm + overrides.optics.sampleOffsetFromLens2Mm;
end

overrides = localNormalizeLegacyCurvedShiftOverrides(overrides); % 兼容旧脚本里 curvedMaxShiftMm 只控制 x 方向的用法
overrides = localNormalizeLegacyAxiconOverrides(overrides); % 兼容旧脚本里只覆盖 axiconAngleDeg/axiconIndex 的用法
params = localMergeStructs(params, overrides); % 真正执行结构体递归合并
end

function overrides = localNormalizeLegacyCurvedShiftOverrides(overrides)
if ~isfield(overrides, 'phase') || ~isstruct(overrides.phase)
    return;
end

if isfield(overrides.phase, 'curvedMaxShiftMm')
    if ~isfield(overrides.phase, 'curvedMaxShiftXMm')
        overrides.phase.curvedMaxShiftXMm = overrides.phase.curvedMaxShiftMm;
    end
    overrides.phase = rmfield(overrides.phase, 'curvedMaxShiftMm');
end
end

function overrides = localNormalizeLegacyAxiconOverrides(overrides)
% localNormalizeLegacyAxiconOverrides
% 作用：如果旧的 overrides 只设置了真实 axicon 的 n/底角，
% 就自动切到 physicalEquivalent，避免旧参数被新的默认 coneAngle 模式忽略。

if ~isfield(overrides, 'phase') || ~isstruct(overrides.phase)
    return;
end

phaseFields = fieldnames(overrides.phase);
usesPhysicalFields = any(strcmp(phaseFields, 'axiconIndex')) || any(strcmp(phaseFields, 'axiconAngleDeg'));
usesNewDefinitionFields = any(strcmp(phaseFields, 'axiconMode')) || ...
    any(strcmp(phaseFields, 'axiconConeAngleDeg')) || ...
    any(strcmp(phaseFields, 'axiconRadialPeriodMm')) || ...
    any(strcmp(phaseFields, 'axiconRadialPeriodPx')) || ...
    any(strcmp(phaseFields, 'axiconRadialCycles'));

if usesPhysicalFields && ~usesNewDefinitionFields
    overrides.phase.axiconMode = 'physicalEquivalent';
end
end

function merged = localMergeStructs(baseStruct, overrideStruct)
% localMergeStructs
% 作用：递归地把 overrideStruct 合并进 baseStruct。
% 如果某个字段本身还是结构体，就继续往下合并；
% 如果某个字段是普通数值/字符串/逻辑值，就直接覆盖。

merged = baseStruct; % 先把默认参数作为合并后的初值
overrideFields = fieldnames(overrideStruct); % 取出所有待覆盖字段的名字

for i = 1:numel(overrideFields) % 逐个字段处理
    fieldName = overrideFields{i}; % 当前正在处理的字段名
    overrideValue = overrideStruct.(fieldName); % 当前字段在覆盖参数中的值

    if isfield(baseStruct, fieldName) && isstruct(baseStruct.(fieldName)) && isstruct(overrideValue) % 如果默认值和覆盖值都是结构体
        merged.(fieldName) = localMergeStructs(baseStruct.(fieldName), overrideValue); % 就递归合并子结构体
    else % 否则说明这是最底层字段，或者默认值/覆盖值不是同类结构
        merged.(fieldName) = overrideValue; % 直接用覆盖值替换
    end
end
end

function outputDir = localEnsureOutputDirectory()
% localEnsureOutputDirectory
% 作用：定位当前脚本所在的项目目录，并确保 outputs 文件夹存在。

scriptDir = fileparts(mfilename('fullpath')); % 当前脚本所在目录，例如 .../Bessel-Simulation/src
repoRoot = fileparts(scriptDir); % 项目根目录，例如 .../Bessel-Simulation
outputDir = fullfile(repoRoot, 'outputs'); % 最终输出目录为项目根目录下的 outputs

if exist(outputDir, 'dir') ~= 7 % 如果这个目录还不存在
    mkdir(outputDir); % 就创建它
end
end

function progressLogFile = localEnsureProgressLogFile(outputParams)
% localEnsureProgressLogFile
% 作用：决定进度日志文件写到哪里。
% 默认写到 outputs/BPM_drill_AI_progress.log。

if strlength(string(outputParams.progressLogFile)) > 0 % 如果用户自己指定了日志路径
    progressLogFile = outputParams.progressLogFile; % 就直接使用用户指定的路径
else % 如果用户没有指定
    progressLogFile = fullfile(outputParams.outputDir, 'BPM_drill_AI_progress.log'); % 默认写到 outputs 文件夹
end
end

function results = localRunSimulation(params)
% localRunSimulation
% 作用：把“建网格 -> 算派生量 -> 构造相位 -> 传播 -> 后处理”这一整套流程串起来。
% 这样主脚本顶层就比较干净，一眼能看出执行顺序。

grid = localSetupGrid(params.simulation); % 根据仿真尺寸和采样点数建立空间网格与频域网格
derived = localBuildDerivedQuantities(params); % 计算一些从原始参数推导出来的量
phase = localBuildPhaseMaps(grid, params, derived); % 构造所有相位分量以及总相位

inputEnvelope = params.beam.fieldAmplitude * exp(-(grid.r .^ 2) / params.beam.waistRadiusMm ^ 2); % 构造高斯振幅包络
inputField = inputEnvelope .* exp(1i * phase.all); % 把总相位乘到高斯包络上，得到输入复振幅场
[apertureMask, apertureEnabled] = localBuildApertureMask(grid, params.phase.apertureRadiusMm);
incidentPowerSamples = sum(abs(inputField) .^ 2, 'all');
if apertureEnabled
    inputField = inputField .* apertureMask;
    apertureTransmission = sum(abs(inputField) .^ 2, 'all') / incidentPowerSamples;
else
    apertureTransmission = 1;
end
if ~isfinite(apertureTransmission) || apertureTransmission <= 0
    error('The aperture blocks all sampled input power. Increase apertureRadiusMm or simulation.N.');
end
apertureTransmission = min(apertureTransmission, 1);
angularSpectrum = fftshift(fft2(inputField)); % 对输入场做二维傅里叶变换，得到角谱

propagation = localRunBpmPropagation(inputField, grid, params, derived); % 用 FFT-BPM 做 z 方向传播
postprocess = localComputePostprocess(propagation.E3D, propagation.zValuesMm, ...
    grid, params, derived, apertureTransmission); % 对传播结果做功率密度等后处理

results = struct(); % 新建结果结构体
results.params = params; % 保存完整参数，便于后面绘图/导出统一调用
results.grid = grid; % 保存网格信息
results.derived = derived; % 保存派生量
results.phase = phase; % 保存所有相位分量
results.inputEnvelope = inputEnvelope; % 保存输入光束包络
results.inputField = inputField; % 保存输入复场
results.angularSpectrum = angularSpectrum; % 保存输入场角谱
results.aperture = struct( ...
    'enabled', apertureEnabled, ...
    'radiusMm', params.phase.apertureRadiusMm, ...
    'mask', apertureMask, ...
    'transmission', apertureTransmission, ...
    'incidentAveragePowerW', params.laser.powerW, ...
    'transmittedAveragePowerW', params.laser.powerW * apertureTransmission, ...
    'incidentPulsePeakPowerW', derived.pulsePeakPowerW, ...
    'transmittedPulsePeakPowerW', derived.pulsePeakPowerW * apertureTransmission);
results.propagation = propagation; % 保存传播结果
results.postprocess = postprocess; % 保存后处理结果
end

function [apertureMask, apertureEnabled] = localBuildApertureMask(grid, apertureRadiusMm)
if ~isnumeric(apertureRadiusMm) || ~isscalar(apertureRadiusMm) || ...
        ~isfinite(apertureRadiusMm) || apertureRadiusMm < 0
    error('params.phase.apertureRadiusMm must be a finite nonnegative scalar number.');
end

apertureEnabled = apertureRadiusMm > 0;
if apertureEnabled
    apertureMask = grid.r <= apertureRadiusMm;
    if ~any(apertureMask, 'all')
        error('The aperture does not include any grid samples. Increase apertureRadiusMm or simulation.N.');
    end
else
    apertureMask = true(size(grid.r));
end
end

function grid = localSetupGrid(simulation)
% localSetupGrid
% 作用：建立实空间坐标、频空间坐标，以及 z 方向采样位置。

grid = struct(); % 新建网格结构体
grid.N = simulation.N; % 保存横向采样点数
grid.sizeMm = simulation.sizeMm; % 保存横向物理尺寸
grid.dxMm = simulation.sizeMm / simulation.N; % x 方向单个像素的物理大小
grid.dyMm = grid.dxMm; % y 方向与 x 方向保持相同采样间距

spatialSampleIndices = (1:simulation.N) - simulation.N / 2; % 与 SLM phase 生成器一致的实空间像素中心定义
grid.xValuesMm = spatialSampleIndices * grid.dxMm; % x 坐标轴，间距严格等于 dxMm
grid.yValuesMm = grid.xValuesMm; % y 坐标轴，当前使用方形采样窗口
[grid.x, grid.y] = meshgrid(grid.xValuesMm, grid.yValuesMm); % 在 x-y 平面上建立二维网格坐标
[grid.theta, grid.r] = cart2pol(grid.x, grid.y); % 把笛卡尔坐标转成极坐标，便于构造涡旋/axicon 等相位

grid.fSizeInvMm = simulation.N / simulation.sizeMm; % 频域总尺寸，单位 mm^-1
grid.dfxInvMm = 1 / simulation.sizeMm; % 频域像素间距，单位 mm^-1
grid.dfyInvMm = grid.dfxInvMm; % y 方向频域采样间距与 x 一样
frequencySampleIndices = -floor(simulation.N / 2):(ceil(simulation.N / 2) - 1); % 与 fftshift(fft2(...)) 排列一致的频率索引
frequencyValuesInvMm = frequencySampleIndices * grid.dfxInvMm; % 与 fftshift(fft2(...)) 排列一致的频率坐标
grid.fxValuesInvMm = frequencyValuesInvMm; % 保存一维 fx 坐标
grid.fyValuesInvMm = frequencyValuesInvMm; % 保存一维 fy 坐标
[grid.fx, grid.fy] = meshgrid(grid.fxValuesInvMm, grid.fyValuesInvMm); % 建立频域平面的二维网格
grid.kx = 2 * pi * grid.fx; % 把空间频率转换成横向波矢分量 kx
grid.ky = 2 * pi * grid.fy; % 把空间频率转换成横向波矢分量 ky
grid.zValuesMm = 0:simulation.dzMm:simulation.zRangeMm; % 生成所有 z 方向传播位置
end

function derived = localBuildDerivedQuantities(params)
% localBuildDerivedQuantities
% 作用：把那些能从原始参数直接推出来的量统一预先算好，
% 避免后面在多个函数里重复写同样的公式。

derived = struct(); % 新建派生量结构体

derived.kBackground = 2 * pi * params.material.backgroundIndex / params.laser.wavelengthMm; % 背景介质中的总波数 k
derived.kSample = 2 * pi * params.material.sampleIndex / params.laser.wavelengthMm; % 样品中的总波数 k_m
derived.pulseEnergyJ = params.laser.powerW / params.laser.repetitionRateHz; % 单脉冲能量 = 平均功率 / 重复频率
derived.pulsePeakPowerW = derived.pulseEnergyJ / params.laser.pulseWidthS; % 峰值功率 = 单脉冲能量 / 脉宽
derived.axicon = localResolveAxiconDefinition(params, derived.kBackground); % 把不同 axicon 输入模式统一解析成 kr 和有效锥角 beta
derived.axicon.geometry = char(string(params.phase.axiconGeometry));
derived.axicon.orientationDeg = params.phase.axiconOrientationDeg;

derived.optics = struct(); % 新建一个 optics 子结构体，用来存和透镜系统有关的派生量
derived.optics.alphaRad = derived.axicon.physicalBaseAngleRad; % 兼容旧字段名：真实 axicon 底角 alpha
derived.optics.M = params.optics.lens2FocalLengthMm / params.optics.lens1FocalLengthMm; % 两片透镜组成的缩放倍率 M=f2/f1
derived.optics.M2 = derived.optics.M ^ 2; % 缩放倍率平方 M2，用于材料内长度缩放
derived.optics.magnification = derived.optics.M; % 兼容旧字段名
derived.optics.beta0Rad = derived.axicon.coneAngleRad; % beta_0 现在表示全息 axicon 的有效出射锥角
derived.optics.beta0Deg = rad2deg(derived.optics.beta0Rad); % 把 beta_0 转成角度方便查看
derived.optics.beta1Rad = atan(tan(derived.optics.beta0Rad) * params.optics.lens1FocalLengthMm / params.optics.lens2FocalLengthMm); % 原脚本中的 beta_1
derived.optics.beta1Deg = rad2deg(derived.optics.beta1Rad); % 把 beta_1 转成角度
betaMaterialArgument = (params.material.backgroundIndex / params.material.sampleIndex) * sin(derived.optics.beta1Rad); % Snell 定律里的 asin 自变量
if abs(betaMaterialArgument) > 1
    error('Effective material cone angle is invalid because asin argument is %.12g.', betaMaterialArgument);
end
derived.optics.betaMaterialRad = asin(betaMaterialArgument); % 入射到样品后对应的折射角
derived.optics.betaMaterialDeg = rad2deg(derived.optics.betaMaterialRad); % 折射角的角度形式
derived.optics.zFocusMm = params.beam.waistRadiusMm / (2 * tan(derived.optics.beta0Rad)); % 原脚本中的 z_f
derived.optics.deltaZMm = 0.8 * 2 * derived.optics.zFocusMm; % 原脚本中的 delta_z
derived.optics.deltaZMaterialMm = derived.optics.M2 * derived.optics.deltaZMm; % 原脚本中的 delta_zm
derived.optics.lens1PositionMm = params.optics.lens1PositionMm; % 第一片透镜位置
derived.optics.lens2PositionMm = params.optics.lens2PositionMm; % 第二片透镜位置
derived.optics.samplePositionMm = params.optics.samplePositionMm; % 样品位置
end

function axicon = localResolveAxiconDefinition(params, kBackground)
% localResolveAxiconDefinition
% 作用：把 APP/脚本里多种 axicon 定义方式统一转换成 SLM 真正使用的径向相位斜率 kr。

mode = char(string(params.phase.axiconMode)); % 当前 axicon 定义模式
validModes = {'coneAngle', 'radialPeriodMm', 'radialPeriodPx', 'radialCycles', 'physicalEquivalent'};
if ~any(strcmp(mode, validModes))
    error('params.phase.axiconMode must be coneAngle, radialPeriodMm, radialPeriodPx, radialCycles, or physicalEquivalent.');
end

gridPixelPitchMm = params.simulation.sizeMm / params.simulation.N; % 当前输出相位矩阵的像素间距，单位 mm/pixel
gridRadiusMm = params.simulation.sizeMm / 2; % axiconRadialCycles 中 rho=1 对应的真实半径
physicalBaseAngleRad = deg2rad(params.phase.axiconAngleDeg); % 真实 axicon 等效模式使用的底角 alpha

switch mode
    case 'coneAngle'
        coneAngleRad = deg2rad(params.phase.axiconConeAngleDeg);
        krRadPerMm = kBackground * sin(coneAngleRad);
    case 'radialPeriodMm'
        radialPeriodMm = params.phase.axiconRadialPeriodMm;
        if radialPeriodMm <= 0
            error('params.phase.axiconRadialPeriodMm must be positive.');
        end
        krRadPerMm = 2 * pi / radialPeriodMm;
        sinConeAngle = krRadPerMm / kBackground;
        if sinConeAngle <= 0 || sinConeAngle >= 1
            error('params.phase.axiconRadialPeriodMm is too small for the current wavelength/background index.');
        end
        coneAngleRad = asin(sinConeAngle);
    case 'radialPeriodPx'
        radialPeriodPx = params.phase.axiconRadialPeriodPx;
        if radialPeriodPx <= 0
            error('params.phase.axiconRadialPeriodPx must be positive.');
        end
        radialPeriodMm = radialPeriodPx * gridPixelPitchMm;
        krRadPerMm = 2 * pi / radialPeriodMm;
        sinConeAngle = krRadPerMm / kBackground;
        if sinConeAngle <= 0 || sinConeAngle >= 1
            error('params.phase.axiconRadialPeriodPx is too small for the current wavelength/background index.');
        end
        coneAngleRad = asin(sinConeAngle);
    case 'radialCycles'
        radialCycles = params.phase.axiconRadialCycles;
        if ~isfinite(radialCycles) || radialCycles <= 0
            error('params.phase.axiconRadialCycles must be a positive finite number.');
        end
        krRadPerMm = 2 * pi * radialCycles / gridRadiusMm;
        sinConeAngle = krRadPerMm / kBackground;
        if sinConeAngle <= 0 || sinConeAngle >= 1
            error('params.phase.axiconRadialCycles is too large for the current wavelength/background index/window size.');
        end
        coneAngleRad = asin(sinConeAngle);
    case 'physicalEquivalent'
        if params.phase.axiconIndex <= 0 || params.material.backgroundIndex <= 0
            error('Axicon and background refractive indices must be positive.');
        end
        snellArgument = (params.phase.axiconIndex / params.material.backgroundIndex) * sin(physicalBaseAngleRad);
        if abs(snellArgument) > 1
            error('Physical-equivalent axicon is invalid because asin argument is %.12g.', snellArgument);
        end
        coneAngleRad = asin(snellArgument) - physicalBaseAngleRad;
        krRadPerMm = kBackground * sin(coneAngleRad);
end

if ~isfinite(coneAngleRad) || coneAngleRad <= 0 || coneAngleRad >= pi / 2
    error('Resolved axicon cone angle must be between 0 and 90 degrees.');
end
if ~isfinite(krRadPerMm) || krRadPerMm <= 0 || krRadPerMm >= kBackground
    error('Resolved axicon radial wavevector must be positive and smaller than the background wave number.');
end

axicon = struct(); % 保存统一后的 axicon 派生量
axicon.mode = mode;
axicon.krRadPerMm = krRadPerMm;
axicon.radialPhaseSlopeRadPerMm = krRadPerMm;
axicon.coneAngleRad = coneAngleRad;
axicon.coneAngleDeg = rad2deg(coneAngleRad);
axicon.radialPeriodMm = 2 * pi / krRadPerMm;
axicon.radialPeriodPx = axicon.radialPeriodMm / gridPixelPitchMm;
axicon.radialCycles = krRadPerMm * gridRadiusMm / (2 * pi);
axicon.gridPixelPitchMm = gridPixelPitchMm;
axicon.physicalIndex = params.phase.axiconIndex;
axicon.physicalBaseAngleRad = physicalBaseAngleRad;
axicon.physicalBaseAngleDeg = params.phase.axiconAngleDeg;
end

function krRadPerMm = localConeAngleDegToKr(betaDeg, kBackground, paramName)
if ~isnumeric(betaDeg) || ~isscalar(betaDeg) || ~isfinite(betaDeg) || abs(betaDeg) >= 90
    error('%s must be finite and between -90 and 90 degrees.', paramName);
end

krRadPerMm = kBackground * sin(deg2rad(betaDeg));
if ~isfinite(krRadPerMm) || abs(krRadPerMm) >= kBackground
    error('%s resolves to an invalid radial wavevector.', paramName);
end
end

function phaseMap = localBuildBesselVortexPhase(grid, kBackground, betaDeg, vortexCharge, betaParamName)
if ~isnumeric(vortexCharge) || ~isscalar(vortexCharge) || ~isfinite(vortexCharge)
    error('Checkerboard Bessel vortex topological charge must be a finite scalar number.');
end

krRadPerMm = localConeAngleDegToKr(betaDeg, kBackground, betaParamName);
phaseMap = krRadPerMm * (grid.sizeMm / 2 - grid.r) + vortexCharge * grid.theta;
end

function mask = localBuildCheckerboardMask(sampleCount, tileSizePx)
if ~isnumeric(tileSizePx) || ~isscalar(tileSizePx) || ~isfinite(tileSizePx) || tileSizePx < 1
    error('params.phase.checkerboardTileSizePx must be a positive integer.');
end

tileSizePx = round(tileSizePx);
[rowIndices, columnIndices] = ndgrid(1:sampleCount, 1:sampleCount);
rowTile = floor((rowIndices - 1) / tileSizePx);
columnTile = floor((columnIndices - 1) / tileSizePx);
mask = mod(rowTile + columnTile, 2) == 0;
end

function phaseMap = localBuildAxiconPhase(grid, params, derived)
geometry = char(string(params.phase.axiconGeometry));
orientationDeg = params.phase.axiconOrientationDeg;
if ~isnumeric(orientationDeg) || ~isscalar(orientationDeg) || ~isfinite(orientationDeg)
    error('params.phase.axiconOrientationDeg must be a finite scalar number.');
end

switch geometry
    case 'circular'
        phaseCoordinateMm = grid.r;
    case 'linear1D'
        orientationRad = deg2rad(orientationDeg);
        normalCoordinateMm = grid.x .* cos(orientationRad) + grid.y .* sin(orientationRad);
        phaseCoordinateMm = abs(normalCoordinateMm);
    otherwise
        error('params.phase.axiconGeometry must be circular or linear1D.');
end

phaseMap = derived.axicon.krRadPerMm * (grid.sizeMm / 2 - phaseCoordinateMm);
end

function phase = localBuildPhaseMaps(grid, params, derived)
% localBuildPhaseMaps
% 作用：计算所有相位分量，包括：
% Airy 相位、axicon 相位、曲线 Bessel 相位、补偿相位、vortex 相位、helical 相位，
% 最后再把它们相加得到总相位。

phase = struct(); % 新建相位结构体

phase.airy = params.phase.airyStrength * ((grid.x ./ params.phase.airyScaleMm) .^ 3 + (grid.y ./ params.phase.airyScaleMm) .^ 3); % Airy 三次相位
phase.axicon = localBuildAxiconPhase(grid, params, derived);

if strcmp(derived.axicon.geometry, 'linear1D') && ...
        (params.phase.curvedMaxShiftXMm ~= 0 || params.phase.curvedMaxShiftYMm ~= 0)
    error('curvedMaxShiftXMm/curvedMaxShiftYMm are not supported with linear1D axicon geometry.');
end

tanConeAngle = tan(derived.axicon.coneAngleRad);
if tanConeAngle == 0
    if params.phase.curvedMaxShiftXMm ~= 0 || params.phase.curvedMaxShiftYMm ~= 0
        error('curvedMaxShiftXMm/curvedMaxShiftYMm require nonzero axicon beta because the curved-Bessel phase formula degenerates at beta = 0.');
    end
    phase.maxPropagationMm = Inf;
    phase.curvatureAX = 0;
    phase.curvatureAY = 0;
    phase.curve = zeros(size(grid.r));
else
    phase.maxPropagationMm = (grid.sizeMm / 2) / abs(tanConeAngle); % 几何近似下的最大无衍射传播距离
    phase.curvatureAX = params.phase.curvedMaxShiftXMm / (phase.maxPropagationMm ^ 2); % 抛物线轨迹 x = A_x z^2 中的曲率系数
    phase.curvatureAY = params.phase.curvedMaxShiftYMm / (phase.maxPropagationMm ^ 2); % 抛物线轨迹 y = A_y z^2 中的曲率系数
    phase.curve = derived.kBackground * (grid.r ./ abs(tanConeAngle)) .* ...
        (phase.curvatureAX .* grid.x + phase.curvatureAY .* grid.y); % 让 Bessel 轨迹发生二维横向弯曲的相位项
end

phase.compensation = params.phase.compensationPhase; % 保留额外补偿相位接口
phase.vortex = params.phase.vortexCharge * grid.theta; % 标准涡旋相位 l*theta
phase.checkerboardMask = false(size(grid.r));
phase.checkerboardBessel1 = zeros(size(grid.r));
phase.checkerboardBessel2 = zeros(size(grid.r));
phase.checkerboardBessel = zeros(size(grid.r));
if params.phase.checkerboardBesselEnabled
    phase.checkerboardMask = localBuildCheckerboardMask(grid.N, params.phase.checkerboardTileSizePx);
    phase.checkerboardBessel1 = localBuildBesselVortexPhase( ...
        grid, derived.kBackground, params.phase.checkerboardBeta1Deg, ...
        params.phase.checkerboardTc1, 'params.phase.checkerboardBeta1Deg');
    phase.checkerboardBessel2 = localBuildBesselVortexPhase( ...
        grid, derived.kBackground, params.phase.checkerboardBeta2Deg, ...
        params.phase.checkerboardTc2, 'params.phase.checkerboardBeta2Deg');
    phase.checkerboardBessel = phase.checkerboardBessel2;
    phase.checkerboardBessel(phase.checkerboardMask) = ...
        phase.checkerboardBessel1(phase.checkerboardMask);
end

phase.rho = grid.r ./ (grid.sizeMm / 2); % 归一化半径 rho，方便定义径向 chirp
phase.radialChirp = 2 * pi * ( ... % 径向 chirp 相位，形式上是关于 rho 的二次函数
    params.phase.omegaInner .* phase.rho + ... % 中心频率项
    0.5 * (params.phase.omegaOuter - params.phase.omegaInner) .* phase.rho .^ 2); % 频率从中心到边缘逐渐变化的项

phase.helicalPhaseOffsetRad = deg2rad(params.phase.helicalPhaseOffset); % helicalPhaseOffset 由用户按“度”输入，这里统一转成弧度用于三角函数
phase.helical = params.phase.helicalGamma * cos( ... % helical 相位项，本质上是一个角向-径向耦合调制
    params.phase.helicalOrder * grid.theta - ... % 角向周期由 m 决定
    phase.radialChirp + ... % 径向 chirp 决定半径方向的周期变化
    phase.helicalPhaseOffsetRad); % 整体初相位偏移

phase.all = phase.axicon + phase.airy + phase.vortex + phase.checkerboardBessel + phase.helical + phase.compensation + phase.curve; % 最终总相位
end

function propagation = localRunBpmPropagation(inputField, grid, params, derived)
% localRunBpmPropagation
% 作用：用 FFT-BPM 方法，把输入场沿 z 方向一步一步传播。
% 如果启用了 lens1 / lens2 / sample，就在对应 z 位置把它们插入传播链。

propagation = struct(); % 新建传播结果结构体

if ~params.simulation.useBPM % 如果用户关闭了 BPM
    message = sprintf('BPM OFF: z propagation was skipped. M=%.12g, M2=%.12g', derived.optics.M, derived.optics.M2); % 记录本次透镜缩放倍率
    localProgressWrite(params, message, true); % 打印/记录一条状态信息；使用 ASCII 避免 VS Code 终端乱码
    propagation.E3D = reshape(inputField, size(inputField, 1), size(inputField, 2), 1); % 仍然保存成 N x N x 1，保证后处理函数按三维栈读取
    propagation.finalField = inputField; % 最终场也等于输入场
    propagation.zValuesMm = 0; % z 方向只保留 0 这一个位置
    propagation.lens1AppliedAtMm = NaN; % 没有真正加入第一片透镜
    propagation.lens2AppliedAtMm = NaN; % 没有真正加入第二片透镜
    propagation.sampleAppliedAtMm = NaN; % 没有真正切换到样品
    return; % 提前结束函数
end

zValuesMm = grid.zValuesMm; % 取出所有 z 方向传播位置
currentField = inputField; % 直接在 CPU 上计算
kx = grid.kx; % 使用 CPU 版 kx
ky = grid.ky; % 使用 CPU 版 ky
radius = grid.r; % 使用 CPU 版 r

backgroundPropagationKernel = exp(1i * params.simulation.dzMm * sqrt(derived.kBackground ^ 2 - kx .^ 2 - ky .^ 2)); % 背景介质中的单步传播算子
samplePropagationKernel = exp(1i * params.simulation.dzMm * sqrt(derived.kSample ^ 2 - kx .^ 2 - ky .^ 2)); % 样品介质中的单步传播算子
propagationKernel = backgroundPropagationKernel; % 当前传播区间使用的传播算子；到达样品后切换
lens1Phase = exp(-1i * derived.kBackground / (2 * params.optics.lens1FocalLengthMm) * radius .^ 2); % 第一片透镜的二次相位
lens2Phase = exp(-1i * derived.kBackground / (2 * params.optics.lens2FocalLengthMm) * radius .^ 2); % 第二片透镜的二次相位

fieldStack = zeros(grid.N, grid.N, numel(zValuesMm), 'like', currentField); % 预分配三维场数组，避免循环中反复扩容
lens1AppliedAtMm = NaN; % 记录第一片透镜到底在哪个 z 步被真正插入
lens2AppliedAtMm = NaN; % 记录第二片透镜真正插入的位置
sampleAppliedAtMm = NaN; % 记录样品折射率真正开始生效的位置
progressTimer = tic; % 为 BPM 主循环单独计时
localProgressStart(params, numel(zValuesMm), derived); % 打印/记录 BPM 开始运行的信息
lastProgressTimeSeconds = -inf; % 记录上一次输出进度的时间；初值设为 -inf 保证第一步会输出

initialZValueMm = zValuesMm(1); % 第一个切片是真正的输入平面 z=0
if params.optics.lens1Enabled && isnan(lens1AppliedAtMm) && initialZValueMm >= derived.optics.lens1PositionMm
    currentField = currentField .* lens1Phase;
    lens1AppliedAtMm = initialZValueMm;
end
if params.optics.lens2Enabled && isnan(lens2AppliedAtMm) && initialZValueMm >= derived.optics.lens2PositionMm
    currentField = currentField .* lens2Phase;
    lens2AppliedAtMm = initialZValueMm;
end
if params.optics.sampleEnabled && isnan(sampleAppliedAtMm) && initialZValueMm >= derived.optics.samplePositionMm
    propagationKernel = samplePropagationKernel;
    sampleAppliedAtMm = initialZValueMm;
end
fieldStack(:, :, 1) = currentField; % 保存 z=0 输入场，避免整条 z 轴被错标一个 dz
[lastProgressTimeSeconds, ~] = localProgressUpdate(params, 1, numel(zValuesMm), initialZValueMm, progressTimer, lastProgressTimeSeconds);

for index = 2:numel(zValuesMm) % 逐个 z 切片推进
    zValueMm = zValuesMm(index); % 当前这一步对应的 z 位置

    stepSpectrum = fftshift(fft2(currentField)); % 先把当前场变换到频域
    currentField = ifft2(ifftshift(stepSpectrum .* propagationKernel)); % 乘单步传播算子后再变回空间域

    if params.optics.lens1Enabled && isnan(lens1AppliedAtMm) && zValueMm >= derived.optics.lens1PositionMm % 如果第一片透镜已启用且还没加入且当前 z 到达其位置
        currentField = currentField .* lens1Phase; % 把第一片透镜相位乘到当前场上
        lens1AppliedAtMm = zValueMm; % 记录加入透镜的实际 z 位置
    end

    if params.optics.lens2Enabled && isnan(lens2AppliedAtMm) && zValueMm >= derived.optics.lens2PositionMm % 如果第二片透镜已启用且还没加入且当前 z 到达其位置
        currentField = currentField .* lens2Phase; % 把第二片透镜相位乘到当前场上
        lens2AppliedAtMm = zValueMm; % 记录加入第二片透镜的实际位置
    end

    if params.optics.sampleEnabled && isnan(sampleAppliedAtMm) && zValueMm >= derived.optics.samplePositionMm % 如果样品已启用且还没切换且当前 z 到达样品位置
        propagationKernel = samplePropagationKernel; % 把传播算子切换成样品介质中的版本，从下一段传播开始生效
        sampleAppliedAtMm = zValueMm; % 记录样品开始生效的位置
    end

    fieldStack(:, :, index) = currentField; % 把这一步传播后的场存入三维数组
    [lastProgressTimeSeconds, ~] = localProgressUpdate(params, index, numel(zValuesMm), zValueMm, progressTimer, lastProgressTimeSeconds); % 按时间间隔打印/记录当前进度
end

localProgressFinish(params, numel(zValuesMm), toc(progressTimer), derived); % 打印/记录 BPM 结束信息

propagation.E3D = fieldStack; % 保存三维传播场
propagation.finalField = currentField; % 同时保存最终 z 面上的场
propagation.zValuesMm = zValuesMm; % 保存 z 位置序列
propagation.lens1AppliedAtMm = lens1AppliedAtMm; % 保存第一片透镜的实际插入位置
propagation.lens2AppliedAtMm = lens2AppliedAtMm; % 保存第二片透镜的实际插入位置
propagation.sampleAppliedAtMm = sampleAppliedAtMm; % 保存样品开始生效的位置
end

function postprocess = localComputePostprocess(fieldStack, zValuesMm, grid, params, derived, apertureTransmission)
% localComputePostprocess
% 作用：从三维复场中提取强度、功率密度、轴上曲线、对数图等后处理结果。
% 注意：这里的功率密度标定仍然沿用了旧代码的“参考切片归一化”思路，
% 它更适合作为相对比较和参考，不建议直接把它当作严格实验绝对值。

postprocess = struct(); % 新建后处理结果结构体

if ~isnumeric(apertureTransmission) || ~isscalar(apertureTransmission) || ...
        ~isfinite(apertureTransmission) || apertureTransmission <= 0 || apertureTransmission > 1 + 1e-12
    error('apertureTransmission must be a finite scalar in the interval (0, 1].');
end

referenceSliceIndex = min(params.output.referenceSliceIndex, size(fieldStack, 3)); % 防止参考切片编号超过 z 切片总数
referenceSlice = abs(fieldStack(:, :, referenceSliceIndex)) .^ 2; % 取参考 z 切片的强度分布
sumIntensity = sum(referenceSlice, 'all'); % 求参考切片上的总强度
if sumIntensity <= 0 || ~isfinite(sumIntensity)
    error('Reference slice has zero or invalid total intensity.');
end
pixelAreaMm2 = grid.dxMm * grid.dyMm; % 每个像素对应的物理面积，单位 mm^2
pixelPowerW = apertureTransmission / sumIntensity; % 以1 W 孔径前入射功率为基准，保留被孔径挡掉的功率损耗
pixelPowerDensityWPerMm2 = pixelPowerW / pixelAreaMm2; % 把单像素功率换成功率密度，单位 W/mm^2
thresholdWPerMm2 = params.material.damageThresholdWPerM2 / 1e6; % 把材料阈值从 W/m^2 转成 W/mm^2；当前默认值对应 7.2e11 W/mm^2

[~, centerRowIndex] = min(abs(grid.yValuesMm)); % SLM 坐标约定下取最靠近 y=0 的采样线
[~, centerColumnIndex] = min(abs(grid.xValuesMm)); % SLM 坐标约定下取最靠近 x=0 的采样线
yImageMm = grid.yValuesMm; % y 方向显示坐标，与传播网格保持一致
zImageMm = reshape(zValuesMm, 1, []); % z 方向显示坐标直接使用传播过程中的真实采样位置
crossSectionIntensity = reshape(abs(fieldStack(:, centerColumnIndex, :)) .^ 2, params.simulation.N, []); % 固定 x=0，提取 y-z 中心截面
crossSectionPowerDensity = crossSectionIntensity .* pixelPowerDensityWPerMm2; % 把二维强度图换成功率密度图
crossSectionPeakPowerDensity = crossSectionPowerDensity * derived.pulsePeakPowerW; % 再乘峰值功率，得到峰值功率密度估算
onAxisPeakPowerDensity = crossSectionPeakPowerDensity(centerRowIndex, :); % 再取中心 y 位置，得到轴上峰值功率密度曲线

[normalCrossSectionIntensity, tangentCrossSectionIntensity, normalCoordinateMm, tangentCoordinateMm] = ...
    localExtractAxiconCrossSections(fieldStack, grid, params, centerRowIndex, centerColumnIndex);
normalCrossSectionPowerDensity = normalCrossSectionIntensity .* pixelPowerDensityWPerMm2;
normalCrossSectionPeakPowerDensity = normalCrossSectionPowerDensity * derived.pulsePeakPowerW;
tangentCrossSectionPowerDensity = tangentCrossSectionIntensity .* pixelPowerDensityWPerMm2;
tangentCrossSectionPeakPowerDensity = tangentCrossSectionPowerDensity * derived.pulsePeakPowerW;

slicePeakIntensity = zeros(1, size(fieldStack, 3)); % 每个 z 平面内真正的峰值强度，用于和 on-axis 曲线区分
for sliceIndex = 1:size(fieldStack, 3)
    currentIntensity = abs(fieldStack(:, :, sliceIndex)) .^ 2;
    slicePeakIntensity(sliceIndex) = max(currentIntensity(:));
end
slicePeakPowerDensity = slicePeakIntensity .* pixelPowerDensityWPerMm2 * derived.pulsePeakPowerW;
[onAxisMaxPeakPowerDensity, onAxisMaxIndex] = max(onAxisPeakPowerDensity);
[sliceMaxPeakPowerDensity, sliceMaxIndex] = max(slicePeakPowerDensity);

postprocess.referenceSliceIndex = referenceSliceIndex; % 保存参考切片编号
postprocess.apertureTransmission = apertureTransmission; % 保存孔径后/孔径前的功率比
postprocess.incidentAveragePowerW = params.laser.powerW; % 孔径前的入射平均功率
postprocess.transmittedAveragePowerW = params.laser.powerW * apertureTransmission; % 孔径后的平均功率
postprocess.incidentPulsePeakPowerW = derived.pulsePeakPowerW; % 孔径前的脉冲峰值功率
postprocess.transmittedPulsePeakPowerW = derived.pulsePeakPowerW * apertureTransmission; % 孔径后的脉冲峰值功率
postprocess.pixelPowerW = pixelPowerW; % 保存单强度单位对应的功率
postprocess.pixelAreaMm2 = pixelAreaMm2; % 保存像素物理面积
postprocess.pixelPowerDensityWPerMm2 = pixelPowerDensityWPerMm2; % 保存单强度单位对应的功率密度
postprocess.thresholdWPerM2 = params.material.damageThresholdWPerM2; % 保存原始单位下的材料阈值
postprocess.thresholdWPerMm2 = thresholdWPerMm2; % 保存换算后的材料阈值
postprocess.unitAssumptions = [ ... % 保存一段文字说明，提醒这套单位处理的假设是什么
    'laser.powerW is the incident power before the aperture. Reference-slice scaling preserves aperture transmission. ', ...
    'Peak power-density plots are reported in W/mm^2. Material threshold is provided in W/m^2 and converted for plotting.']; % 第二句说明画图时单位怎么处理
postprocess.midSliceIndex = centerRowIndex; % 兼容旧字段名：保存中心 y 索引
postprocess.centerRowIndex = centerRowIndex; % 保存中心 y 索引
postprocess.centerColumnIndex = centerColumnIndex; % 保存中心 x 索引
postprocess.centerXMm = grid.xValuesMm(centerColumnIndex); % 保存中心 x 坐标，便于确认 on-axis 采样点
postprocess.centerYMm = grid.yValuesMm(centerRowIndex); % 保存中心 y 坐标，便于确认 on-axis 采样点
postprocess.yImageMm = yImageMm; % 保存 y 方向绘图坐标
postprocess.zImageMm = zImageMm; % 保存 z 方向绘图坐标
postprocess.crossSectionIntensity = crossSectionIntensity; % 保存中心截面强度图
postprocess.crossSectionPowerDensityWPerMm2 = crossSectionPowerDensity; % 保存中心截面功率密度图
postprocess.crossSectionPeakPowerDensityWPerMm2 = crossSectionPeakPowerDensity; % 保存中心截面峰值功率密度图
postprocess.crossSectionIntensityLog = log(1 + crossSectionIntensity); % 保存强度的对数显示版本
postprocess.crossSectionPeakPowerDensityLog = log(1 + crossSectionPeakPowerDensity); % 保存峰值功率密度的对数显示版本
postprocess.normalCoordinateMm = normalCoordinateMm;
postprocess.tangentCoordinateMm = tangentCoordinateMm;
postprocess.normalCrossSectionIntensity = normalCrossSectionIntensity;
postprocess.normalCrossSectionPowerDensityWPerMm2 = normalCrossSectionPowerDensity;
postprocess.normalCrossSectionPeakPowerDensityWPerMm2 = normalCrossSectionPeakPowerDensity;
postprocess.normalCrossSectionPeakPowerDensityLog = log(1 + normalCrossSectionPeakPowerDensity);
postprocess.tangentCrossSectionIntensity = tangentCrossSectionIntensity;
postprocess.tangentCrossSectionPowerDensityWPerMm2 = tangentCrossSectionPowerDensity;
postprocess.tangentCrossSectionPeakPowerDensityWPerMm2 = tangentCrossSectionPeakPowerDensity;
postprocess.tangentCrossSectionPeakPowerDensityLog = log(1 + tangentCrossSectionPeakPowerDensity);
postprocess.onAxisPeakPowerDensityWPerMm2 = onAxisPeakPowerDensity; % 保存轴上峰值功率密度曲线
postprocess.slicePeakPowerDensityWPerMm2 = slicePeakPowerDensity; % 保存每个 z 平面内的真实峰值功率密度
postprocess.onAxisMaxPeakPowerDensityWPerMm2 = onAxisMaxPeakPowerDensity; % 保存轴上最大值
postprocess.onAxisMaxZMm = zImageMm(onAxisMaxIndex); % 保存轴上最大值位置
postprocess.sliceMaxPeakPowerDensityWPerMm2 = sliceMaxPeakPowerDensity; % 保存全平面峰值的最大值
postprocess.sliceMaxZMm = zImageMm(sliceMaxIndex); % 保存全平面峰值最大值位置
end

function [normalSection, tangentSection, normalCoordinateMm, tangentCoordinateMm] = ...
        localExtractAxiconCrossSections(fieldStack, grid, params, centerRowIndex, centerColumnIndex)
normalCoordinateMm = grid.xValuesMm;
tangentCoordinateMm = grid.yValuesMm;
geometry = char(string(params.phase.axiconGeometry));

if strcmp(geometry, 'circular')
    normalSection = reshape(abs(fieldStack(centerRowIndex, :, :)) .^ 2, grid.N, []);
    tangentSection = reshape(abs(fieldStack(:, centerColumnIndex, :)) .^ 2, grid.N, []);
    return;
end
if ~strcmp(geometry, 'linear1D')
    error('params.phase.axiconGeometry must be circular or linear1D.');
end

orientationRad = deg2rad(params.phase.axiconOrientationDeg);
normalX = normalCoordinateMm .* cos(orientationRad);
normalY = normalCoordinateMm .* sin(orientationRad);
tangentX = -tangentCoordinateMm .* sin(orientationRad);
tangentY = tangentCoordinateMm .* cos(orientationRad);
normalSection = zeros(grid.N, size(fieldStack, 3));
tangentSection = zeros(grid.N, size(fieldStack, 3));
for sliceIndex = 1:size(fieldStack, 3)
    currentIntensity = abs(fieldStack(:, :, sliceIndex)) .^ 2;
    normalSection(:, sliceIndex) = interp2( ...
        grid.xValuesMm, grid.yValuesMm, currentIntensity, normalX, normalY, 'linear', 0).';
    tangentSection(:, sliceIndex) = interp2( ...
        grid.xValuesMm, grid.yValuesMm, currentIntensity, tangentX, tangentY, 'linear', 0).';
end
end

function localPlotResults(results, params)
% localPlotResults
% 作用：把最常用的结果画成两张图：
% figure(1) 主要看输入场和相位；
% figure(2) 主要看传播剖面和轴上峰值功率密度。

figure(1); % 新建第一张图窗
clf('reset'); % 清掉上一轮图里的隐藏辅助线和色条
tiledlayout(2, 4, 'Padding', 'none', 'TileSpacing', 'compact'); % 用 2x4 的紧凑布局排版

nexttile; % 切到第 1 个子图
imshow(angle(results.inputField), []); % 显示输入复场的相位
title('Phase on SLM (angle(E))'); % 图标题
localApplyValueColorbar(gca, angle(results.inputField), 'wrappedPhase'); % 显示带数值的颜色条

nexttile; % 切到第 2 个子图
imshow(abs(results.inputField) .^ 2, []); % 显示输入场强度
title('input beam (|E|^2)'); % 图标题
localApplyValueColorbar(gca, abs(results.inputField) .^ 2, 'auto'); % 显示带数值的颜色条

nexttile; % 切到第 3 个子图
imshow(abs(results.angularSpectrum) .^ 2, []); % 显示输入场角谱强度
title('Angular spectrum (|F|^2)'); % 图标题
localApplyValueColorbar(gca, abs(results.angularSpectrum) .^ 2, 'auto'); % 显示带数值的颜色条

nexttile; % 切到第 4 个子图
imshow(angle(exp(1i * results.phase.checkerboardBessel)), []); % 显示棋盘 Bessel vortex 相位
title('phase checker Bessel'); % 图标题
localApplyValueColorbar(gca, angle(exp(1i * results.phase.checkerboardBessel)), 'wrappedPhase'); % 显示带数值的颜色条

nexttile; % 切到第 5 个子图
imshow(results.phase.helical, []); % 显示 helical 相位本体
title('phase helical'); % 图标题
localApplyValueColorbar(gca, results.phase.helical, 'auto'); % 显示带数值的颜色条

nexttile; % 切到第 6 个子图
imshow(angle(exp(1i * results.phase.axicon)), []); % 显示 axicon 相位包裹回 [-pi, pi] 之后的样子
title('phase axicon'); % 图标题
localApplyValueColorbar(gca, angle(exp(1i * results.phase.axicon)), 'wrappedPhase'); % 显示带数值的颜色条

nexttile; % 切到第 7 个子图
imshow(angle(exp(1i * results.phase.vortex)), []); % 显示 vortex 相位包裹回 [-pi, pi] 之后的样子
title('phase vortex'); % 图标题
localApplyValueColorbar(gca, angle(exp(1i * results.phase.vortex)), 'wrappedPhase'); % 显示带数值的颜色条

nexttile; % 切到第 8 个子图
imshow(results.phase.checkerboardMask, []); % 显示棋盘 mask
title('checker mask'); % 图标题
localApplyValueColorbar(gca, double(results.phase.checkerboardMask), 'mask'); % 显示带数值的颜色条

figure(2); % 新建第二张图窗
clf('reset'); % 清掉上一轮图里的隐藏辅助线和色条
tiledlayout(3, 1, 'Padding', 'none', 'TileSpacing', 'compact'); % 用 3x1 的布局依次排三个剖面图

nexttile; % 切到第 1 个子图
imagesc(results.postprocess.zImageMm, results.postprocess.yImageMm, results.postprocess.crossSectionPeakPowerDensityLog);
title('Fixed x=0 y-z peak power density log scale');
localApplyValueColorbar(gca, results.postprocess.crossSectionPeakPowerDensityLog, 'auto');
localPlotActiveMarkers(gca, results, params); % 如果启用了透镜/样品，就在图上画位置线
axis on; % 保留坐标轴
xlabel('z (mm)'); % x 轴标签
ylabel('y (mm)');

nexttile; % 切到第 2 个子图
imagesc(results.postprocess.zImageMm, results.postprocess.yImageMm, results.postprocess.crossSectionPeakPowerDensityWPerMm2);
title('Fixed x=0 y-z peak power density (W/mm^2)');
localApplyValueColorbar(gca, results.postprocess.crossSectionPeakPowerDensityWPerMm2, 'auto');
localPlotActiveMarkers(gca, results, params); % 如果启用了透镜/样品，就在图上画位置线
axis on; % 保留坐标轴
xlabel('z (mm)'); % x 轴标签
ylabel('y (mm)');

nexttile; % 切到第 3 个子图
peakPowerDensity = max([results.postprocess.onAxisPeakPowerDensityWPerMm2(:); results.postprocess.slicePeakPowerDensityWPerMm2(:)]); % 找到显示曲线的最大值，方便设坐标范围
plot(results.postprocess.zImageMm, results.postprocess.onAxisPeakPowerDensityWPerMm2, 'DisplayName', 'On-axis'); % 画轴上峰值功率密度曲线，横坐标使用真实 z 位置
hold on; % 允许在同一张图上继续叠加元素
plot(results.postprocess.zImageMm, results.postprocess.slicePeakPowerDensityWPerMm2, '--', 'DisplayName', 'Slice peak'); % 画每个 z 平面的真实峰值曲线
yline(results.postprocess.thresholdWPerMm2, 'Color', 'r', 'DisplayName', 'Threshold'); % 用红线画出材料损伤阈值参考线
xlim([min(results.postprocess.zImageMm), max(results.postprocess.zImageMm)]); % 横坐标显示真实 z 范围
ylim([0, peakPowerDensity * 1.5]); % 纵坐标从 0 到峰值的 1.5 倍
localPlotActiveMarkers(gca, results, params); % 在曲线图上也标出透镜/样品位置
localAddBlankColorbarSlot(gca); % 给曲线图预留与上面 colorbar 相同的右侧宽度，保证 z 方向对齐
xlabel('z (mm)'); % 补上横坐标标签
ylabel('Power density (W/mm^2)'); % 补上纵坐标标签
title('Estimated on-axis and slice-peak power density (W/mm^2)'); % 图标题
legend('Location', 'northeast'); % 区分轴上采样和真实切片峰值
hold off; % 关闭叠加模式
end

function localApplyValueColorbar(axHandle, data, scaleMode)
[limits, ticks, tickLabels] = localColorbarScaleSpec(data, scaleMode);
set(axHandle, 'CLim', limits);
colorbarHandle = colorbar(axHandle);
colorbarHandle.Ticks = ticks;
colorbarHandle.TickLabels = tickLabels;
colorbarHandle.Color = localColorbarTextColor(axHandle);
colorbarHandle.Box = 'on';
colorbarHandle.Label.String = '';
try
    colorbarHandle.TickLabelInterpreter = 'none';
catch
end
end

function [limits, ticks, tickLabels] = localColorbarScaleSpec(data, scaleMode)
switch char(string(scaleMode))
    case 'wrappedPhase'
        limits = [-pi, pi];
        ticks = [-pi, -pi / 2, 0, pi / 2, pi];
    case 'mask'
        limits = [0, 1];
        ticks = [0, 1];
    otherwise
        finiteValues = data(isfinite(data));
        if isempty(finiteValues)
            limits = [0, 1];
            ticks = linspace(limits(1), limits(2), 5);
        else
            minValue = min(finiteValues(:));
            maxValue = max(finiteValues(:));
            if minValue == maxValue
                padding = max(1, abs(minValue)) * 0.5;
                limits = [minValue - padding, maxValue + padding];
                ticks = minValue;
            else
                limits = [minValue, maxValue];
                ticks = linspace(limits(1), limits(2), 5);
            end
        end
end
tickLabels = localFormatColorbarTickLabels(ticks);
end

function tickLabels = localFormatColorbarTickLabels(ticks)
tickLabels = arrayfun(@localFormatColorbarValue, ticks, 'UniformOutput', false);
end

function label = localFormatColorbarValue(value)
if value == 0
    label = '0';
elseif abs(value) >= 1e4 || abs(value) < 1e-3
    label = sprintf('%.2e', value);
else
    label = sprintf('%.3f', value);
    label = regexprep(label, '(\.\d*?)0+$', '$1');
    label = regexprep(label, '\.$', '');
end
end

function textColor = localColorbarTextColor(axHandle)
textColor = [0.15, 0.15, 0.15];
try
    if isnumeric(axHandle.XColor) && numel(axHandle.XColor) == 3
        textColor = axHandle.XColor;
    end
catch
end

backgroundColor = axHandle.Color;
try
    if ~(isnumeric(backgroundColor) && numel(backgroundColor) == 3)
        figureHandle = ancestor(axHandle, 'figure');
        if ~isempty(figureHandle) && isnumeric(figureHandle.Color) && numel(figureHandle.Color) == 3
            backgroundColor = figureHandle.Color;
        else
            backgroundColor = [1, 1, 1];
        end
    end
catch
    backgroundColor = [1, 1, 1];
end

if mean(backgroundColor) < 0.35 && mean(textColor) < 0.5
    textColor = [0.86, 0.86, 0.86];
elseif mean(backgroundColor) >= 0.35 && mean(textColor) > 0.65
    textColor = [0.15, 0.15, 0.15];
end
end

function localAddBlankColorbarSlot(axHandle)
% localAddBlankColorbarSlot
% 作用：为没有色条的曲线图保留和上方剖面图一致的右侧空间，让三张图的 z 位置对齐。

slotColor = axHandle.Color;
figureHandle = ancestor(axHandle, 'figure');
if ~isempty(figureHandle) && isnumeric(figureHandle.Color) && numel(figureHandle.Color) == 3
    slotColor = figureHandle.Color;
end
if ~isnumeric(slotColor) || numel(slotColor) ~= 3
    slotColor = [1 1 1];
end

try
    colormap(axHandle, repmat(slotColor, 256, 1));
catch
end

colorbarHandle = colorbar(axHandle);
colorbarHandle.Limits = [0 1];
colorbarHandle.Ticks = linspace(0, 1, 6);
colorbarHandle.TickLabels = {'0', '2', '4', '6', '8', '10'};
colorbarHandle.Color = slotColor;
colorbarHandle.Box = 'off';
colorbarHandle.Label.String = '';
end

function localPlotActiveMarkers(axHandle, results, params)
% localPlotActiveMarkers
% 作用：如果用户真的启用了 lens1 / lens2 / sample，
% 就在剖面图上把这些元件对应的 z 位置画成竖线。

if params.optics.lens1Enabled % 如果第一片透镜启用
    localPlotOpticMarker(axHandle, results.derived.optics.lens1PositionMm, 'Lens 1', 'r'); % 画出第一片透镜位置
end

if params.optics.lens2Enabled % 如果第二片透镜启用
    localPlotOpticMarker(axHandle, results.derived.optics.lens2PositionMm, 'Lens 2', 'r'); % 画出第二片透镜位置
end

if params.optics.sampleEnabled % 如果样品启用
    localPlotOpticMarker(axHandle, results.derived.optics.samplePositionMm, 'Sample', 'w'); % 画出样品位置
end
end

function localPlotOpticMarker(axHandle, zPositionMm, labelText, lineColor)
marker = xline(axHandle, zPositionMm, ...
    'Color', lineColor, ...
    'LineWidth', 1, ...
    'Label', labelText, ...
    'LabelOrientation', 'aligned', ...
    'LabelVerticalAlignment', 'top', ...
    'LabelHorizontalAlignment', 'center', ...
    'HandleVisibility', 'off');

try
    marker.FontWeight = 'bold';
catch
end
end

function localProgressStart(params, totalSteps, derived)
% localProgressStart
% 作用：在 BPM 主循环开始时输出一条清晰的起始信息。

message = sprintf('BPM START: total_steps=%d, M=%.12g, M2=%.12g', totalSteps, derived.optics.M, derived.optics.M2); % 组合开始信息；使用 ASCII 避免 VS Code 终端乱码
localProgressWrite(params, message, true); % 打印/显示开始信息
end

function [lastProgressTimeSeconds, didPrint] = localProgressUpdate(params, index, totalSteps, zValueMm, progressTimer, lastProgressTimeSeconds)
% localProgressUpdate
% 作用：在 BPM 主循环过程中定期输出进度。
% 默认每 progressIntervalSeconds 秒输出一次，同时第 1 步和最后一步一定输出。

didPrint = false; % 默认当前这一步不输出
elapsedSeconds = toc(progressTimer); % 计算 BPM 主循环已经运行了多久
progressIntervalSeconds = max(0.1, params.output.progressIntervalSeconds); % 防止用户把时间间隔设成 0 或负数
shouldPrint = index == 1 || index == totalSteps || (elapsedSeconds - lastProgressTimeSeconds) >= progressIntervalSeconds; % 判断当前步是否需要输出

if ~shouldPrint % 如果当前步不需要输出
    return; % 直接返回，避免刷屏
end

percentDone = 100 * index / totalSteps; % 计算完成百分比
message = sprintf('BPM RUNNING: step=%d/%d, percent=%.1f%%, z_mm=%.2f, elapsed_s=%.1f', index, totalSteps, percentDone, zValueMm, elapsedSeconds); % 组合进度信息；使用 ASCII 避免 VS Code 终端乱码
localProgressWrite(params, message, false); % 打印/追加写入日志
lastProgressTimeSeconds = elapsedSeconds; % 更新最近一次输出进度的时间
didPrint = true; % 标记当前这一步确实输出了进度
end

function localProgressFinish(params, totalSteps, elapsedSeconds, derived)
% localProgressFinish
% 作用：在 BPM 主循环结束时输出一条完成信息。

message = sprintf('BPM FINISHED: total_steps=%d, elapsed_s=%.2f, M=%.12g, M2=%.12g', totalSteps, elapsedSeconds, derived.optics.M, derived.optics.M2); % 组合完成信息；使用 ASCII 避免 VS Code 终端乱码
localProgressWrite(params, message, false); % 打印/追加写入日志
end

function localProgressWrite(params, message, resetLog)
% localProgressWrite
% 作用：把同一条进度消息同时写到终端和日志文件。
% 这样如果 VS Code 终端不明显，也可以打开 outputs/BPM_drill_AI_progress.log 查看。

timestampedMessage = sprintf('[%s] %s', char(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss")), message); % 给消息加时间戳

if params.output.printProgress % 如果允许终端打印
    fprintf('%s\n', timestampedMessage); % 输出到 MATLAB/VS Code 终端
    drawnow limitrate; % 让 MATLAB 尽量及时刷新输出
end

if params.output.writeProgressLog % 如果允许写日志文件
    writeMode = 'a'; % 默认追加写入
    if resetLog % 如果要求重置日志
        writeMode = 'w'; % 就从头覆盖写入
    end

    fileId = fopen(params.output.progressLogFile, writeMode, 'n', 'UTF-8'); % 打开日志文件，使用 UTF-8 编码
    if fileId ~= -1 % 如果文件成功打开
        fprintf(fileId, '%s\n', timestampedMessage); % 写入一行日志
        fclose(fileId); % 关闭文件，确保内容马上落盘
    end
end
end

function localExportResults(results, params)
% localExportResults
% 作用：统一管理导出逻辑。
% 哪个开关开着，就调用对应的导出函数。

if params.output.write3DIntensity % 如果允许导出 3D 强度
    localExport3DIntensity(results, params); % 导出三维强度 tif
end

if params.output.writeAllPhase % 如果允许导出总相位
    localExportSlmPhase(results, params); % 导出 SLM 相位 bmp
end

if params.output.writeHelicalPhase % 如果允许导出 helical 相位
    localExportHelicalPhase(results, params); % 导出 helical 相位 bmp
end

if params.output.writeHelicalOffsetSlmBatch % 如果允许按 helicalPhaseOffset 批量导出总 SLM 相位
    localExportHelicalOffsetSlmPhaseBatch(results, params); % 逐个 offset 重新计算相位并导出 SLM 图
end

if params.output.writeRotatedSlmBatch % 如果允许批量导出旋转后的总 SLM 相位
    localExportRotatedSlmPhaseBatch(results, params); % 按指定角度范围导出一整组 SLM 相位 bmp
end
end

function localExport3DIntensity(results, params)
% localExport3DIntensity
% 作用：把三维强度归一化到 8-bit，并按 z 切片写入一个多页 tif 文件。

intensity3D = abs(results.propagation.E3D) .^ 2; % 先把三维复场转成三维强度
intensity3D = intensity3D - min(intensity3D(:)); % 把最小值平移到 0
intensity3D = intensity3D / max(intensity3D(:)); % 再归一化到 [0, 1]
intensity3D8Bit = uint8(intensity3D * 255); % 最后映射到 8-bit 灰度

[rowRange, columnRange] = localCenteredCropRanges(size(intensity3D8Bit, 1), size(intensity3D8Bit, 2), params.output.cropHalfWidthPixels); % 计算围绕中心裁剪的行列范围
fileName = fullfile(params.output.outputDir, localBuild3DFileName(params)); % 生成导出的完整文件路径

for index = 1:size(intensity3D8Bit, 3) % 逐个 z 切片写入 tif
    currentSlice = squeeze(intensity3D8Bit(rowRange, columnRange, index)); % 取出当前 z 切片对应的二维图像
    if index == 1 % 如果这是第一页
        imwrite(currentSlice, fileName); % 直接新建 tif 文件
    else % 如果不是第一页
        imwrite(currentSlice, fileName, 'WriteMode', 'append'); % 追加到已有 tif 文件后面
    end
end
end

function localExportSlmPhase(results, params)
% localExportSlmPhase
% 作用：把总输入相位导出成一张 8-bit 灰度 bmp。

slmPhase8Bit = localPhaseMatrixToUint8(angle(results.inputField)); % 先提取输入场相位，再映射到 8-bit
fileName = fullfile(params.output.outputDir, localBuildSlmPhaseFileName(params)); % 生成导出的完整文件路径
imwrite(slmPhase8Bit, fileName); % 把相位图写入磁盘
end

function localExportHelicalPhase(results, params)
% localExportHelicalPhase
% 作用：把 helical 相位单独导出成一张 8-bit 灰度 bmp。

helicalPhase = results.phase.helical;
if results.aperture.enabled
    helicalPhase(~results.aperture.mask) = 0;
end
helicalPhase8Bit = localPhaseMatrixToUint8(helicalPhase); % 把 helical 相位映射到 8-bit
fileName = fullfile(params.output.outputDir, localBuildHelicalPhaseFileName(params)); % 生成导出的完整文件路径
imwrite(helicalPhase8Bit, fileName); % 把 helical 相位图写入磁盘
end

function localExportHelicalOffsetSlmPhaseBatch(results, params)
% localExportHelicalOffsetSlmPhaseBatch
% 作用：不是旋转已经生成好的图片，而是逐个改变 helicalPhaseOffset，重新计算总相位后导出 SLM 图。
% 这样得到的是物理相位参数扫描，而不是后处理层面的 bitmap 几何旋转。

offsetStepDeg = params.output.helicalOffsetStepDeg; % 取出 offset 扫描步长，单位度

if ~isfinite(offsetStepDeg) || offsetStepDeg == 0 % 如果步长不是有限数，或者被设成 0
    error('helicalOffsetStepDeg must be a finite nonzero number.'); % 主动报错，避免冒出难懂的 colon 运算错误
end

offsetsDeg = params.output.helicalOffsetStartDeg:offsetStepDeg:params.output.helicalOffsetEndDeg; % 生成需要扫描的 helicalPhaseOffset 角度列表

if isempty(offsetsDeg) % 如果角度列表为空，通常说明起点、终点或步长设置不合理
    error('Helical offset angle list is empty. Check helicalOffsetStartDeg, helicalOffsetEndDeg, and helicalOffsetStepDeg.'); % 主动报错，避免悄悄不导出
end

basePhaseWithoutHelical = results.phase.axicon + results.phase.airy + results.phase.vortex + results.phase.checkerboardBessel + results.phase.compensation + results.phase.curve; % 这些相位项不随 helicalPhaseOffset 改变，可提前合并
helicalArgumentWithoutOffset = params.phase.helicalOrder * results.grid.theta - results.phase.radialChirp; % helical 相位中不含 offset 的角向-径向耦合部分
batchDir = localEnsureHelicalOffsetSlmBatchDirectory(params); % 确保批量输出子文件夹存在
localProgressWrite(params, sprintf('HELICAL OFFSET SLM BATCH START: total_images=%d, output_dir=%s', numel(offsetsDeg), batchDir), false); % 记录批量导出开始

for offsetIndex = 1:numel(offsetsDeg) % 逐个 helicalPhaseOffset 导出
    offsetDeg = offsetsDeg(offsetIndex); % 当前要使用的 helicalPhaseOffset，单位度
    offsetRad = deg2rad(offsetDeg); % 公式中的三角函数需要弧度，所以这里从度转换到弧度
    helicalPhase = params.phase.helicalGamma * cos(helicalArgumentWithoutOffset + offsetRad); % 用当前 offset 重新计算 helical 相位
    totalPhase = basePhaseWithoutHelical + helicalPhase; % 重新组合总 SLM 相位
    batchField = results.inputEnvelope .* exp(1i * totalPhase);
    if results.aperture.enabled
        batchField = batchField .* results.aperture.mask;
    end
    slmPhase8Bit = localPhaseMatrixToUint8(angle(batchField)); % 映射成 SLM 可用的 8-bit 灰度相位图
    fileName = fullfile(batchDir, localBuildHelicalOffsetSlmPhaseFileName(params, offsetDeg)); % 生成当前 offset 对应的文件名
    imwrite(slmPhase8Bit, fileName); % 写出当前 offset 的 bmp 文件
end

localProgressWrite(params, sprintf('HELICAL OFFSET SLM BATCH FINISHED: total_images=%d', numel(offsetsDeg)), false); % 记录批量导出结束
end

function batchDir = localEnsureHelicalOffsetSlmBatchDirectory(params)
% localEnsureHelicalOffsetSlmBatchDirectory
% 作用：确保 helicalPhaseOffset 扫描的 SLM 批量输出目录存在。

batchDir = fullfile(params.output.outputDir, params.output.helicalOffsetSlmSubfolder); % 把子文件夹放在统一 outputs 目录下面

if exist(batchDir, 'dir') ~= 7 % 如果这个批量输出目录还不存在
    mkdir(batchDir); % 就创建它
end
end

function localExportRotatedSlmPhaseBatch(results, params)
% localExportRotatedSlmPhaseBatch
% 作用：把当前总 SLM 相位图按固定角度步长批量旋转导出。
% 这里默认用于生成 0~359 度、每 1 度一张、刚好一整圈的顺时针 SLM 图。

slmPhase8Bit = localPhaseMatrixToUint8(angle(results.inputField)); % 先生成未旋转的 8-bit 总 SLM 相位图
rotationStepDeg = params.output.rotatedSlmStepDeg; % 取出角度步长，单独命名方便做合法性检查

if ~isfinite(rotationStepDeg) || rotationStepDeg == 0 % 如果步长不是有限数，或者被设成 0
    error('rotatedSlmStepDeg must be a finite nonzero number.'); % 主动报错，避免冒出难懂的 colon 运算错误
end

anglesDeg = params.output.rotatedSlmStartAngleDeg:rotationStepDeg:params.output.rotatedSlmEndAngleDeg; % 生成需要导出的角度列表

if isempty(anglesDeg) % 如果角度列表为空，通常说明起点、终点或步长设置不合理
    error('Rotated SLM angle list is empty. Check rotatedSlmStartAngleDeg, rotatedSlmEndAngleDeg, and rotatedSlmStepDeg.'); % 主动报错，避免悄悄不导出
end

batchDir = localEnsureRotatedSlmBatchDirectory(params); % 确保批量输出子文件夹存在
localProgressWrite(params, sprintf('SLM BATCH START: total_images=%d, output_dir=%s', numel(anglesDeg), batchDir), false); % 记录批量导出开始

for angleIndex = 1:numel(anglesDeg) % 逐个角度导出
    angleDeg = anglesDeg(angleIndex); % 当前要导出的旋转角度
    rotatedSlmPhase8Bit = localRotateSlmPhaseImage(slmPhase8Bit, angleDeg, params.output.rotatedSlmClockwise); % 按当前角度旋转图像
    fileName = fullfile(batchDir, localBuildRotatedSlmPhaseFileName(params, angleDeg)); % 生成当前角度对应的文件名
    imwrite(rotatedSlmPhase8Bit, fileName); % 写出当前角度的 bmp 文件
end

localProgressWrite(params, sprintf('SLM BATCH FINISHED: total_images=%d', numel(anglesDeg)), false); % 记录批量导出结束
end

function batchDir = localEnsureRotatedSlmBatchDirectory(params)
% localEnsureRotatedSlmBatchDirectory
% 作用：确保旋转 SLM 批量输出目录存在。

batchDir = fullfile(params.output.outputDir, params.output.rotatedSlmSubfolder); % 把子文件夹放在统一 outputs 目录下面

if exist(batchDir, 'dir') ~= 7 % 如果这个批量输出目录还不存在
    mkdir(batchDir); % 就创建它
end
end

function rotatedImage = localRotateSlmPhaseImage(slmPhase8Bit, angleDeg, rotateClockwise)
% localRotateSlmPhaseImage
% 作用：把一张 8-bit SLM 相位图旋转指定角度，并保持输出尺寸不变。
% Positive angle means visually counter-clockwise, so clockwise rotation uses a negative angle.

if mod(angleDeg, 360) == 0 % 如果角度刚好等效于 0 度
    rotatedImage = slmPhase8Bit; % 就直接使用原图，避免 0 度旋转带来不必要的插值/边界处理
    return; % 提前返回
end

signedAngleDeg = angleDeg; % 先把用户给的角度作为视觉上的逆时针角度
if rotateClockwise % 如果用户要求顺时针
    signedAngleDeg = -angleDeg; % MATLAB 中负角度代表顺时针
end

rotatedImage = localRotateImageNearestCrop(slmPhase8Bit, signedAngleDeg); % nearest 保持 8-bit 灰度级，crop 保持 SLM 图尺寸不变
end

function phase8Bit = localPhaseMatrixToUint8(phaseMatrix)
% localPhaseMatrixToUint8
% 作用：把一个相位矩阵从弧度值映射到 8-bit 灰度图。
% 这里默认认为输入相位主要位于 [-pi, pi] 范围内。

phaseNormalized = (phaseMatrix + pi) / (2 * pi); % 把 [-pi, pi] 映射到 [0, 1]
phase8Bit = uint8(phaseNormalized * 255); % 再把 [0, 1] 映射到 [0, 255]
end

function [rowRange, columnRange] = localCenteredCropRanges(rowCount, columnCount, cropHalfWidthPixels)
% localCenteredCropRanges
% 作用：根据图像尺寸和半宽像素数，给出围绕中心裁剪的行列索引范围。

rowCenter = round(rowCount / 2); % 图像中心行
columnCenter = round(columnCount / 2); % 图像中心列

rowStart = max(1, rowCenter - cropHalfWidthPixels); % 裁剪起始行，不能小于 1
rowEnd = min(rowCount, rowCenter + cropHalfWidthPixels); % 裁剪结束行，不能超过总行数
columnStart = max(1, columnCenter - cropHalfWidthPixels); % 裁剪起始列，不能小于 1
columnEnd = min(columnCount, columnCenter + cropHalfWidthPixels); % 裁剪结束列，不能超过总列数

rowRange = rowStart:rowEnd; % 最终返回的行索引范围
columnRange = columnStart:columnEnd; % 最终返回的列索引范围
end

function token = localBuildAxiconDefinitionToken(params)
% localBuildAxiconDefinitionToken
% 作用：把当前 axicon 主定义写进导出文件名，避免 coneAngle/radialPeriod/physical 模式混淆。

mode = char(string(params.phase.axiconMode));
switch mode
    case 'coneAngle'
        token = ['axiconMode=coneAngle beta=', num2str(params.phase.axiconConeAngleDeg), 'deg'];
    case 'radialPeriodMm'
        token = ['axiconMode=radialPeriodMm period=', num2str(params.phase.axiconRadialPeriodMm), 'mm'];
    case 'radialPeriodPx'
        token = ['axiconMode=radialPeriodPx period=', num2str(params.phase.axiconRadialPeriodPx), 'px'];
    case 'radialCycles'
        token = ['axiconMode=radialCycles cycles=', num2str(params.phase.axiconRadialCycles)];
    case 'physicalEquivalent'
        token = ['axiconMode=physicalEquivalent n=', num2str(params.phase.axiconIndex), ' alpha=', num2str(params.phase.axiconAngleDeg), 'deg'];
    otherwise
        token = ['axiconMode=', mode];
end
token = [token, localBuildAxiconGeometryToken(params), localBuildApertureToken(params)];
end

function token = localBuildAxiconGeometryToken(params)
geometry = char(string(params.phase.axiconGeometry));
if strcmp(geometry, 'circular')
    token = '';
    return;
end
token = [' geometry=', geometry, ...
    ' orientation=', localBuildAngleToken(params.phase.axiconOrientationDeg), 'deg'];
end

function token = localBuildApertureToken(params)
if params.phase.apertureRadiusMm == 0
    token = '';
    return;
end
token = [' apertureR=', num2str(params.phase.apertureRadiusMm), 'mm'];
end

function token = localBuildCheckerboardBesselToken(params)
if ~params.phase.checkerboardBesselEnabled
    token = '';
    return;
end

token = [' checkerBessel tile=', num2str(params.phase.checkerboardTileSizePx), 'px', ...
    ' TC1=', num2str(params.phase.checkerboardTc1), ...
    ' beta1=', num2str(params.phase.checkerboardBeta1Deg), 'deg', ...
    ' TC2=', num2str(params.phase.checkerboardTc2), ...
    ' beta2=', num2str(params.phase.checkerboardBeta2Deg), 'deg'];
end

function token = localBuildCurvedShiftToken(params)
if params.phase.curvedMaxShiftXMm == 0 && params.phase.curvedMaxShiftYMm == 0
    token = '';
    return;
end

token = [' curveShift x=', num2str(params.phase.curvedMaxShiftXMm), 'mm', ...
    ' y=', num2str(params.phase.curvedMaxShiftYMm), 'mm'];
end

function fileName = localBuild3DFileName(params)
% localBuild3DFileName
% 作用：按照当前参数生成 3D 强度 tif 的文件名。

fileName = ['Drill Beam 3D ', ... % 文件名前缀，标明这是 3D 强度
    num2str(params.simulation.sizeMm), 'x', num2str(params.simulation.sizeMm), 'x', num2str(params.simulation.zRangeMm), ' mm ', ... % 写入横向尺寸和 z 传播范围
    localBuildAxiconDefinitionToken(params), ... % 写入当前 axicon 定义
    ' lc=', num2str(params.phase.vortexCharge), ... % 写入涡旋拓扑荷
    localBuildCheckerboardBesselToken(params), ... % 写入棋盘 Bessel vortex 参数
    localBuildCurvedShiftToken(params), ... % 写入曲线 Bessel 的 x/y 末端偏移量
    ' gamma=', num2str(params.phase.helicalGamma), ... % 写入 helical 调制度
    ' m=', num2str(params.phase.helicalOrder), ... % 写入 helical 阶数
    ' helicalOffset=', localBuildAngleToken(params.phase.helicalPhaseOffset), ... % 写入 helical 相位偏置，避免不同 offset 的 3D 文件互相覆盖
    ' omega=', num2str(params.phase.omegaInner), ... % 写入 omega 参数
    ' w=', num2str(params.beam.waistRadiusMm), ... % 写入高斯束腰半径
    '.tif']; % 文件扩展名
end

function fileName = localBuildSlmPhaseFileName(params)
% localBuildSlmPhaseFileName
% 作用：按照当前参数生成总 SLM 相位 bmp 的文件名。

fileName = ['Drill Beam SLM phase ', ... % 文件名前缀，标明这是总 SLM 相位
    num2str(params.simulation.sizeMm), 'x', num2str(params.simulation.sizeMm), ' mm ', ... % 写入横向尺寸
    localBuildAxiconDefinitionToken(params), ... % 写入当前 axicon 定义
    ' lc=', num2str(params.phase.vortexCharge), ... % 写入涡旋拓扑荷
    localBuildCheckerboardBesselToken(params), ... % 写入棋盘 Bessel vortex 参数
    localBuildCurvedShiftToken(params), ... % 写入曲线 Bessel 的 x/y 末端偏移量
    ' gamma=', num2str(params.phase.helicalGamma), ... % 写入 helical 调制度
    ' m=', num2str(params.phase.helicalOrder), ... % 写入 helical 阶数
    ' omega=', num2str(params.phase.omegaInner), ... % 写入 omega 参数
    ' w=', num2str(params.beam.waistRadiusMm), ... % 写入束腰半径
    '.bmp']; % 文件扩展名
end

function fileName = localBuildHelicalPhaseFileName(params)
% localBuildHelicalPhaseFileName
% 作用：按照当前参数生成单独 helical 相位 bmp 的文件名。

fileName = ['Drill Beam Helical phase ', ... % 文件名前缀，标明这是 helical 相位
    num2str(params.simulation.sizeMm), 'x', num2str(params.simulation.sizeMm), ' mm ', ... % 写入横向尺寸
    localBuildAxiconDefinitionToken(params), ... % 写入当前 axicon 定义
    ' lc=', num2str(params.phase.vortexCharge), ... % 写入涡旋拓扑荷
    localBuildCheckerboardBesselToken(params), ... % 写入棋盘 Bessel vortex 参数
    localBuildCurvedShiftToken(params), ... % 写入曲线 Bessel 的 x/y 末端偏移量
    ' gamma=', num2str(params.phase.helicalGamma), ... % 写入 helical 调制度
    ' m=', num2str(params.phase.helicalOrder), ... % 写入 helical 阶数
    ' omega=', num2str(params.phase.omegaInner), ... % 写入 omega 参数
    ' w=', num2str(params.beam.waistRadiusMm), ... % 写入束腰半径
    '.bmp']; % 文件扩展名
end

function fileName = localBuildHelicalOffsetSlmPhaseFileName(params, offsetDeg)
% localBuildHelicalOffsetSlmPhaseFileName
% 作用：按照当前参数和 helicalPhaseOffset，生成批量 SLM 相位 bmp 的文件名。

offsetToken = localBuildAngleToken(offsetDeg); % 把 offset 整理成适合文件名的文本，例如 000deg、001deg
fileName = ['Drill Beam SLM phase helicalOffset ', offsetToken, ' ', ... % 文件名前缀和 helicalPhaseOffset 数值
    num2str(params.simulation.sizeMm), 'x', num2str(params.simulation.sizeMm), ' mm ', ... % 写入横向尺寸
    localBuildAxiconDefinitionToken(params), ... % 写入当前 axicon 定义
    ' lc=', num2str(params.phase.vortexCharge), ... % 写入涡旋拓扑荷
    localBuildCheckerboardBesselToken(params), ... % 写入棋盘 Bessel vortex 参数
    localBuildCurvedShiftToken(params), ... % 写入曲线 Bessel 的 x/y 末端偏移量
    ' gamma=', num2str(params.phase.helicalGamma), ... % 写入 helical 调制度
    ' m=', num2str(params.phase.helicalOrder), ... % 写入 helical 阶数
    ' omega=', num2str(params.phase.omegaInner), ... % 写入 omega 参数
    ' w=', num2str(params.beam.waistRadiusMm), ... % 写入束腰半径
    '.bmp']; % 文件扩展名
end

function fileName = localBuildRotatedSlmPhaseFileName(params, angleDeg)
% localBuildRotatedSlmPhaseFileName
% 作用：按照当前参数和旋转角度，生成批量 SLM 相位 bmp 的文件名。

angleToken = localBuildAngleToken(angleDeg); % 把角度整理成适合文件名的文本，例如 000deg、001deg
if params.output.rotatedSlmClockwise % 如果当前批量导出使用顺时针方向
    directionToken = 'CW'; % 文件名里标记 CW，表示 clockwise
else % 如果当前批量导出使用逆时针方向
    directionToken = 'CCW'; % 文件名里标记 CCW，表示 counter-clockwise
end

fileName = ['Drill Beam SLM phase rotated ', directionToken, ' ', angleToken, ' ', ... % 文件名前缀和旋转角度
    num2str(params.simulation.sizeMm), 'x', num2str(params.simulation.sizeMm), ' mm ', ... % 写入横向尺寸
    localBuildAxiconDefinitionToken(params), ... % 写入当前 axicon 定义
    ' lc=', num2str(params.phase.vortexCharge), ... % 写入涡旋拓扑荷
    localBuildCheckerboardBesselToken(params), ... % 写入棋盘 Bessel vortex 参数
    localBuildCurvedShiftToken(params), ... % 写入曲线 Bessel 的 x/y 末端偏移量
    ' gamma=', num2str(params.phase.helicalGamma), ... % 写入 helical 调制度
    ' m=', num2str(params.phase.helicalOrder), ... % 写入 helical 阶数
    ' omega=', num2str(params.phase.omegaInner), ... % 写入 omega 参数
    ' w=', num2str(params.beam.waistRadiusMm), ... % 写入束腰半径
    '.bmp']; % 文件扩展名
end

function rotatedImage = localRotateImageNearestCrop(inputImage, angleDeg)
% Local nearest-neighbor crop rotation, avoiding an Image Processing Toolbox dependency.
[rowCount, columnCount] = size(inputImage);
rowCenter = (rowCount + 1) / 2;
columnCenter = (columnCount + 1) / 2;
[outputColumns, outputRows] = meshgrid(1:columnCount, 1:rowCount);

xOut = outputColumns - columnCenter;
yOut = outputRows - rowCenter;
cosTheta = cosd(angleDeg);
sinTheta = sind(angleDeg);

sourceColumns = round(cosTheta * xOut + sinTheta * yOut + columnCenter);
sourceRows = round(-sinTheta * xOut + cosTheta * yOut + rowCenter);
insideInput = sourceRows >= 1 & sourceRows <= rowCount & sourceColumns >= 1 & sourceColumns <= columnCount;

rotatedImage = zeros(size(inputImage), 'like', inputImage);
sourceLinearIndex = sub2ind([rowCount, columnCount], sourceRows(insideInput), sourceColumns(insideInput));
rotatedImage(insideInput) = inputImage(sourceLinearIndex);
end

function angleToken = localBuildAngleToken(angleDeg)
% localBuildAngleToken
% 作用：把角度数值转换成稳定、易排序、适合 Windows 文件名的文本。

if abs(angleDeg - round(angleDeg)) < 1e-9 % 如果角度本质上是整数
    angleToken = sprintf('%03ddeg', round(angleDeg)); % 用三位数补零，保证文件按 000、001、002 ... 排序
else % 如果以后用户把步长改成小数
    angleToken = sprintf('%.3fdeg', angleDeg); % 保留三位小数
    angleToken = strrep(angleToken, '.', 'p'); % 文件名里用 p 代替小数点，避免不同系统解析差异
end
end
