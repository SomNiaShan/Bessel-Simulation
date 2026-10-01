# BPM_drill_AI 参数说明

这份文档对应主脚本：

- `Bessel-Simulation/src/BPM_drill_AI.m`

阅读建议：

- 如果你是第一次接手这份代码，先看主脚本顶部的中文注释，再对照这份文档。
- 如果你只是想快速调参，优先看“常用优先级”和“参数分组说明”两节。
- 如果你准备认真改物理模型，再仔细看每个参数后面的“调大/调小会怎样”和“注意事项”。

## 常用优先级

最常改的通常是这几类：

1. `params.phase`
   这里决定输出光束长什么样，尤其是 `apertureRadiusMm`、`axiconGeometry`、`axiconMode` 及其当前主参数、`vortexCharge`、棋盘 Bessel vortex 参数、`helicalGamma`、`helicalOrder`、`omegaInner`、`omegaOuter`。
2. `params.simulation`
   这里决定仿真精度和计算量，尤其是 `N`、`zRangeMm`、`dzMm`。
3. `params.output`
   这里决定要不要画图、要不要导出文件。
4. `params.material.damageThresholdWPerM2`
   这里只影响图里的阈值参考线，不影响传播本身。
5. `params.optics`
   这里只在你真的启用透镜或样品时才会影响传播。

## 使用方式

默认方式是直接运行主脚本。

如果你不想改源码，可以在 MATLAB 工作区先写：

```matlab
BPM_drill_AI_overrides.phase.vortexCharge = 2;
BPM_drill_AI_overrides.phase.helicalOrder = 3;
BPM_drill_AI_overrides.output.writeHelicalPhase = true;
BPM_drill_AI_overrides.output.writeHelicalOffsetSlmBatch = true;
run('C:/Users/Shan/Desktop/academic/Bessel-Simulation/src/BPM_drill_AI.m');
```

这样只会覆盖你指定的字段，其余参数仍然使用默认值。

## 参数分组说明

### 1. `params.simulation`

#### App 的局部 z 加密（`adaptiveCollins`）

在左侧 **Z sampling** 页选择 `local`，用表格填写多个
`[起点 z, 终点 z, 局部 dz]`，单位均为 mm；点击 **Preview sampling**
可查看实际切片数、有效区间、最小/最大间距和内存估计。
Simulation 页的 **Base z spacing**（`dzMm`）仍控制基础粗网格。
每个新增切片都从完整输入场计算；绘图插值不替代传播计算。

| 参数 | 默认值 | 作用 |
| --- | --- | --- |
| `zSamplingMode` | `'uniform'` | `uniform` 保持原采样；`local` 启用局部区间和额外平面。 |
| `zRefinementRegionsMm` | `zeros(0,3)` | K×3 矩阵，每行为 `[start,end,localDz]`。要求 `0≤start<end≤zRangeMm`，`0<localDz≤dzMm`；重叠区间采用最小步长。 |
| `zExtraPlanesMm` | `[]` | 额外精确观察坐标，例如 `[220.5,221.05]`，必须位于传播范围内。界面接受逗号、分号或空白分隔的数字，支持科学计数法，不执行表达式。 |
| `maxZPlanes` | `20000` | 生成坐标或强度堆栈前的切片数上限，超限时报错，不自动降低精度。 |

保留基础网格、所有区间端点、启用的透镜/样品位置、传播终点和额外平面。
由于这些坐标可能不对齐，实际间距可小于填写的局部 dz。
`uniform` 模式保留未启用的区间设置；切换到 `legacyASM` 会显示提示并
回到 `uniform`，表格不清空。脚本请求 `legacyASM + local` 会报错。
`useBPM=false` 时只返回输入平面 z=0。

对 f1=200 mm、f2=10 mm、透镜位于 z=0 和 210 mm 的示例，可先用
`zRangeMm=250`、`dzMm=1`、区间 `[218,223,0.02]`、额外平面 `220.5`。
ROI N=512 时为 496 层，强度堆栈约 0.484 GiB；局部 dz=0.01 则为
746 层、约 0.729 GiB。整个 250 mm 范围使用 dz=0.02 会产生
12,501 层，单强度堆栈就约 12.208 GiB。
继续减半局部 dz，比较峰位置、峰值和单峰 FWHM 是否收敛；若峰在
加密区间边界，先扩大区间。z=220.5 是该例的成像面，不应当作预设峰位置。

