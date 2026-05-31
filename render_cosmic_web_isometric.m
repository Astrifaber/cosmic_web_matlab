%% render_cosmic_web_isometric.m
% 从 MATLAB 工作区读取 x,y,z 点云向量
% 渲染为宇宙网等轴侧视图（isometric view）
%
% 要求：
% 工作区必须已有变量：
%   x   2097152x1 double
%   y   2097152x1 double
%   z   2097152x1 double
%
% 输出特点：
% 1. 每个点视为微弱发光体
% 2. 点密集的纤维/节点自动更亮
% 3. 考虑深度遮挡：近处更亮，远处更暗
% 4. 对高亮节点做 HDR 压缩，避免过曝
% 5. 输出紫-橙-白色调，接近宇宙网参考风格
load("D:\Cosmoscraft\cosmic_web_matlab\matlab.mat");

%% ========================= 用户参数区 =========================

outFile = 'cosmic_web_isometric_tuned.png';

Nxy = 520;
Nz  = 380;

sigmaVox = 0.58;

rhoCap    = 12.0;
emitLogK  = 42.0;
tau       = 0.32;
depthBeta = 0.18;

glowSigma  = 0.70;
glowAmount = 0.12;

clipLo   = 0.005;
clipHi   = 99.985;
toneK    = 12.0;
gammaOut = 0.62;

cropThresh = 0.0025;
cropMargin = 0.03;

flipDepth = false;
showFigure = true;

%% =============================================================

%% =============================================================

fprintf('Reading x, y, z from base workspace...\n');

% 从 base workspace 读取变量
x = evalin('base', 'x');
y = evalin('base', 'y');
z = evalin('base', 'z');

% 基本检查
assert(isnumeric(x) && isvector(x), '工作区变量 x 必须是数值向量。');
assert(isnumeric(y) && isvector(y), '工作区变量 y 必须是数值向量。');
assert(isnumeric(z) && isvector(z), '工作区变量 z 必须是数值向量。');

x = x(:);
y = y(:);
z = z(:);

assert(numel(x) == numel(y) && numel(y) == numel(z), ...
    'x, y, z 三个向量长度必须一致。');

fprintf('Point count = %d\n', numel(x));

% 去除 NaN / Inf
mask = isfinite(x) & isfinite(y) & isfinite(z);
x = x(mask);
y = y(mask);
z = z(mask);

% 降内存：转换为 single
x = single(x);
y = single(y);
z = single(z);

fprintf('Valid point count after filtering = %d\n', numel(x));

%% 1) 归一化到立方体中心，保持各向同性
fprintf('Normalizing coordinates...\n');

xmin = min(x); xmax = max(x);
ymin = min(y); ymax = max(y);
zmin = min(z); zmax = max(z);

cx = 0.5 * (xmin + xmax);
cy = 0.5 * (ymin + ymax);
cz = 0.5 * (zmin + zmax);

sx = xmax - xmin;
sy = ymax - ymin;
sz = zmax - zmin;
s  = max([sx, sy, sz]);

if s <= 0
    error('点云空间尺寸为 0，无法渲染。');
end

x = (x - cx) / s;
y = (y - cy) / s;
z = (z - cz) / s;

%% 2) 等轴侧视图（isometric view）相机坐标
fprintf('Rotating to isometric camera coordinates...\n');

% 经典等轴视图对应视线方向约 [1,1,1]
look = unitvec([1, 1, 1]);
up0  = [0, 0, 1];

right = unitvec(cross(up0, look));
up    = unitvec(cross(look, right));

% 投影到相机坐标系：u,v 为屏幕坐标；w 为深度
u = x * right(1) + y * right(2) + z * right(3);
v = x * up(1)    + y * up(2)    + z * up(3);
w = x * look(1)  + y * look(2)  + z * look(3);

clear x y z;

%% 3) 点云离散到 3D 体素
fprintf('Voxelizing point cloud...\n');

pad = 0.02;  % 给边缘留一点空白

