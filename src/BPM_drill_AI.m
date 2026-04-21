clear all
tic
% 仿真参数 Simulation parameters
N = 1081;        % pixel number（NxN）  (我们的SLM参数，N=1080，Size=8,对应pixel size=8um)
Size=8.64;       % real size unit in mm
z_range=400; % 光场沿z方向传播距离 mm
dz=2; % z方向计算步长 mm
n0=1; % background refractive index, in air=1
nm=1.7551; % 1.7551 sapphire
% 算法选择  Algorithm
BPM=1;
GPU=0;
% 文件输出 Files Output
output_3D=1;
output_all_phase=1;
output_helical_phase=0;
script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(script_dir);
output_dir = fullfile(repo_root, 'outputs');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% 激光参数 Laser parameters
L=double(1.029e-3);     % wavelength in mm
k=2*pi*n0/L; % 真空波数 unit in mm-1
km=2*pi*nm/L;
Power=20; %Laser power unit in W
Frequency=100e3; % Repetition rate unit in Hz
Pulse_w=275e-15; % Pulse width unit in s
Pulse_e=Power/Frequency; % Pulse energy unit in J
Pulse_peakpower=Pulse_e/Pulse_w; % Pulse peak power
% Assume pusle has square shape on the time domain unit in W
R_beam=0.03; %unit in cm
S_beam=pi*R_beam^2; %unit in m^2
I_beam=Pulse_peakpower/S_beam; % unit in W/mm^2

% 正空间坐标 real space coordinate
[x, y] = meshgrid(linspace(-Size/2,Size/2,N), linspace(-Size/2,Size/2,N));
[theta, r] = cart2pol(x, y);
dx=Size/N; %像素间距 mm/pixel
dy=dx;

% 倒空间坐标 reciprocal space coordinate
fSize=N/Size; % 倒空间总尺寸 mm-1
dfx=1/Size; % 像素间距 mm-1/pixel
dfy=dfx;
[fx, fy] = meshgrid(linspace(-fSize/2,fSize/2,N), linspace(-fSize/2,fSize/2,N));
kx=2*pi*fx;% 波矢分量 rad/mm
ky=2*pi*fy;

% 构造高斯光
w0 = 3.85/2;        % waist radius
E0=1;%% 构造相位

% 构造 Airy beam
airy_strength = 0; % 立方相位调制深度 (无量纲系数)
w1=2;
phase_airy = airy_strength * ( (x./w1).^3 + (y./w1).^3 );

% 构造锥透镜相位
 n_ax=1.4287; % 锥透镜折射率 CaF2 at 1029 nm
%  alpha_d=0.5; % 锥透镜底角 unit in degree
%  alpha=deg2rad(alpha_d); % unit in rad
% tau_d=180-2*alpha_d; % 锥透镜顶角 unit in degree
% tau=deg2rad(tau_d); % unit in rad
% %phase_axicon=-k*(n-1)*(180/pi)*alpha*r; %锥透镜相位
% phase_axicon=k*(n_ax-1)*tand(alpha_d)*(Size/2-r); %锥透镜相位
E_G = E0*exp(-r.^2/w0^2);  % 电场高斯包络 （real)

% 构造锥透镜相位
alpha_d=0.4;
alpha=deg2rad(alpha_d); % unit in rad
phase_axicon=k*tand(alpha_d)*(-r);

% --- 开始魔改：生成弯曲 Bessel 相位 (Curved Bessel Phase) ---

% 1. 计算 Bessel 光束理论上的最大无衍射距离 (Geometrical limit)
% 根据几何关系，最大半径 (Size/2) 对应的聚焦位置
z_max_bessel = (Size/2) / tand(alpha_d); 

% 2. 定义弯曲参数：你希望光束在 z_max_bessel 处横向偏移多少 mm？
% 正值向 x 正方向弯曲，负值向 x 负方向弯曲
max_shift = 0; % 例如：在光束末端偏移 0.5 mm

% 3. 反推曲率系数 A (假设抛物线轨迹 x = A * z^2)
% 因为 shift = A * z^2，所以 A = shift / z^2
curvature_A = max_shift / (z_max_bessel^2);

