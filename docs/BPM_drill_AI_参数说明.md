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
   这里决定输出光束长什么样，尤其是 `axiconMode` 及其当前主参数、`vortexCharge`、棋盘 Bessel vortex 参数、`helicalGamma`、`helicalOrder`、`omegaInner`、`omegaOuter`。
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

#### `N`

- 含义：横向采样点数，整个计算平面大小是 `N x N`。
- 调大后：
  横向分辨率更高，细节更清楚，频域采样也更细。
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

- 含义：BPM 每一步沿 z 推进的步长。
- 调大后：
  计算更快，但传播近似更粗。
- 调小后：
  传播更细致、更稳定，但计算更慢。
- 直接影响：
  z 方向采样精度和循环次数。
- 常见风险：
  步长过大时，传播误差会变明显。

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

- 含义：平均功率。
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

#### `axiconMode`

- 含义：选择 axicon 的主定义方式。
- 可选值：
  `coneAngle`、`radialPeriodMm`、`radialPeriodPx`、`radialCycles`、`physicalEquivalent`。
- 注意：
  程序内部会先把当前模式换算成统一的 `derived.axicon.krRadPerMm` 和
  `derived.axicon.coneAngleDeg`，后续相位和传播距离只使用这两个等效量。
  因此多个 axicon 输入参数不会同时生效，只有当前模式对应的参数是主输入。
  在 APP 里，未选中的 axicon 输入框会作为只读等效值随当前主输入自动刷新。

#### `axiconConeAngleDeg`

- 含义：SLM 全息 axicon 的有效出射锥角 `beta`，单位度。
- 生效条件：
  `axiconMode = 'coneAngle'`。
- 调大后：
  径向相位斜率变大，理论最大无衍射距离会缩短。

#### `axiconRadialPeriodMm`

- 含义：SLM 径向 `2*pi` 相位周期，单位 mm。
- 生效条件：
  `axiconMode = 'radialPeriodMm'`。
- 调小后：
  径向相位斜率变大，等效锥角变大。

#### `axiconRadialPeriodPx`

- 含义：SLM 径向 `2*pi` 相位周期，单位为当前输出相位矩阵的像素。
- 生效条件：
  `axiconMode = 'radialPeriodPx'`。
- 注意：
  这里的 1 pixel 对应 `simulation.sizeMm / simulation.N` mm。
  如果改变 `N` 或 `sizeMm`，同一个像素周期对应的物理周期也会变化。

#### `axiconRadialCycles`

- 含义：从光轴中心到归一化半径 `rho = 1` 处的 axicon 径向 `2*pi` 相位周期数。
- 生效条件：
  `axiconMode = 'radialCycles'`。
- 换算关系：
  令 `R = simulation.sizeMm / 2`，则
  `axiconRadialPeriodMm = R / axiconRadialCycles`，
  `k_r = 2*pi*axiconRadialCycles/R`。
- 例子：
  默认 `sizeMm = 8.64 mm` 时，`R = 4.32 mm`；如果 `axiconRadialCycles = 20`，
  则中心到边缘共有 20 个径向周期，每个周期 `4.32/20 = 0.216 mm`。

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
  第二片透镜位置是基于它再加 `f1 + f2` 自动算出来的。

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
  这会改变功率密度估算的绝对值标尺，但不改变相对形状。

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
