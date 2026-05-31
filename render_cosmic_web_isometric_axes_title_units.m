%% render_cosmic_web_isometric_axes_title_units.m
% 从 MATLAB 工作区读取 x,y,z 点云向量，进行正交等轴侧体渲染，
% 并在最终 PNG 上叠加 3D 立方体坐标轴、刻度和坐标标签。
%
% 使用方式：
%   1) 确保工作区已有 x,y,z，或下面 dataMatFile 指向的 mat 文件可读取；
%   2) 运行：render_cosmic_web_isometric_axes_ortho
%
% 说明：
%   - 当前渲染投影是 orthographic / 正交投影：只使用相机基向量点乘，
%     不引入透视除法，所以不会出现近大远小。
%   - 坐标轴尺度自动判断：优先检查 params.Lbox / params.BoxSize 等字段；
%     若物理盒长与 x/y/z 原始数据跨度相近，则使用 params 的物理尺度；
%     否则退回到 x/y/z 原始坐标范围。你也可以用 axisSource 强制指定。

%% ========================= 数据文件，可按需修改 =========================
% 若该文件存在，脚本会先 load；若不存在，则直接使用当前工作区变量 x,y,z。
dataMatFile = "D:\Cosmoscraft\cosmic_web_matlab\matlab.mat";

if isfile(dataMatFile)
    fprintf('Loading workspace file: %s\n', dataMatFile);
    load(dataMatFile);
else
    fprintf('Data file not found, using current base workspace variables x,y,z.\n');
end

%% ========================= 用户参数区 =========================

outFile = 'cosmic_web_isometric_axes_title_units.png';

% ---------- 体渲染分辨率 ----------
Nxy = 520;
Nz  = 380;

% ---------- 体素平滑 ----------
sigmaVox = 0.58;

% ---------- 密度与发光控制 ----------
rhoCap    = 12.0;
emitLogK  = 42.0;
tau       = 0.32;
depthBeta = 0.18; %控制"近处更亮、远处更暗"的主参数

% ---------- 2D 发光晕 ----------
glowSigma  = 0.70;
glowAmount = 0.12;

% ---------- 最终 tone mapping ----------
clipLo   = 0.005;
clipHi   = 99.985;
toneK    = 12.0;
gammaOut = 0.62;

% ---------- 输出与裁边 ----------
outSize    = 1600;
cropThresh = 0.0025;
cropMargin = 0.03;

% 添加坐标轴后需要给刻度文字留边距，否则文字可能被裁掉
axisCropMargin = 0.08;

% ---------- 正交等轴相机 ----------
% 该方向决定等轴视线。默认 [1,1,1]。
cameraLookDirection = [1, 1, 1];
flipDepth = false;

% ---------- 坐标轴叠加 ----------
drawAxes      = true;
drawCubeFrame = true;

% axisSource:
%   'auto'       : 自动判断。若 params.Lbox 等字段可信，则使用物理尺度；否则用 x/y/z 原始坐标。
%   'data'       : 强制使用 x/y/z 原始坐标范围。
%   'paramsLbox' : 强制使用 params.Lbox / BoxSize / boxSize / L / Lbox 等字段作为 0 到 L 的坐标轴。
axisSource = 'auto';
axisUnitWhenParams = 'Mpc/h';
axisTickTargetCount = 7;