% 4. 生成弯曲相位 phase_curve
% 公式原理：phi = k_transverse * x
% 其中 k_transverse 随半径 r 线性增加，导致焦点偏移随 z 平方增加
% 这里的 tand(alpha_d) 直接使用了你之前定义的角度
phase_curve = k * curvature_A * (r ./ tand(alpha_d)) .* (x);

% --- 结束魔改 ---

% 构造锥透镜补偿相位，为了产生平顶Bessel
phase_comp=0;

% 构造螺旋相位
lc = 1;               % 涡旋阶数（拓扑荷数 topological charge）
phase_vortex = lc*theta;     % 螺旋相位  (real)

%构造空间螺旋相位
gamma = 1;    % 决定横向偏离角度 (Phase modulation depth)
m = 1;        % 决定有几根螺旋 (Angular spatial frequency)
phi = 0;      % 初始相位
% 定义周期变化参数 (Chirp parameters)
omega_inner = 20; % r = 0 (中心) 处的频率参数
omega_outer = 20; % r = Size/2 (边缘) 处的频率参数
% 计算归一化半径 rho (范围约为 0~1.414)
% 注意：这里定义 r/(Size/2) 为归一化单位，对应你之前代码中的 (2/Size)*r
rho = r ./ (Size/2); 
% 构造径向啁啾相位 (Radial Chirp Phase)
% 原理：瞬时频率 f(r) 线性增加 => 相位 phi(r) 是 r 的二次函数
% 公式：phi = 2*pi * (w_start * rho + 0.5 * (w_end - w_start) * rho.^2)
phase_radial_chirp = 2 * pi * (omega_inner .* rho + 0.5 * (omega_outer - omega_inner) .* rho.^2);
% 生成最终的螺旋相位
phase_helical = gamma * cos(m*theta - phase_radial_chirp + phi);

% 总相位
phase_all=phase_axicon+phase_airy+phase_vortex+phase_helical+phase_comp+phase_curve;
%% test

% airy_strength = 10; % 立方相位调制深度 (无量纲系数)
% w1=4;
% phase_test_o = airy_strength * ( (x./w1).^3 + (y./w1).^3 );
% phase_test=angle(exp(1i*phase_test_o));
% figure(3)
% imshow(phase_test)

%% 透镜缩放
f1=200; % focal length unit in mm
f2=30; % focal length unit in mm
M=f2/f1; % magnification
%beta_0=asin((n_ax/n0)*cos(tau/2))+(tau-pi)/2;
%beta_0=((n_ax-n0)/n0)*((pi-tau)/2);
beta_0=n_ax*sin(alpha)-alpha;
beta_0d=rad2deg(beta_0);
%beta_1=asin(sin(beta_0)/M);
beta_1=atan(tan(beta_0)*f1/f2);
beta_1d=rad2deg(beta_1);
beta_m=asin((n0/nm)*sin(beta_1));
beta_md=rad2deg(beta_m);
z_f=w0/(2*tan(beta_0));% 约等于，只有在底角Alpha比较小的时候成立
delta_z=0.8*2*z_f;
delta_zm=M^2*delta_z;
%%
% 构造初始复振幅
E=E_G.*exp(1i*(phase_all)); %复振幅 (complex)
if GPU==1
    E=gpuArray(E);
end
% 傅里叶变换获得角频谱
F_o=fft2(E);
F=fftshift(F_o);
%% BPM 主循环
if BPM==1
    E_z_BPM=E;
    H_step=exp(1i*dz*sqrt(k^2-kx.^2-ky.^2));% 构造步进传播算子
    Lens1=exp(-1i*k/(2*f1)*r.^2);
    Lens2=exp(-1i*k/(2*f2)*r.^2);
    Lens1_position_o=550;
    Lens2_position_o=Lens1_position_o+f1+f2;
    Sample_position_o=Lens2_position_o+20;
    Lens1_flag=0;% 1的话就是加上镜子
    Lens2_flag=0;
    Sample_flag=0;

    z_values = 0:dz:z_range;
    E_3D_BPM = zeros(N, N, numel(z_values), 'like', E_z_BPM);
    i=1;
    for z=z_values
        if z>=Lens1_position_o && Lens1_flag==1
            E_z_BPM=E_z_BPM.*Lens1; % 加上透镜
            Lens1_flag=0;
            Lens1_position=z;
        end
        if z>=Lens2_position_o && Lens2_flag==1
            E_z_BPM=E_z_BPM.*Lens2; % 加上透镜
            Lens2_flag=0;
            Lens2_position=z;
        end
        if z>=Sample_position_o && Sample_flag==1
            H_step = exp(1i*dz*sqrt(km^2 - kx.^2 - ky.^2));%改变传播因子
            Sample_flag=0;
            Sample_position=z;
        end

        F_step=fftshift(fft2(E_z_BPM));% 傅里叶变换获得角频谱
        F_z_step=F_step.*H_step; % 传播后的角频谱
        E_z_BPM=ifft2(ifftshift(F_z_step));% 傅里叶逆变换获得传播后的复振幅分布

        E_3D_BPM(:,:,i)= E_z_BPM;% BPM计算得到的空间场分布
        i=i+1;
        z
    end