umin = min(u); umax = max(u);
vmin = min(v); vmax = max(v);
wmin = min(w); wmax = max(w);

du = umax - umin;
dv = vmax - vmin;
dw = wmax - wmin;

umin = umin - pad * du; umax = umax + pad * du;
vmin = vmin - pad * dv; vmax = vmax + pad * dv;
wmin = wmin - pad * dw; wmax = wmax + pad * dw;

iu = 1 + floor((u - umin) ./ max(eps('single'), (umax - umin)) * (Nxy - 1));
iv = 1 + floor((v - vmin) ./ max(eps('single'), (vmax - vmin)) * (Nxy - 1));
iw = 1 + floor((w - wmin) ./ max(eps('single'), (wmax - wmin)) * (Nz  - 1));

valid = (iu >= 1 & iu <= Nxy & iv >= 1 & iv <= Nxy & iw >= 1 & iw <= Nz);

iu = iu(valid);
iv = iv(valid);
iw = iw(valid);

subs = [double(iv), double(iu), double(iw)];
vol  = accumarray(subs, 1, [Nxy, Nxy, Nz], @sum, 0);
vol  = single(vol);

clear u v w iu iv iw subs valid;

%% 4) 3D 高斯平滑
fprintf('Applying 3D Gaussian smoothing...\n');
vol = gaussblur3(vol, sigmaVox);

%% 5) 鲁棒归一化，避免极亮节点过曝
fprintf('Robust density normalization...\n');

p999 = sample_percentile(vol, 99.90, 500000);
if p999 <= 0
    error('体素密度全为 0，无法渲染。');
end

rho = vol / p999;
rho = min(rho, rhoCap);

clear vol;

%% 6) 定义发光与吸收
fprintf('Computing emissive and absorption fields...\n');

% 发光：强调暗弱纤维，又抑制极亮节点
emit = log1p(emitLogK * rho) / log1p(emitLogK * rhoCap);

% 吸收：密度越高，越遮挡后方
alpha = 1 - exp(-tau * rho);

clear rho;

%% 7) 前向体渲染（front-to-back compositing）
fprintf('Ray marching...\n');

I = zeros(Nxy, Nxy, 'single');   % 最终亮度
T = ones(Nxy, Nxy, 'single');    % 剩余透过率

% 深度权重：近亮远暗
depthWeight = exp(-depthBeta * linspace(0, 1, Nz));

if flipDepth
    kList = Nz:-1:1;
else
    kList = 1:Nz;
end

for kk = 1:Nz
    k = kList(kk);

    E = emit(:,:,k);
    A = alpha(:,:,k);

    sliceColor = depthWeight(kk) .* E;

    % 发光-吸收模型
    I = I + T .* A .* sliceColor;
    T = T .* (1 - A);
end

clear emit alpha T;

%% 8) 添加 2D glow
fprintf('Adding 2D glow...\n');

glow = gaussblur2(I, glowSigma);
I = I + glowAmount * glow;

clear glow;

%% 9) Tone mapping
fprintf('Applying tone mapping...\n');

lo = sample_percentile(I, clipLo, 200000);
hi = sample_percentile(I, clipHi, 200000);

if hi <= lo
    hi = max(I(:));
    lo = min(I(:));
end

I = (I - lo) ./ max(eps('single'), (hi - lo));
I = min(max(I, 0), 1);

I = asinh(toneK * I) / asinh(toneK);
I = I .^ gammaOut;

%% 10) 自动裁边
fprintf('Auto cropping...\n');
[I, ~] = crop_image_by_threshold(I, cropThresh, cropMargin);

%% 11) 放大输出
I = imresize(I, [outSize, outSize], 'bicubic');

%% 12) 伪彩色映射：黑 -> 紫 -> 橙 -> 白
fprintf('Applying cosmic colormap...\n');
cmap = cosmic_colormap(1024);
RGB = apply_colormap(I, cmap);

%% 13) 保存与显示
fprintf('Saving image...\n');
imwrite(RGB, outFile);