% MATLAB scatter3 风格坐标轴：细线、小字、无 X/Y/Z 大标签、无中心交叉轴。
axisStyle.axisColor       = [0.88, 0.88, 0.88];
axisStyle.frameColor      = [0.34, 0.38, 0.42];
axisStyle.textColor       = [0.92, 0.92, 0.92];
axisStyle.lineWidth       = 0.85;
axisStyle.frameLineWidth  = 0.55;
axisStyle.tickLengthPx    = 9;
axisStyle.fontSize        = 12;
axisStyle.labelFontSize   = 16;
axisStyle.infoFontSize    = 10;
axisStyle.fontName        = 'Helvetica';
axisStyle.showAxisLabels  = true;   % 现在显示带单位的 X/Y/Z 轴标签。
axisStyle.showScaleInfo   = false;
axisStyle.tickLabelGapPx  = 16;
axisStyle.axisLabelGapPx  = 40;
axisStyle.axisLabelFracXY = 0.58;
axisStyle.axisLabelFracZ  = 0.55;
axisStyle.axisLabelWeight = 'bold';
axisStyle.axisLabelColor  = [0.95, 0.95, 0.95];
axisStyle.rotateAxisLabel = true;
axisStyle.canvasPadLeft   = 90;
axisStyle.canvasPadRight  = 90;
axisStyle.canvasPadBottom = 90;
axisStyle.canvasPadTop    = 150;
axisStyle.titleText       = 'Cosmic Web Orthographic Projection';
axisStyle.titleFontSize   = 20;
axisStyle.titleWeight     = 'bold';
axisStyle.titleColor      = [0.96, 0.96, 0.96];

showFigure = true;

%% =============================================================

fprintf('Reading x, y, z from base workspace...\n');

assert(evalin('base', 'exist(''x'', ''var'')') == 1, '工作区中没有变量 x。');
assert(evalin('base', 'exist(''y'', ''var'')') == 1, '工作区中没有变量 y。');
assert(evalin('base', 'exist(''z'', ''var'')') == 1, '工作区中没有变量 z。');

x = evalin('base', 'x');
y = evalin('base', 'y');
z = evalin('base', 'z');

if evalin('base', 'exist(''params'', ''var'')') == 1
    params = evalin('base', 'params');
else
    params = struct();
end

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

%% 1) 原始坐标范围与坐标轴尺度判断
fprintf('Analyzing coordinate scale...\n');

xmin = min(x); xmax = max(x);
ymin = min(y); ymax = max(y);
zmin = min(z); zmax = max(z);

rawBoxMin = double([xmin, ymin, zmin]);
rawBoxMax = double([xmax, ymax, zmax]);
rawSpan   = rawBoxMax - rawBoxMin;

axisInfo = resolve_axis_info(axisSource, params, rawBoxMin, rawBoxMax, axisUnitWhenParams, axisTickTargetCount);

fprintf('Axis scale source = %s\n', axisInfo.sourceDescription);
fprintf('Axis display range: X [%.6g, %.6g], Y [%.6g, %.6g], Z [%.6g, %.6g] %s\n', ...
    axisInfo.displayMin(1), axisInfo.displayMax(1), ...
    axisInfo.displayMin(2), axisInfo.displayMax(2), ...
    axisInfo.displayMin(3), axisInfo.displayMax(3), axisInfo.unitText);

%% 2) 归一化到立方体中心，保持各向同性
fprintf('Normalizing coordinates...\n');

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

rawCenter = double([cx, cy, cz]);
rawScale  = double(s);

x = (x - cx) / s;
y = (y - cy) / s;
z = (z - cz) / s;

%% 3) 正交等轴相机坐标
fprintf('Projecting to orthographic isometric camera coordinates...\n');

look = unitvec(cameraLookDirection);
up0  = [0, 0, 1];

if norm(cross(up0, look)) < 1e-8
    up0 = [0, 1, 0];
end

right = unitvec(cross(up0, look));
up    = unitvec(cross(look, right));

% 正交投影：u,v,w 均为点乘结果。没有透视除法。
u = x * right(1) + y * right(2) + z * right(3);
v = x * up(1)    + y * up(2)    + z * up(3);
w = x * look(1)  + y * look(2)  + z * look(3);