end
%% 图片亮度到实际光功率的换算
%
I_3D_temp=abs(E_3D_BPM(:,:,30)).^2;
sum_intensity=sum(sum(I_3D_temp));
imge_pixel_power=1/sum_intensity;
%假设图片中总光强为1W，且为CW光,每图片中的一个亮度对应的光强 unit in W
pixel_size=(Size/N)^2; % pixel area unit in mm^2
imge_pixel_power_density=imge_pixel_power/pixel_size; % 亮度对应的功率密度 W/mm^2
I_threshold=7.2e11; % intensity threshold for sappire, W/m^2
%figure(3)
%imshow(I_3D_temp,[]);
%}
%% Plot
figure(1)
tiledlayout(2, 3, 'Padding', 'none', 'TileSpacing', 'compact');

nexttile;
imshow(angle(E),[])
title('Phase on SLM (angle(E)) ')
colorbar;

nexttile;
imshow(abs(E).^2,[])
title('input beam (|E|^2) ')
colorbar;

nexttile;
imshow(abs(F).^2,[])
title('Angular spectrum (|F|^2)')
colorbar;

nexttile;
imshow(phase_helical,[])
title('phase helical')
colorbar;

nexttile;
imshow(angle(exp(1i*phase_axicon)),[])
title('phase axicon')
colorbar;

nexttile;
imshow(angle(exp(1i*phase_vortex)),[])
title('phase vortex')
colorbar;
%% Show cross-section
figure(2)
tiledlayout(3, 1, 'Padding', 'none', 'TileSpacing', 'compact');

% BPM
mid_slice=floor(size(E_3D_BPM,1)/2); % 剖面位置
y_img=linspace(-Size/2,Size/2,N); % mm
z_img=linspace(0,z_range,size(E_3D_BPM,3)); % mm
img_BPM=squeeze(abs(E_3D_BPM(mid_slice,:,:))).^2;% 光强 E^2
img_BPM_powerdensity=img_BPM.*imge_pixel_power_density; % 功率密度 W/mm^2
img_BPM_peak_powerdensity=img_BPM_powerdensity*Pulse_peakpower; % 功率密度 W/mm^2
img_BPM_log=log(1+(img_BPM));% log 光强
img_BPM_peak_powerdensity_log=log(1+(img_BPM_peak_powerdensity));% log 光强

nexttile;
imagesc(z_img, y_img, img_BPM_peak_powerdensity_log);
title('Power density W/mm^2 log scale (FFT-BPM algorithm)')
colorbar;
xline(Lens1_position_o, 'Color', 'r')
xline(Lens2_position_o, 'Color', 'r')
xline(Sample_position_o, 'Color', 'w')
axis on;
xlabel('z (mm)');
ylabel('y (mm)');

nexttile;
imagesc(z_img, y_img, img_BPM_peak_powerdensity);
title('Power density W/mm^2 (FFT-BPM algorithm)')
colorbar;
xline(Lens1_position_o, 'Color', 'r')
xline(Lens2_position_o, 'Color', 'r')
xline(Sample_position_o, 'Color', 'w')
axis on;
xlabel('z (mm)');
ylabel('y (mm)');