`Bessel_Simulation_app_engine('plan',params)` 会返回解析后的参数、
`zPlan` 与 `memory`，不会运行传播或创建输出文件。
Run 和预览使用同一份坐标及内存公式；估计包括源数组、强度堆栈与 CZT
工作数组，但不是 MATLAB 进程真实峰值内存的保证。

TIFF 第 k 页对应 JSON 的 `zMm(k)`。JSON 和原始 MAT 均保存实际运行的
`zSamplingMetadata`；修改导出前的界面不会重新定义已计算的 z 坐标。
很多外部三维查看器默认 TIFF 层间距相等，因此定量分析请读 MAT/JSON 的
实际坐标；沿 z 积分使用 `trapz(zMm,data)`，不要乘一个固定 dz。
摘要中的最大值指已采样平面内的最大值，切片峰值仅覆盖 xy ROI。
z 加密不能解决 xy ROI 截断、源平面欠采样或近轴模型的适用范围问题。

2026-10-01 在 MATLAB R2026a 验证：41/41 个测试通过，包含非均匀坐标
导出与界面切换。上述 N=1080、ROI N=512、M²=1.2 示例中，局部 dz=0.02
与 0.01 mm 的采样峰分别位于 221.06 和 221.07 mm；峰值相差约
0.0364%，单峰纵向 FWHM 分别约 0.88001 和 0.88021 mm，相差约
0.0226%。共同 z 平面的强度数组完全一致。完整对照函数为
`tests/benchmark_z_refinement.m`，可独立运行；这些收敛结果只针对该示例。

#### `N`

- 含义：横向采样点数，整个计算平面大小是 `N x N`。
- 调大后：
  固定 `sizeMm` 时横向分辨率更高，可表示更高的空间频率；频域采样间距仍为 `1/sizeMm`。
- 调小后：
  计算更快、内存更省，但相位细节和传播结果更容易失真。
- 直接影响：
  计算速度、内存占用、图像精细程度。
- 常见风险：
  `N` 很大时，`E_3D_BPM` 三维数组会非常占内存。

#### `sizeMm`

- 含义：横向计算窗口的物理尺寸，单位 mm。
- 调大后：
  能容纳更大的横向结构，不容易把场截断在边界。
- 调小后：
  视野更聚焦，但更容易发生边界截断。
- 直接影响：
  实空间采样间距 `dx`、`dy`，以及频域采样范围。
- 常见风险：
  只改 `sizeMm` 不改 `N`，会让像素物理尺寸变大，分辨率变粗。

#### `zRangeMm`

- 含义：沿 z 方向总共传播多远。
- 调大后：
  能看更长的传播过程，能看到更远处的结构变化。
- 调小后：
  只看近场或中短程传播。
- 直接影响：
  三维数据长度、运行时间、导出 tif 页数。
- 常见风险：
  很大的 `zRangeMm` 配上很小的 `dzMm`，会让 z 切片数暴增。

#### `dzMm`

- 含义：脚本版沿 z 输出/推进的步长。App 的 `adaptiveCollins` 模式使用它指定常规观察面的间距，光学元件另在精确位置计算。
- 调大后：
  观察面更稀疏、计算更快，但可能漏掉焦区的峰值。
- 调小后：
  观察面更密、计算更慢；单纯减小它不能修复横向欠采样或 FFT 周期回卷。
- 直接影响：
  z 方向采样精度和循环次数。
- 常见风险：
  焦区轴向变化快时，需要足够密的观察面；脚本版还会把不在步进网格上的元件延后到下一步。

#### `useBPM`

- 含义：是否执行 BPM 传播。
- `true`：
  正常做沿 z 传播。
- `false`：
  不传播，直接把输入场作为输出。
- 适合场景：
  调试输入相位、检查导出逻辑、快速验证脚本是否能跑通。

### 2. `params.laser`

#### `wavelengthMm`

- 含义：激光波长，单位 mm。
- 调大后：
  波数 `k` 会减小，传播和相位调制的尺度都会变化。
- 调小后：
  波数 `k` 会增大。
- 直接影响：
  axicon 相位、传播算子、样品中的波数。
- 常见风险：
  改波长时，最好同步检查折射率、axicon 参数是否仍然合理。