% 坐标框角点也参与画布范围计算，防止后续坐标轴被裁掉
axisCornersRaw  = box_corners(axisInfo.rawBoxMin, axisInfo.rawBoxMax);
axisCornersNorm = raw_to_norm(axisCornersRaw, rawCenter, rawScale);
[axisCornerU, axisCornerV, axisCornerW] = project_norm_points(axisCornersNorm, right, up, look); %#ok<ASGLU>

clear x y z;

%% 4) 点云离散到 3D 体素
fprintf('Voxelizing point cloud...\n');

pad = 0.02;

uForBounds = [u; single(axisCornerU(:))];
vForBounds = [v; single(axisCornerV(:))];
wForBounds = [w; single(axisCornerW(:))];

umin = min(uForBounds); umax = max(uForBounds);
vmin = min(vForBounds); vmax = max(vForBounds);
wmin = min(wForBounds); wmax = max(wForBounds);

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

clear u v w iu iv iw subs valid uForBounds vForBounds wForBounds;

%% 5) 3D 高斯平滑
fprintf('Applying 3D Gaussian smoothing...\n');
vol = gaussblur3(vol, sigmaVox);

%% 6) 鲁棒归一化，避免极亮节点过曝
fprintf('Robust density normalization...\n');

p999 = sample_percentile(vol, 99.90, 500000);
if p999 <= 0
    error('体素密度全为 0，无法渲染。');
end

rho = vol / p999;
rho = min(rho, rhoCap);

clear vol;

%% 7) 发光与吸收
fprintf('Computing emissive and absorption fields...\n');

emit  = log1p(emitLogK * rho) / log1p(emitLogK * rhoCap);
alpha = 1 - exp(-tau * rho);

clear rho;

%% 8) 正交视线方向上的前向体渲染
fprintf('Ray marching...\n');

I = zeros(Nxy, Nxy, 'single');
T = ones(Nxy, Nxy, 'single');

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

    I = I + T .* A .* sliceColor;
    T = T .* (1 - A);
end

clear emit alpha T;

%% 9) 2D glow
fprintf('Adding 2D glow...\n');

glow = gaussblur2(I, glowSigma);
I = I + glowAmount * glow;

clear glow;

%% 10) Tone mapping
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

%% 11) 自动裁边：同时保留渲染主体和坐标框角点
fprintf('Auto cropping...\n');

axisCornerPixBase = project_raw_to_base_pixels(axisCornersRaw, rawCenter, rawScale, right, up, umin, umax, vmin, vmax, Nxy);

if drawAxes
    cropMarginUse = max(cropMargin, axisCropMargin);
    [I, cropBBox] = crop_image_by_threshold_and_points(I, cropThresh, cropMarginUse, ...
        axisCornerPixBase(:,1), axisCornerPixBase(:,2));
else
    [I, cropBBox] = crop_image_by_threshold(I, cropThresh, cropMargin);
end

%% 12) 放大输出与伪彩色映射
I = imresize(I, [outSize, outSize], 'bicubic');

fprintf('Applying cosmic colormap...\n');
cmap = cosmic_colormap(1024);
RGB = apply_colormap(I, cmap);

%% 13) 保存：可选择叠加坐标轴
fprintf('Saving image...\n');

camInfo.right = right;
camInfo.up    = up;
camInfo.look  = look;
camInfo.umin  = double(umin);
camInfo.umax  = double(umax);
camInfo.vmin  = double(vmin);
camInfo.vmax  = double(vmax);
camInfo.Nxy   = Nxy;
camInfo.cropBBox = cropBBox;
camInfo.outSize  = outSize;
camInfo.rawCenter = rawCenter;
camInfo.rawScale  = rawScale;

if drawAxes
    draw_axes_and_save(RGB, outFile, showFigure, axisInfo, camInfo, axisStyle, drawCubeFrame);
else
    imwrite(RGB, outFile);
    if showFigure
        figure('Color', 'k', 'Name', 'Cosmic Web Orthographic Isometric Render');
        image(RGB);
        axis image off;
        title('Cosmic Web Orthographic Isometric Render', 'Color', 'w');
    end
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