nexttile;
peak_power_density=max(img_BPM_peak_powerdensity(mid_slice,:));
plot(img_BPM_peak_powerdensity(mid_slice,:))
hold on
yline(7.2e11, 'Color', 'r')
axis([0 size(img_BPM_peak_powerdensity,2) 0 peak_power_density*1.5])
title('Power density on axis W/mm^2 (FFT-BPM algorithm)')
%%
%{
phase_raw = angle(E);         % 初始相位（存在跳跃）
phase_unwrapped_x = unwrap(phase_raw, [], 2);  % 沿 x 方向展开
phase_unwrapped = unwrap(phase_unwrapped_x, [], 1);  % 再沿 y 方向展开

figure (3)
imagesc(phase_unwrapped)
axis image
colorbar
title('Unwrapped phase')
%}
%% 输出光束3D强度为TIFF文件
%
if output_3D==1
% 准备8-bit图像
I_3D_intensity=abs(E_3D_BPM).^2;
I_3D_intensity_norm = I_3D_intensity - min(I_3D_intensity(:));
I_3D_intensity_norm = I_3D_intensity_norm / max(I_3D_intensity_norm(:));
I_3D_intensity_8bit=uint8(I_3D_intensity_norm*255);

% 保存为.TTIF
filename = fullfile(output_dir, ['Drill Beam 3D ',...
    num2str(Size),'x',num2str(Size),'x',num2str(z_range),' mm ',...
    'alpha=',num2str(alpha_d),...
    ' lc=',num2str(lc),...
    ' gamma=',num2str(gamma),...
    ' m=',num2str(m),...
    ' omega=',num2str(omega_inner),...
    ' w=',num2str(w0),...
    '.tif']);

for i = 1:size(I_3D_intensity_8bit, 3)
    slice = squeeze(I_3D_intensity_8bit(round(size(I_3D_intensity_8bit,1)/2)-100:round(size(I_3D_intensity_8bit,1)/2)+100, round(size(I_3D_intensity_8bit,1)/2)-100:round(size(I_3D_intensity_8bit,2)/2)+100, i));  % z = k 平面
    if i == 1
        imwrite(slice, filename);
    else
        imwrite(slice, filename, 'WriteMode', 'append');
    end
end
%}
end
%% 输出SLM相位为TIFF文件
%
if output_all_phase==1
% 计算 SLM 相位（范围 [-pi, pi]）
SLM_phase = angle(E);   % E 是你构造的入射场

% 如果上面用了 GPU，可以保险一点先 gather 一下：
% SLM_phase = angle(gather(E));

% 映射到 [0, 1]：[-pi, pi] -> [0, 1]
SLM_phase_norm = (SLM_phase + pi) / (2*pi);

% 映射到 [0, 255] 并转成 uint8
SLM_phase_8bit = uint8(SLM_phase_norm * 255);

% 生成文件名（你可以按需改短一点）
filename_slm = fullfile(output_dir, ['Drill Beam SLM phase ', ...
    num2str(Size),'x',num2str(Size),' mm ', ...
    'alpha=',num2str(alpha_d), ...
    ' lc=',num2str(lc), ...
    ' gamma=',num2str(gamma), ...
    ' m=',num2str(m), ...
    ' omega=',num2str(omega_inner), ...
    ' w=',num2str(w0), ...
    '.bmp']);

% 保存为单张 8-bit 灰度 tiff
imwrite(SLM_phase_8bit, filename_slm);
end

%% 单独输出Helical相位为TIFF文件

if output_helical_phase==1

% 映射到 [0, 1]：[-pi, pi] -> [0, 1]
phase_helical_norm = (phase_helical + pi) / (2*pi);

% 映射到 [0, 255] 并转成 uint8
phase_helical_8bit = uint8(phase_helical_norm * 255);

% 生成文件名（你可以按需改短一点）
filename_slm = fullfile(output_dir, ['Drill Beam Helical phase ', ...
    num2str(Size),'x',num2str(Size),' mm ', ...
    'alpha=',num2str(alpha_d), ...
    ' lc=',num2str(lc), ...
    ' gamma=',num2str(gamma), ...
    ' m=',num2str(m), ...
    ' omega=',num2str(omega_inner), ...
    ' w=',num2str(w0), ...
    '.bmp']);

% 保存为单张 8-bit 灰度 tiff
imwrite(phase_helical_8bit, filename_slm);
end
%}
toc