if showFigure
    figure('Color', 'k', 'Name', 'Cosmic Web Isometric Render');
    image(RGB);
    axis image off;
    title('Cosmic Web Isometric Render', 'Color', 'w');
end

fprintf('Done. Output saved to: %s\n', outFile);

%% ========================= 局部函数 =========================

function v = unitvec(v)
    v = double(v(:).');
    n = sqrt(sum(v.^2));
    if n < eps
        error('零向量无法归一化。');
    end
    v = v / n;
end

function out = gaussblur3(vol, sigma)
    if sigma <= 0
        out = vol;
        return;
    end
    g = gaussian_kernel_1d(sigma);
    out = convn(vol, reshape(g, [], 1, 1), 'same');
    out = convn(out, reshape(g, 1, [], 1), 'same');
    out = convn(out, reshape(g, 1, 1, []), 'same');
end

function out = gaussblur2(img, sigma)
    if sigma <= 0
        out = img;
        return;
    end
    g = gaussian_kernel_1d(sigma);
    out = convn(img, reshape(g, [], 1), 'same');
    out = convn(out, reshape(g, 1, []), 'same');
end

function g = gaussian_kernel_1d(sigma)
    rad = max(1, ceil(3 * sigma));
    x = -rad:rad;
    g = exp(-(x.^2) / (2 * sigma^2));
    g = single(g / sum(g));
end

function p = sample_percentile(A, pct, maxSamples)
    x = A(:);
    x = x(isfinite(x));

    n = numel(x);
    if n == 0
        p = 0;
        return;
    end

    if n > maxSamples
        idx = randperm(n, maxSamples);
        x = x(idx);
    end

    x = sort(double(x));
    k = round((pct / 100) * numel(x));
    k = max(1, min(numel(x), k));
    p = x(k);
end

function [Ic, bbox] = crop_image_by_threshold(I, thr, marginRatio)
    mask = I > thr;
    [yy, xx] = find(mask);

    h = size(I,1);
    w = size(I,2);

    if isempty(xx)
        Ic = I;
        bbox = [1, 1, w, h];
        return;
    end

    x1 = min(xx); x2 = max(xx);
    y1 = min(yy); y2 = max(yy);

    bw = x2 - x1 + 1;
    bh = y2 - y1 + 1;
    mg = round(max(bw, bh) * marginRatio);

    x1 = max(1, x1 - mg);
    x2 = min(w, x2 + mg);
    y1 = max(1, y1 - mg);
    y2 = min(h, y2 + mg);

    Ic = I(y1:y2, x1:x2);
    bbox = [x1, y1, x2 - x1 + 1, y2 - y1 + 1];
end

function cmap = cosmic_colormap(N)
    % 更接近参考图：黑 -> 深蓝紫 -> 紫红 -> 橙粉 -> 少量金白
    % 重点：把橙黄和白色推到更高亮度区间，避免大面积黄白过曝。

    x = [
        0.00
        0.08
        0.20
        0.38
        0.58
        0.76
        0.90
        0.975
        1.00
    ];

    anchors = [
        0.00, 0.00, 0.00
        0.02, 0.00, 0.08
        0.07, 0.02, 0.20
        0.18, 0.04, 0.42
        0.42, 0.08, 0.68
        0.72, 0.20, 0.62
        0.95, 0.42, 0.25
        1.00, 0.82, 0.42
        1.00, 1.00, 0.92
    ];

    xi = linspace(0, 1, N);

    cmap = zeros(N, 3, 'single');
    for c = 1:3
        cmap(:, c) = single(interp1(x, anchors(:, c), xi, 'pchip'));
    end

    cmap = min(max(cmap, 0), 1);
end

function RGB = apply_colormap(I, cmap)
    I = min(max(I, 0), 1);
    n = size(cmap, 1);

    idx = 1 + floor(I * (n - 1));
    idx = min(max(idx, 1), n);

    RGB = zeros([size(I), 3], 'single');
    for c = 1:3
        tmp = cmap(idx(:), c);
        RGB(:,:,c) = reshape(tmp, size(I));
    end
end