#### `powerW`

- 含义：圆孔径之前的入射平均功率。
- 调大后：
  峰值功率估算变大，后处理里的功率密度曲线整体抬高。
- 调小后：
  功率密度曲线整体降低。
- 直接影响：
  后处理中的功率密度估算。
- 不影响：
  相位形状、传播路径、场分布归一化形状本身。

#### `repetitionRateHz`

- 含义：脉冲重复频率。
- 调大后：
  在平均功率固定下，单脉冲能量减小，峰值功率降低。
- 调小后：
  单脉冲能量增大，峰值功率升高。
- 直接影响：
  后处理功率密度的绝对标尺。

#### `pulseWidthS`

- 含义：脉宽。
- 调大后：
  峰值功率降低。
- 调小后：
  峰值功率升高。
- 直接影响：
  后处理中的峰值功率密度估算。

### 3. `params.beam`

#### `waistRadiusMm`

- 含义：输入高斯光束腰半径。
- 调大后：
  入射光束横向更宽，参与构成相位的有效区域更大。
- 调小后：
  光束更集中，边缘区域参与更少。
- 直接影响：
  输入场包络、焦深相关估算、导出文件名中的 `w`。
- 常见风险：
  如果束腰太小，某些相位结构会因照明范围不足而看不明显。

#### `fieldAmplitude`

- 含义：输入场振幅整体缩放系数。
- 调大后：
  强度整体升高。
- 调小后：
  强度整体降低。
- 注意：
  这主要影响场强比例，不改变相位形状。

### 4. `params.phase`

这一组是最核心的“光束造型参数”。

#### `airyStrength`

- 含义：Airy 三次相位强度。
- 调大后：
  Airy 弯曲特征会更明显。
- 调小后：
  Airy 效应减弱；设为 `0` 就完全关闭。
- 常见风险：
  太大时会让总相位变得很陡，输出可能更复杂、更难解释。

#### `airyScaleMm`

- 含义：Airy 相位的空间尺度。
- 调大后：
  Airy 相位变化更慢、更平缓。
- 调小后：
  Airy 相位变化更快、更陡。

#### `apertureRadiusMm`

- 含义：位于 SLM/输入平面、以光轴为中心的硬边圆形振幅孔径，单位 mm。
- `0`：
  完全打开，不对输入场做任何截断，并保持旧仿真结果。
- `> 0`：
  当 `sqrt(x^2 + y^2) <= apertureRadiusMm` 时 mask 为 1，否则为 0。孔径外的复振幅场被设为 0，而不是只把相位设为 0。
- 功率定义：
  `laser.powerW` 是孔径前功率。程序计算 `results.aperture.transmission`，并用 `powerW * transmission` 作为孔径后平均功率。功率密度后处理保留这个损耗。
- 数值效果：
  硬边会产生物理上应有的衍射振铃；孔径过小时需要检查横向网格是否有足够采样点。
- 实验注意：
  仅在相位型 SLM 上显示零相位不能挡光。实验中需要实体光阑、振幅调制器，或者把孔径外的光偏转后用空间滤波去除。

#### `axiconGeometry`

- 含义：选择主 axicon 相位的横向几何。
- `circular`：
  使用原来的圆对称相位 `phase.axicon = k_r * (R - r)`，其中 `r = sqrt(x^2 + y^2)`。
- `linear1D`：
  使用一维 biprism 相位 `phase.axicon = k_r * (R - abs(u))`，形成 Bessel-like light sheet。
- 默认：
  `circular`，因此旧参数和旧仿真结果保持不变。

#### `axiconOrientationDeg`

- 含义：`linear1D` 相位法向 `u` 在 x-y 平面内的角度，单位度。
- 坐标关系：
  `u = x*cos(gamma) + y*sin(gamma)`，其中 `gamma = axiconOrientationDeg`。
- `0 deg`：
  相位沿 x 变化，light sheet 沿 y-z 平面延伸。
- `90 deg`：
  相位沿 y 变化，light sheet 沿 x-z 平面延伸。
- 注意：
  在 `circular` geometry 下该参数不参与相位计算。

#### `axiconMode`