function Pn = raw_to_norm(Praw, center, scale)
    Pn = (double(Praw) - double(center)) ./ double(scale);
end

function [u, v, w] = project_norm_points(Pn, right, up, look)
    Pn = double(Pn);
    u = Pn * double(right(:));
    v = Pn * double(up(:));
    w = Pn * double(look(:));
end

function pix = project_raw_to_base_pixels(Praw, rawCenter, rawScale, right, up, umin, umax, vmin, vmax, Nxy)
    Pn = raw_to_norm(Praw, rawCenter, rawScale);
    [u, v, ~] = project_norm_points(Pn, right, up, [0 0 1]);
    col = 1 + (u - double(umin)) ./ max(eps, double(umax - umin)) * (Nxy - 1);
    row = 1 + (v - double(vmin)) ./ max(eps, double(vmax - vmin)) * (Nxy - 1);
    pix = [col(:), row(:)];
end

function pix = project_raw_to_final_pixels(Praw, camInfo)
    pixBase = project_raw_to_base_pixels(Praw, camInfo.rawCenter, camInfo.rawScale, ...
        camInfo.right, camInfo.up, camInfo.umin, camInfo.umax, camInfo.vmin, camInfo.vmax, camInfo.Nxy);

    x1 = camInfo.cropBBox(1);
    y1 = camInfo.cropBBox(2);
    cw = camInfo.cropBBox(3);
    ch = camInfo.cropBBox(4);

    col = ((pixBase(:,1) - x1) ./ max(eps, cw - 1)) * (camInfo.outSize - 1) + 1;
    row = ((pixBase(:,2) - y1) ./ max(eps, ch - 1)) * (camInfo.outSize - 1) + 1;

    pix = [col(:), row(:)];
end