- 含义：选择 axicon 横向相位斜率的主定义方式；它和 `axiconGeometry` 相互独立。
- 可选值：
  `coneAngle`、`radialPeriodMm`、`radialPeriodPx`、`radialCycles`、`physicalEquivalent`。
- 注意：
  程序内部会先把当前模式换算成统一的 `derived.axicon.krRadPerMm` 和
  `derived.axicon.coneAngleDeg`，后续 circular 和 linear1D 相位都使用这两个等效量。
  因此多个 axicon 输入参数不会同时生效，只有当前模式对应的参数是主输入。
  在 APP 里，未选中的 axicon 输入框会作为只读等效值随当前主输入自动刷新。

#### `axiconConeAngleDeg`

- 含义：SLM 全息 axicon 的有效出射锥角 `beta`，单位度。
- 生效条件：
  `axiconMode = 'coneAngle'`。
- 调大后：
  径向相位斜率变大，理论最大无衍射距离会缩短。

#### `axiconRadialPeriodMm`

- 含义：SLM 沿当前 axicon 坐标的 `2*pi` 相位周期，单位 mm。
- 生效条件：
  `axiconMode = 'radialPeriodMm'`。
- 调小后：
  横向相位斜率变大，等效锥角变大。

#### `axiconRadialPeriodPx`

- 含义：SLM 沿当前 axicon 坐标的 `2*pi` 相位周期，单位为当前输出相位矩阵的像素。
- 生效条件：
  `axiconMode = 'radialPeriodPx'`。
- 注意：
  这里的 1 pixel 对应 `simulation.sizeMm / simulation.N` mm。
  如果改变 `N` 或 `sizeMm`，同一个像素周期对应的物理周期也会变化。

#### `axiconRadialCycles`

- 含义：从光轴中心到计算窗口参考半宽 `R` 的 axicon `2*pi` 相位周期数。
- 生效条件：
  `axiconMode = 'radialCycles'`。
- 换算关系：
  令 `R = simulation.sizeMm / 2`，则
  `axiconRadialPeriodMm = R / axiconRadialCycles`，
  `k_r = 2*pi*axiconRadialCycles/R`。
- 例子：
  默认 `sizeMm = 8.64 mm` 时，`R = 4.32 mm`；如果 `axiconRadialCycles = 20`，
  则中心到参考边缘共有 20 个周期，每个周期 `4.32/20 = 0.216 mm`。

#### `axiconIndex`

- 含义：等效真实 axicon 的材料折射率。
- 生效条件：
  仅当 `axiconMode = 'physicalEquivalent'` 时，它和 `axiconAngleDeg` 共同决定有效锥角。

#### `axiconAngleDeg`

- 含义：等效真实 axicon 的底角 `alpha`，单位度。
- 生效条件：
  仅当 `axiconMode = 'physicalEquivalent'` 时生效。
- 注意：
  新版本里 `phase.axicon` 不再直接使用 `axiconAngleDeg`；
  它会先换算成有效锥角 `beta` 和径向波矢 `k_r`。

#### `curvedMaxShiftXMm` / `curvedMaxShiftYMm`

- 含义：曲线 Bessel 设计中，末端期望横向偏移量，分别控制 x / y 方向。
- 调大后：
  对应方向的曲线轨迹偏转更明显；两个方向都非零时，轨迹会沿合成方向偏转。
- 调小后：
  对应方向的弯曲减弱；两个参数都设为 `0` 时回到不弯曲。
- 常见风险：
  过大时可能得到很强的非对称结构。
- 限制：
  当前公式只适用于 `axiconGeometry = 'circular'`。使用 `linear1D` 时两个 shift 都必须为 `0`。

#### light-sheet 传播截面

- App 和脚本默认绘图：
  使用实验室固定坐标下 `x = 0` 的 y-z 截面，对应 `crossSection...` 字段。改变 `axiconOrientationDeg` 时，可以直接看到旋转后的 light sheet 与该固定平面如何相交。
- `normalCrossSection...`：
  沿 axicon 相位法向 `u` 提取的 u-z 截面，用于检查 light-sheet 厚度、旁瓣和传播长度。
- `tangentCrossSection...`：
  沿 sheet 切向 `v` 提取的 v-z 截面，用于检查 sheet 面内延展和均匀性。

#### `compensationPhase`

- 含义：预留的额外补偿相位。
- 调大或改成矩阵后：
  会直接叠加到总相位中。