function C = box_corners(boxMin, boxMax)
    boxMin = double(boxMin(:).');
    boxMax = double(boxMax(:).');
    C = [
        boxMin(1), boxMin(2), boxMin(3)
        boxMax(1), boxMin(2), boxMin(3)
        boxMin(1), boxMax(2), boxMin(3)
        boxMax(1), boxMax(2), boxMin(3)
        boxMin(1), boxMin(2), boxMax(3)
        boxMax(1), boxMin(2), boxMax(3)
        boxMin(1), boxMax(2), boxMax(3)
        boxMax(1), boxMax(2), boxMax(3)
    ];
end

function edges = box_edges()
    edges = [
        1 2; 1 3; 2 4; 3 4
        5 6; 5 7; 6 8; 7 8
        1 5; 2 6; 3 7; 4 8
    ];
end

function axisInfo = resolve_axis_info(axisSource, params, rawBoxMin, rawBoxMax, unitWhenParams, tickTargetCount)
    rawBoxMin = double(rawBoxMin(:).');
    rawBoxMax = double(rawBoxMax(:).');
    rawSpan = rawBoxMax - rawBoxMin;
    dataSpan = max(rawSpan);

    [hasLbox, Lbox, fieldName] = find_box_length_in_params(params);

    useParams = false;
    sourceDescription = 'x/y/z raw coordinate range';
    unitText = '';

    switch lower(string(axisSource))
        case "paramslbox"
            if hasLbox
                useParams = true;
            else
                warning('axisSource = paramsLbox，但 params 中没有可识别的 Lbox/BoxSize 字段，退回 x/y/z 原始坐标范围。');
            end
        case "data"
            useParams = false;
        otherwise
            if hasLbox && isfinite(Lbox) && Lbox > 0
                relDiff = abs(double(Lbox) - double(dataSpan)) / max(double(Lbox), double(dataSpan));
                if relDiff < 0.25
                    useParams = true;
                end
            end
    end

    axisInfo.rawBoxMin = rawBoxMin;
    axisInfo.rawBoxMax = rawBoxMax;

    if useParams
        axisInfo.displayMin = [0, 0, 0];
        axisInfo.displayMax = [double(Lbox), double(Lbox), double(Lbox)];
        unitText = unitWhenParams;
        sourceDescription = sprintf('params.%s = %.6g', fieldName, double(Lbox));
    else
        displayMin = rawBoxMin;
        displayMax = rawBoxMax;

        % 若原始坐标几乎从 0 开始，则把标签起点规整为 0。
        for d = 1:3
            if abs(displayMin(d)) < 0.03 * max(eps, rawSpan(d))
                displayMin(d) = 0;
            end
        end

        axisInfo.displayMin = displayMin;
        axisInfo.displayMax = displayMax;
    end

    axisInfo.unitText = unitText;
    axisInfo.sourceDescription = sourceDescription;

    axisInfo.ticks = cell(1,3);
    for d = 1:3
        axisInfo.ticks{d} = nice_ticks(axisInfo.displayMin(d), axisInfo.displayMax(d), tickTargetCount);
    end
end

function [hasLbox, Lbox, fieldName] = find_box_length_in_params(params)
    hasLbox = false;
    Lbox = NaN;
    fieldName = '';

    if ~isstruct(params)
        return;
    end

    candidates = {'Lbox', 'lbox', 'BoxSize', 'boxSize', 'boxsize', 'L', 'boxLength', 'box_length'};
    for i = 1:numel(candidates)
        f = candidates{i};
        if isfield(params, f)
            val = params.(f);
            if isnumeric(val) && isscalar(val) && isfinite(val) && val > 0
                hasLbox = true;
                Lbox = double(val);
                fieldName = f;
                return;
            end
        end
    end
end

function ticks = nice_ticks(a, b, targetCount)
    a = double(a);
    b = double(b);

    if ~isfinite(a) || ~isfinite(b) || a == b
        ticks = a;
        return;
    end

    if b < a
        tmp = a; a = b; b = tmp;
    end

    span = b - a;
    rawStep = span / max(1, targetCount - 1);
    pow10 = 10 ^ floor(log10(rawStep));
    r = rawStep / pow10;

    if r <= 1
        step = 1 * pow10;
    elseif r <= 2
        step = 2 * pow10;
    elseif r <= 5
        step = 5 * pow10;
    else
        step = 10 * pow10;
    end

    t0 = ceil(a / step) * step;
    t1 = floor(b / step) * step;
    ticks = t0:step:t1;

    if isempty(ticks)
        ticks = linspace(a, b, targetCount);
    end

    % 若端点很接近规整刻度，强制包含端点。
    if abs(a - ticks(1)) < 1e-6 * max(1, abs(step))
        ticks(1) = a;
    end
    if abs(b - ticks(end)) < 1e-6 * max(1, abs(step))
        ticks(end) = b;
    end
end

function rawValue = display_tick_to_raw(tickValue, dim, axisInfo)
    dmin = axisInfo.displayMin(dim);
    dmax = axisInfo.displayMax(dim);
    rmin = axisInfo.rawBoxMin(dim);
    rmax = axisInfo.rawBoxMax(dim);

    if abs(dmax - dmin) < eps
        rawValue = rmin;
    else
        rawValue = rmin + (tickValue - dmin) / (dmax - dmin) * (rmax - rmin);
    end
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
    [Ic, bbox] = crop_image_by_threshold_and_points(I, thr, marginRatio, [], []);
end

function [Ic, bbox] = crop_image_by_threshold_and_points(I, thr, marginRatio, extraX, extraY)
    mask = I > thr;
    [yy, xx] = find(mask);

    h = size(I,1);
    w = size(I,2);

    extraX = extraX(:);
    extraY = extraY(:);
    ok = isfinite(extraX) & isfinite(extraY);
    extraX = extraX(ok);
    extraY = extraY(ok);

    if isempty(xx) && isempty(extraX)
        Ic = I;
        bbox = [1, 1, w, h];
        return;
    end

    allX = [double(xx(:)); double(extraX(:))];
    allY = [double(yy(:)); double(extraY(:))];

    x1 = floor(min(allX)); x2 = ceil(max(allX));
    y1 = floor(min(allY)); y2 = ceil(max(allY));

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

function draw_axes_and_save(RGB, outFile, showFigure, axisInfo, camInfo, style, drawCubeFrame)
    % 按 MATLAB scatter3 / axes box 风格叠加坐标轴，并额外添加：
    %   1) 沿 X/Y/Z 方向的带单位轴标签；
    %   2) 顶部居中的科研绘图风格图题；
    %   3) 扩展四周留白，避免文字拥挤。

    if showFigure
        vis = 'on';
    else
        vis = 'off';
    end

    leftPad   = get_style_field(style, 'canvasPadLeft',   90);
    rightPad  = get_style_field(style, 'canvasPadRight',  90);
    bottomPad = get_style_field(style, 'canvasPadBottom', 90);
    topPad    = get_style_field(style, 'canvasPadTop',   150);

    canvasH = camInfo.outSize + topPad + bottomPad;
    canvasW = camInfo.outSize + leftPad + rightPad;

    canvasRGB = zeros(canvasH, canvasW, 3, 'like', RGB);
    r0 = topPad + 1;
    r1 = topPad + camInfo.outSize;
    c0 = leftPad + 1;
    c1 = leftPad + camInfo.outSize;
    canvasRGB(r0:r1, c0:c1, :) = RGB;

    fig = figure('Visible', vis, 'Color', 'k', ...
        'Name', 'Cosmic Web Orthographic Isometric Render', ...
        'Units', 'pixels', 'Position', [80, 80, canvasW, canvasH]);

    ax = axes('Parent', fig, 'Position', [0, 0, 1, 1]);
    image(ax, canvasRGB);
    axis(ax, 'image');
    axis(ax, 'off');
    hold(ax, 'on');

    cornersRaw = box_corners(axisInfo.rawBoxMin, axisInfo.rawBoxMax);
    cornersPix = project_raw_to_final_pixels(cornersRaw, camInfo);
    cornersPix(:,1) = cornersPix(:,1) + leftPad;
    cornersPix(:,2) = cornersPix(:,2) + topPad;

    % 选择图2风格的外侧坐标轴边。
    axisEdges = select_matlab_style_axis_edges(cornersRaw, cornersPix, axisInfo);

    if drawCubeFrame
        draw_matlab_style_frame(ax, cornersPix, style, axisEdges);
    end

    cubeCenterPix = mean(cornersPix, 1);

    draw_edge_axis(ax, axisEdges.X, 1, axisInfo, style, cubeCenterPix);
    draw_edge_axis(ax, axisEdges.Y, 2, axisInfo, style, cubeCenterPix);
    draw_edge_axis(ax, axisEdges.Z, 3, axisInfo, style, cubeCenterPix);

    % 顶部居中图题
    titleText = string(get_style_field(style, 'titleText', ''));
    if strlength(titleText) > 0
        titleY = max(24, topPad * 0.42);
        text(ax, canvasW / 2, titleY, char(titleText), ...
            'Color', get_style_field(style, 'titleColor', [0.96, 0.96, 0.96]), ...
            'FontName', style.fontName, ...
            'FontSize', get_style_field(style, 'titleFontSize', 20), ...
            'FontWeight', get_style_field(style, 'titleWeight', 'bold'), ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'Interpreter', 'none');
    end

    xlim(ax, [0.5, canvasW + 0.5]);
    ylim(ax, [0.5, canvasH + 0.5]);

    try
        exportgraphics(fig, outFile, 'Resolution', 150, 'BackgroundColor', 'black');
    catch
        set(fig, 'InvertHardcopy', 'off');
        print(fig, outFile, '-dpng', '-r150');
    end

    if ~showFigure
        close(fig);
    end
end

function axisEdges = select_matlab_style_axis_edges(cornersRaw, cornersPix, axisInfo)
    % cornersRaw 的顺序来自 box_corners:
    % 1 min min min
    % 2 max min min
    % 3 min max min
    % 4 max max min
    % 5 min min max
    % 6 max min max
    % 7 min max max
    % 8 max max max
    %
    % 对任一维度有 4 条候选边：
    %   X/Y 轴：选择屏幕最靠下的候选边，形成图2底部前缘坐标轴。
    %   Z 轴  ：选择屏幕最靠左的候选边，形成图2左侧竖直坐标轴。

    allEdges = box_edges();

    axisEdges.X = pick_axis_edge(cornersRaw, cornersPix, allEdges, 1, 'bottom', axisInfo);
    axisEdges.Y = pick_axis_edge(cornersRaw, cornersPix, allEdges, 2, 'bottom', axisInfo);
    axisEdges.Z = pick_axis_edge(cornersRaw, cornersPix, allEdges, 3, 'left',   axisInfo);
end

function edge = pick_axis_edge(cornersRaw, cornersPix, allEdges, dim, mode, axisInfo)
    cand = [];
    for i = 1:size(allEdges,1)
        id = allEdges(i,:);
        a = cornersRaw(id(1),:);
        b = cornersRaw(id(2),:);
        diffMask = abs(a - b) > 1e-9;
        if diffMask(dim) && sum(diffMask) == 1
            p = cornersPix(id,:);
            mid = mean(p, 1);
            cand(end+1).ids = id; %#ok<AGROW>
            cand(end).p = p;
            cand(end).mid = mid;
            cand(end).raw = [a; b];
        end
    end

    if isempty(cand)
        error('未能为第 %d 维找到坐标轴候选边。', dim);
    end

    score = zeros(numel(cand),1);
    switch lower(mode)
        case 'bottom'
            % 图像坐标 row 越大越靠下。
            for i = 1:numel(cand)
                score(i) = cand(i).mid(2);
            end
            [~, best] = max(score);
        case 'left'
            % 图像坐标 col 越小越靠左。
            for i = 1:numel(cand)
                score(i) = cand(i).mid(1);
            end
            [~, best] = min(score);
        otherwise
            best = 1;
    end

    raw = cand(best).raw;
    pix = cand(best).p;

    edge.dim = dim;
    edge.ids = cand(best).ids;
    edge.raw = raw;
    edge.pix = pix;

    % X/Y：数值从 displayMin 到 displayMax，保持真实坐标方向。
    % Z：为了匹配图2，让 0 在下、最大值在上；这更像 MATLAB 三维坐标轴的视觉方向。
    if dim == 3
        if pix(1,2) > pix(2,2)
            % 第 1 个端点更靠下。
            pMin = pix(1,:); pMax = pix(2,:);
        else
            pMin = pix(2,:); pMax = pix(1,:);
        end
    else
        if raw(1,dim) <= raw(2,dim)
            pMin = pix(1,:); pMax = pix(2,:);
        else
            pMin = pix(2,:); pMax = pix(1,:);
        end
    end

    edge.pMin = pMin;
    edge.pMax = pMax;
    edge.displayMin = axisInfo.displayMin(dim);
    edge.displayMax = axisInfo.displayMax(dim);
end

function draw_matlab_style_frame(ax, cornersPix, style, axisEdges)
    edges = box_edges();

    strongPairs = [sort(axisEdges.X.ids); sort(axisEdges.Y.ids); sort(axisEdges.Z.ids)];

    for i = 1:size(edges,1)
        id = edges(i,:);
        p = cornersPix(id,:);
        sid = sort(id);

        isAxisEdge = any(all(strongPairs == sid, 2));
        if isAxisEdge
            continue;
        end

        plot(ax, p(:,1), p(:,2), '-', ...
            'Color', style.frameColor, ...
            'LineWidth', style.frameLineWidth);
    end
end

function draw_edge_axis(ax, edge, dim, axisInfo, style, cubeCenterPix)
    p0 = edge.pMin;
    p1 = edge.pMax;

    plot(ax, [p0(1), p1(1)], [p0(2), p1(2)], '-', ...
        'Color', style.axisColor, 'LineWidth', style.lineWidth);

    axisDir = p1 - p0;
    n = norm(axisDir);
    if n < eps
        return;
    end
    axisDir = axisDir / n;

    tickNormal = [-axisDir(2), axisDir(1)];

    midPoint = 0.5 * (p0 + p1);
    if norm((midPoint + tickNormal * style.tickLengthPx) - cubeCenterPix) < norm(midPoint - cubeCenterPix)
        tickNormal = -tickNormal;
    end

    ticks = axisInfo.ticks{dim};

    for i = 1:numel(ticks)
        tv = ticks(i);
        f = (tv - edge.displayMin) / max(eps, edge.displayMax - edge.displayMin);
        f = min(max(f, 0), 1);
        q = p0 + f * (p1 - p0);

        q1 = q;
        q2 = q + tickNormal * style.tickLengthPx;
        plot(ax, [q1(1), q2(1)], [q1(2), q2(2)], '-', ...
            'Color', style.axisColor, 'LineWidth', style.lineWidth);

        labelPos = q + tickNormal * (style.tickLengthPx + style.tickLabelGapPx);
        text(ax, labelPos(1), labelPos(2), format_tick_label(tv), ...
            'Color', style.textColor, ...
            'FontName', style.fontName, ...
            'FontSize', style.fontSize, ...
            'FontWeight', 'normal', ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'Interpreter', 'none');
    end

    if isfield(style, 'showAxisLabels') && style.showAxisLabels
        if dim == 3
            frac = get_style_field(style, 'axisLabelFracZ', 0.55);
        else
            frac = get_style_field(style, 'axisLabelFracXY', 0.58);
        end
        frac = min(max(frac, 0.10), 0.90);

        basePos = p0 + frac * (p1 - p0);
        gapPx = get_style_field(style, 'axisLabelGapPx', 40);
        labelPos = basePos + tickNormal * (style.tickLengthPx + style.tickLabelGapPx + gapPx);

        axisName = char('X' + dim - 1);
        if strlength(string(axisInfo.unitText)) > 0
            labelText = sprintf('%s (%s)', axisName, axisInfo.unitText);
        else
            labelText = axisName;
        end

        rot = 0;
        if get_style_field(style, 'rotateAxisLabel', true)
            rot = atan2d(-(p1(2) - p0(2)), p1(1) - p0(1));
            if rot > 90
                rot = rot - 180;
            elseif rot < -90
                rot = rot + 180;
            end
        end

        text(ax, labelPos(1), labelPos(2), labelText, ...
            'Color', get_style_field(style, 'axisLabelColor', style.textColor), ...
            'FontName', style.fontName, ...
            'FontSize', get_style_field(style, 'labelFontSize', 16), ...
            'FontWeight', get_style_field(style, 'axisLabelWeight', 'bold'), ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'Rotation', rot, ...
            'Interpreter', 'none');
    end
end

function val = get_style_field(style, fieldName, defaultVal)
    if isstruct(style) && isfield(style, fieldName)
        val = style.(fieldName);
    else
        val = defaultVal;
    end
end

function s = format_tick_label(v)
    v = double(v);
    if abs(v - round(v)) < 1e-8 * max(1, abs(v))
        s = sprintf('%.0f', v);
    elseif abs(v) >= 100
        s = sprintf('%.1f', v);
    elseif abs(v) >= 10
        s = sprintf('%.2f', v);
    else
        s = sprintf('%.3g', v);
    end
end