- 默认：
  为 `0`，也就是关闭。
- 适用场景：
  以后如果你想补系统像差、加额外相位修正，可以从这里接入。

#### `vortexCharge`

- 含义：涡旋拓扑荷数 `l`。
- 调大后：
  涡旋相位绕中心旋转得更快，中心奇点阶数更高。
- 调小后：
  涡旋特征减弱；设为 `0` 表示没有 vortex 相位。
- 直接影响：
  输出的中空程度、螺旋结构特征。

#### `checkerboardBesselEnabled`

- 含义：是否启用棋盘式双 Bessel vortex 相位。
- 关闭时：
  该相位项为 0，原来的 axicon / vortex / helical 等逻辑不变。
- 开启时：
  程序会生成两束 Bessel vortex 相位：
  `phase_1 = k sin(beta_1) * (R - r) + TC_1 * theta`，
  `phase_2 = k sin(beta_2) * (R - r) + TC_2 * theta`，
  然后按棋盘格 mask 在二维相位图中选择对应位置的 `phase_1` 或 `phase_2`。
- 棋盘规则：
  同奇偶格子使用 beam 1，即 odd-odd 和 even-even；交替格子使用 beam 2，即 odd-even 和 even-odd。

#### `checkerboardTileSizePx`

- 含义：棋盘格边长，单位是生成相位图的像素。
- 调大后：
  每个区域更大，beam 1 / beam 2 的切换更少。
- 调小后：
  切换更密，棋盘 multiplexing 更细。
- 常见风险：
  太小会导致强烈像素级相位跳变；太大则只剩少量区域交替。

#### `checkerboardTc1` / `checkerboardTc2`

- 含义：棋盘 beam 1 / beam 2 的 vortex 拓扑荷数。
- 用法：
  例如 `checkerboardTc1 = 1`、`checkerboardTc2 = -1` 会在棋盘格中交替使用相反手性的 vortex 相位。

#### `checkerboardBeta1Deg` / `checkerboardBeta2Deg`

- 含义：棋盘 beam 1 / beam 2 的 axicon cone angle `beta_1` / `beta_2`，单位是度。
- 用法：
  二者可以相同，只改变 TC；也可以不同，同时改变 Bessel cone angle。
- 限制：
  必须在 `-90` 到 `90` 度之间。

#### `helicalGamma`

- 含义：helical 相位调制度。
- 调大后：
  helical 相位的影响更强。
- 调小后：
  helical 相位贡献更弱；设为 `0` 可完全关闭 helical 相位。
- 适用场景：
  如果你想单独看 axicon+vortex 的结果，可以把它设为 `0`。

#### `helicalOrder`

- 含义：helical 相位中的角向阶数 `m`。
- 调大后：
  一圈里的角向重复次数增加，结构会更密。
- 调小后：
  角向结构变稀疏。
- 直接影响：
  helical 相位图样和导出文件名中的 `m`。

#### `helicalPhaseOffset`

- 含义：helical 相位整体的初始相位偏置，单位是度。
- 调大或调小后：
  主要是把 helical 图样整体沿角向平移。
- 一般用途：
  微调图样朝向或对称位置。
- 注意：
  代码内部会在代入 `cos(...)` 前自动把它从度转换成弧度。

#### `omegaInner`

- 含义：径向 chirp 在中心处的频率参数。
- 调大后：
  靠近中心区域的径向周期会更密。
- 调小后：
  中心区域变化更缓。
- 直接影响：
  helical 相位里中心部分的细密程度。

#### `omegaOuter`

- 含义：径向 chirp 在边缘处的频率参数。
- 调大后：
  靠近边缘区域的径向周期更密。
- 调小后：
  边缘区域变化更缓。
- 适合搭配：
  和 `omegaInner` 一起用来做径向周期渐变。

### 5. `params.optics`

这组参数只有在 `lens1Enabled`、`lens2Enabled`、`sampleEnabled` 打开后才真正进入传播。

#### `lens1FocalLengthMm`

- 含义：第一片透镜焦距。

#### `lens2FocalLengthMm`

- 含义：第二片透镜焦距。

#### `lens1PositionMm`

- 含义：第一片透镜的位置。
- 调大后：
  第一片透镜在更靠后的传播位置插入。
- 调小后：
  更早插入。
- 注意：
  脚本版的 `lens2PositionMm` 是独立参数，不会随着焦距自动变化。App 中选择 `telescopeLocked` 后，才会按 `lens1PositionMm + f1 + f2` 重设第二片透镜位置。

#### `samplePositionMm`

- 含义：样品在 z 轴上的绝对位置，单位 mm。
- 默认值：`660`。
- 调大后：
  样品更晚进入传播过程。
- 调小后：
  样品更早进入。

#### `lens1Enabled`

- 含义：是否启用第一片透镜。
- `true`：
  当前场在达到设定 z 位置时乘上第一片透镜相位。
- `false`：
  完全忽略它。

#### `lens2Enabled`

- 含义：是否启用第二片透镜。
- 作用方式与 `lens1Enabled` 相同。

#### `sampleEnabled`

- 含义：是否在传播到样品位置后，把传播算子切换成样品折射率版本。
- `true`：
  到达样品位置后，传播算子从背景介质切到样品介质。
- `false`：
  全程按背景介质传播。

### 6. `params.material`

#### `backgroundIndex`

- 含义：背景介质折射率。
- 调大后：
  背景波数变大，传播算子改变。
- 调小后：
  背景波数变小。
- 常见用途：
  从空气换到其他背景介质时需要改它。

#### `sampleIndex`

- 含义：样品折射率。
- 调大后：
  样品中的传播波数增大。
- 调小后：
  样品中的传播波数减小。
- 注意：
  只有 `sampleEnabled = true` 时它才会真正影响传播。

#### `damageThresholdWPerM2`

- 含义：材料损伤阈值，单位 `W/m^2`。
- 当前默认值：
  `7.2e17 W/m^2`，它等价于实验给出的 `7.2e13 W/cm^2`。
- 调大后：
  图里的红色阈值参考线会上升。
- 调小后：
  红线会下降。
- 不影响：
  不影响光场传播本身，只影响后处理图中的参考线。

### 7. `params.output`

#### `write3DIntensity`

- 含义：是否导出三维强度多页 tif。
- `true`：
  会输出一个多页 tif。
- `false`：
  不导出这个文件。

#### `writeAllPhase`

- 含义：是否导出总 SLM 相位 bmp。
- `true`：
  会导出总相位图。
- `false`：
  不导出。

#### `writeHelicalPhase`

- 含义：是否导出单独的 helical 相位 bmp。
- `true`：
  会导出 helical phase 图。
- `false`：
  不导出。

#### `writeHelicalOffsetSlmBatch`

- 含义：是否批量扫描 `helicalPhaseOffset` 并导出总 SLM 相位 bmp。
- 当前默认值：
  `true`，会输出 `0~359` 度、每 `1` 度一张、共 `360` 张图。
- 重要区别：
  这不是把图片旋转，而是每次重新计算 helical 相位和总 SLM 相位。
- 输出位置：
  默认写入 `Bessel-Simulation/outputs/SLM_phase_helical_offset_0_to_359/`。

#### `helicalOffsetStartDeg`

- 含义：批量扫描 `helicalPhaseOffset` 的起始角度，单位度。
- 当前默认值：
  `0`。

#### `helicalOffsetEndDeg`

- 含义：批量扫描 `helicalPhaseOffset` 的结束角度，单位度。
- 当前默认值：
  `359`。

#### `helicalOffsetStepDeg`

- 含义：批量扫描 `helicalPhaseOffset` 的角度步长，单位度。
- 当前默认值：
  `1`。
- 注意：
  不要设成 `0`。

#### `helicalOffsetSlmSubfolder`

- 含义：`helicalPhaseOffset` 批量 SLM 图保存到 `outputs` 下的哪个子文件夹。
- 当前默认值：
  `SLM_phase_helical_offset_0_to_359`。

#### `writeRotatedSlmBatch`

- 含义：是否几何旋转已经生成好的 SLM bitmap。
- 当前默认值：
  `false`。
- 建议：
  当前物理扫描不需要它，通常保持关闭。

#### `plotFigures`

- 含义：是否画图。
- `true`：
  运行后会弹出 figure。
- `false`：
  适合批量扫参或做 smoke test。

#### `cropHalfWidthPixels`

- 含义：导出 3D 强度 tif 时，从中心向四周各取多少像素。
- 调大后：
  导出的视野更大。
- 调小后：
  导出的视野更聚焦中心。
- 常见风险：
  设得太大可能接近整幅图；设得太小可能把边缘结构裁掉。

#### `referenceSliceIndex`

- 含义：后处理功率密度归一化时所用的参考 z 切片编号。
- 调大后：
  用更靠后的 z 面做归一化。
- 调小后：
  用更靠前的 z 面做归一化。
- 注意：
  这会改变功率密度估算的绝对值标尺，但不改变相对形状。有限孔径时，归一化系数会额外乘以 aperture transmission，不会把被挡掉的功率补回。

#### `outputDir`

- 含义：输出目录。
- 默认行为：
  脚本会自动把它设为 `Bessel-Simulation/outputs/`。
- 一般不建议手动改：
  除非你明确知道想把输出重定向到别的地方。

#### `printProgress`

- 含义：是否在 MATLAB/VS Code 终端里打印 BPM 运行进度。
- 默认值：
  `true`，也就是默认会打印。
- 适合场景：
  在 VS Code 里运行时，用它确认程序不是卡死，而是在继续传播。

#### `progressIntervalSeconds`

- 含义：每隔多少秒打印一次进度。
- 调大后：
  输出更少，终端更干净。
- 调小后：
  输出更频繁，更容易确认程序还在跑。
- 建议：
  默认 `5` 秒比较折中；如果你想更频繁，可以设成 `1` 或 `2`。

#### `writeProgressLog`

- 含义：是否把进度同步写入 log 文件。
- 默认值：
  `true`。
- 适合场景：
  如果 VS Code 终端看不到实时输出，可以打开 `outputs/BPM_drill_AI_progress.log` 看进度。

#### `progressLogFile`

- 含义：进度日志文件路径。
- 默认行为：
  留空时自动写到 `Bessel-Simulation/outputs/BPM_drill_AI_progress.log`。
- 一般不需要改：
  除非你想把日志写到别的目录。

## 常见调参思路

### 只想快速改光束形状

优先改：

- `vortexCharge`
- `helicalGamma`
- `helicalOrder`
- `omegaInner`
- `omegaOuter`
- `checkerboardBesselEnabled`
- `checkerboardTileSizePx`
- `checkerboardTc1` / `checkerboardTc2`
- `checkerboardBeta1Deg` / `checkerboardBeta2Deg`
- `axiconMode`
- `axiconConeAngleDeg` / `axiconRadialPeriodMm` / `axiconRadialPeriodPx` / `axiconRadialCycles`

### 只想让仿真快一点

优先改：

- 减小 `N`
- 减小 `zRangeMm`
- 增大 `dzMm`
- 关闭 `plotFigures`
- 关闭不必要的导出开关

### 只想检查相位而不关心传播

建议：

- `useBPM = false`
- `plotFigures = true`
- `writeAllPhase = true`

### 只想批量导出 helicalPhaseOffset 扫描 SLM 图

建议：

- `writeHelicalOffsetSlmBatch = true`
- `helicalOffsetStartDeg = 0`
- `helicalOffsetEndDeg = 359`
- `helicalOffsetStepDeg = 1`
- 如果不需要看传播结果，可以临时设 `useBPM = false` 加快运行。

### 只想看 helical 相位文件

建议：

- `writeHelicalPhase = true`
- 其他导出先关掉

## 改参数时的经验提醒

- 一次只改 1 到 2 个核心参数，比较容易看懂哪个参数导致了变化。
- 改 `N` 时，最好同时想一想 `sizeMm`，因为这两个一起决定横向采样精度。
- 改 `zRangeMm` 时，最好同时看 `dzMm`，因为它们一起决定 z 切片数量。
- 改阈值线位置时，只需要改 `damageThresholdWPerM2`，不用动绘图代码。
- 如果你发现结果“很奇怪”，先把 `helicalGamma=0`、`airyStrength=0`，退回到更简单的相位组合，再逐项加回来。

## 以后如果还要继续整理

下一步最值得继续做的通常有三件事：

1. 把功率密度标定从“参考切片归一化”改成更严格的物理标定。
2. 给 phase 部分单独做开关，让不同相位项可以更方便地独立启停。
3. 给常用参数做一个专门的 GUI 或配置文件，而不是每次都改脚本。
