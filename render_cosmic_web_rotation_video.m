function render_cosmic_web_rotation_video()
%% render_cosmic_web_rotation_video.m
% 从 MATLAB base workspace 或 mat 文件读取 x,y,z 点云向量，
% 将宇宙网立方体绕竖直方向水平旋转，并输出 MP4 视频。
%
% 使用方式：
%   1) 确保 MATLAB 工作区已有 x,y,z；
%   2) 或者设置 dataMatFile 指向包含 x,y,z 的 mat 文件；
%   3) 运行：
%        render_cosmic_web_rotation_video
%
% 输出：
%   cosmic_web_horizontal_rotation.mp4

load("D:\Cosmoscraft\cosmic_web_matlab\matlab.mat");

%% ========================= 数据来源 =========================
% 留空 "" ：优先读取当前 MATLAB 工作区中的 x,y,z
% 指定 mat 路径：从 mat 文件读取 x,y,z
dataMatFile = "";

% 例：
% dataMatFile = "D:\Cosmoscraft\cosmic_web_matlab\matlab.mat";

%% ========================= 视频输出参数 =========================
outVideo = 'cosmic_web_horizontal_rotation.mp4';

frameCount   = 180;     % 总帧数。30 fps 下 180 帧约 6 秒
frameRate    = 30;      % 视频帧率
videoQuality = 95;      % 1-100，越高文件越大

rotationRounds = 1.0;   % 旋转圈数。1 表示完整 360 度
rotationDirection = 1;  % 1 正向，-1 反向

% 初始视线方向。沿水平面旋转时，Z 分量保持不变。
% [1,1,1] 是你原脚本的等轴视角。
cameraLookDirection0 = [1, 1, 1];

% true 会显示渲染窗口；false 会用离屏导出，通常更慢但不弹窗。
showRenderWindow = true;

%% ========================= 渲染参数区 =========================

% ---------- 体渲染分辨率 ----------
% 视频逐帧渲染耗时明显高于单张图。
% 若想先快速预览，可改为 Nxy=360, Nz=260, outSize=1200, frameCount=60。
Nxy = 520;
Nz  = 380;

% ---------- 体素平滑 ----------
sigmaVox = 0.58;

% ---------- 密度与发光控制 ----------
rhoCap    = 12.0;
emitLogK  = 42.0;
tau       = 0.32;
depthBeta = 0.18;   % 控制近处更亮、远处更暗

% ---------- 2D 发光晕 ----------
glowSigma  = 0.70;
glowAmount = 0.12;

% ---------- 最终 tone mapping ----------
clipLo   = 0.005;
clipHi   = 99.985;
toneK    = 12.0;
gammaOut = 0.62;

% 为避免视频亮度闪烁，建议开启全局 tone mapping。
% 开启后会先抽样渲染若干帧，估计全视频统一的亮度上下限。
useGlobalToneMapping = true;
toneProbeFrameCount  = 24;
toneSamplesPerProbe  = 60000;

% ---------- 输出图像尺寸 ----------
outSize = 1600;

% ---------- 体素边界留白 ----------
projectionPad = 0.02;

% ---------- 锁定三维视图比例 ----------
% true：所有帧使用统一正交视野，u/v 同比例映射，避免旋转时被压缩拉伸
lockMetricAspect = true;

% 视野额外留白。越大，旋转过程中越不容易贴边，但主体会稍小。
fixedViewPadding = 1.10;

% true：u/v 使用完全相同的世界坐标范围，保证横纵向像素尺度一致
forceSquareMetricViewport = true;

% ---------- 正交深度方向 ----------
% 若你感觉近远关系反了，切换 true/false。
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

% MATLAB scatter3 风格坐标轴
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
axisStyle.showAxisLabels  = true;
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

%% ========================= 读取数据 =========================
fprintf('Reading x, y, z...\n');

[x, y, z, params] = read_xyz_and_params(dataMatFile);

assert(isnumeric(x) && isvector(x), '变量 x 必须是数值向量。');
assert(isnumeric(y) && isvector(y), '变量 y 必须是数值向量。');
assert(isnumeric(z) && isvector(z), '变量 z 必须是数值向量。');

x = x(:);
y = y(:);
z = z(:);

assert(numel(x) == numel(y) && numel(y) == numel(z), ...
    'x, y, z 三个向量长度必须一致。');

fprintf('Point count = %d\n', numel(x));

mask = isfinite(x) & isfinite(y) & isfinite(z);
x = single(x(mask));
y = single(y(mask));
z = single(z(mask));

fprintf('Valid point count after filtering = %d\n', numel(x));

%% ========================= 坐标归一化与尺度分析 =========================
fprintf('Analyzing coordinate scale...\n');

xmin = min(x); xmax = max(x);
ymin = min(y); ymax = max(y);
zmin = min(z); zmax = max(z);

rawBoxMin = double([xmin, ymin, zmin]);
rawBoxMax = double([xmax, ymax, zmax]);

axisInfo = resolve_axis_info(axisSource, params, rawBoxMin, rawBoxMax, ...
    axisUnitWhenParams, axisTickTargetCount);

fprintf('Axis scale source = %s\n', axisInfo.sourceDescription);
fprintf('Axis display range: X [%.6g, %.6g], Y [%.6g, %.6g], Z [%.6g, %.6g] %s\n', ...
    axisInfo.displayMin(1), axisInfo.displayMax(1), ...
    axisInfo.displayMin(2), axisInfo.displayMax(2), ...
    axisInfo.displayMin(3), axisInfo.displayMax(3), axisInfo.unitText);

fprintf('Normalizing point cloud...\n');

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

Pnorm = zeros(numel(x), 3, 'single');
Pnorm(:,1) = (x - cx) / s;
Pnorm(:,2) = (y - cy) / s;
Pnorm(:,3) = (z - cz) / s;

clear x y z;

%% ========================= 打包参数 =========================
rp.Nxy = Nxy;
rp.Nz = Nz;
rp.sigmaVox = sigmaVox;
rp.rhoCap = rhoCap;
rp.emitLogK = emitLogK;
rp.tau = tau;
rp.depthBeta = depthBeta;
rp.glowSigma = glowSigma;
rp.glowAmount = glowAmount;
rp.clipLo = clipLo;
rp.clipHi = clipHi;
rp.toneK = toneK;
rp.gammaOut = gammaOut;
rp.outSize = outSize;
rp.projectionPad = projectionPad;
rp.flipDepth = flipDepth;

rp.lockMetricAspect = lockMetricAspect;
rp.fixedViewPadding = fixedViewPadding;
rp.forceSquareMetricViewport = forceSquareMetricViewport;

rp.rawCenter = rawCenter;
rp.rawScale = rawScale;
rp.axisInfo = axisInfo;

%% ========================= 旋转角度 =========================
theta0 = atan2(cameraLookDirection0(2), cameraLookDirection0(1));
zLook  = cameraLookDirection0(3);

angles = theta0 + rotationDirection * linspace(0, 2*pi*rotationRounds, frameCount + 1);
angles(end) = [];

lookDirections = zeros(frameCount, 3);
for i = 1:frameCount
    lookDirections(i,:) = [cos(angles(i)), sin(angles(i)), zLook];
end

%% ========================= 固定正交视野，锁定横纵比例 =========================
if lockMetricAspect
    fprintf('Computing fixed metric orthographic viewport...\n');

    fixedViewBounds = compute_fixed_orthographic_bounds( ...
        lookDirections, ...
        axisInfo.rawBoxMin, ...
        axisInfo.rawBoxMax, ...
        rawCenter, ...
        rawScale, ...
        projectionPad, ...
        fixedViewPadding, ...
        forceSquareMetricViewport);

    rp.fixedViewBounds = fixedViewBounds;

    fprintf('Fixed viewport:\n');
    fprintf('  u range = [%.6g, %.6g]\n', fixedViewBounds.umin, fixedViewBounds.umax);
    fprintf('  v range = [%.6g, %.6g]\n', fixedViewBounds.vmin, fixedViewBounds.vmax);
    fprintf('  w range = [%.6g, %.6g]\n', fixedViewBounds.wmin, fixedViewBounds.wmax);
    fprintf('  pixel scale locked: du = %.6g, dv = %.6g\n', ...
        fixedViewBounds.umax - fixedViewBounds.umin, ...
        fixedViewBounds.vmax - fixedViewBounds.vmin);
else
    rp.fixedViewBounds = [];
end

%% ========================= 全局 Tone Mapping 预估 =========================
toneLoFixed = [];
toneHiFixed = [];

if useGlobalToneMapping
    fprintf('Estimating global tone mapping from probe frames...\n');

    probeCount = min(frameCount, toneProbeFrameCount);
    probeIds = unique(round(linspace(1, frameCount, probeCount)));

    samplePool = zeros(numel(probeIds) * toneSamplesPerProbe, 1, 'single');
    cursor = 1;

    for ii = 1:numel(probeIds)
        fid = probeIds(ii);
        fprintf('  Probe frame %d / %d...\n', fid, frameCount);

        lookDir = lookDirections(fid,:);
        [Iraw, ~] = render_raw_intensity(Pnorm, lookDir, rp);

        smp = random_sample_vector(Iraw(:), toneSamplesPerProbe);
        n = numel(smp);

        samplePool(cursor:cursor+n-1) = smp(:);
        cursor = cursor + n;
    end

    samplePool = samplePool(1:cursor-1);
    toneLoFixed = percentile_from_vector(samplePool, clipLo);
    toneHiFixed = percentile_from_vector(samplePool, clipHi);

    if toneHiFixed <= toneLoFixed
        toneLoFixed = min(samplePool);
        toneHiFixed = max(samplePool);
    end

    fprintf('Global tone range: lo = %.6g, hi = %.6g\n', toneLoFixed, toneHiFixed);
end

%% ========================= 创建视频写入器 =========================
fprintf('Opening video writer: %s\n', outVideo);

vw = VideoWriter(outVideo, 'MPEG-4');
vw.FrameRate = frameRate;
vw.Quality = videoQuality;
open(vw);

cleanupObj = onCleanup(@() safe_close_video(vw));

%% ========================= 主渲染循环 =========================
fprintf('Rendering video frames...\n');

tStart = tic;

for f = 1:frameCount
    fprintf('Frame %d / %d\n', f, frameCount);

    lookDir = lookDirections(f,:);

    [Iraw, camInfo] = render_raw_intensity(Pnorm, lookDir, rp);
    I = apply_tone_mapping(Iraw, rp, toneLoFixed, toneHiFixed);

    I = imresize(I, [outSize, outSize], 'bicubic');

    cmap = cosmic_colormap(1024);
    RGB = apply_colormap(I, cmap);

    if drawAxes
        frameRGB = compose_frame_with_axes(RGB, axisInfo, camInfo, axisStyle, drawCubeFrame, showRenderWindow);
    else
        frameRGB = uint8(round(255 * min(max(RGB,0),1)));
    end

    writeVideo(vw, frameRGB);
end

close(vw);
delete(cleanupObj);

elapsed = toc(tStart);
fprintf('Done. Video saved to: %s\n', outVideo);
fprintf('Elapsed time: %.2f minutes\n', elapsed / 60);

end

%% ========================= 数据读取函数 =========================

function [x, y, z, params] = read_xyz_and_params(dataMatFile)
    params = struct();

    if strlength(string(dataMatFile)) > 0 && isfile(dataMatFile)
        fprintf('Loading mat file: %s\n', dataMatFile);
        S = load(dataMatFile);

        assert(isfield(S, 'x'), 'mat 文件中没有变量 x。');
        assert(isfield(S, 'y'), 'mat 文件中没有变量 y。');
        assert(isfield(S, 'z'), 'mat 文件中没有变量 z。');

        x = S.x;
        y = S.y;
        z = S.z;

        if isfield(S, 'params')
            params = S.params;
        end
    else
        fprintf('Using x,y,z from base workspace.\n');

        assert(evalin('base', 'exist(''x'', ''var'')') == 1, 'base workspace 中没有变量 x。');
        assert(evalin('base', 'exist(''y'', ''var'')') == 1, 'base workspace 中没有变量 y。');
        assert(evalin('base', 'exist(''z'', ''var'')') == 1, 'base workspace 中没有变量 z。');

        x = evalin('base', 'x');
        y = evalin('base', 'y');
        z = evalin('base', 'z');

        if evalin('base', 'exist(''params'', ''var'')') == 1
            params = evalin('base', 'params');
        end
    end
end

function safe_close_video(vw)
    try
        close(vw);
    catch
    end
end

%% ========================= 单帧体渲染 =========================

function [I, camInfo] = render_raw_intensity(Pnorm, lookDirection, rp)

    Nxy = rp.Nxy;
    Nz  = rp.Nz;

    look = unitvec(lookDirection);
    up0  = [0, 0, 1];

    if norm(cross(up0, look)) < 1e-8
        up0 = [0, 1, 0];
    end

    right = unitvec(cross(up0, look));
    up    = unitvec(cross(look, right));

    rs = single(right);
    us = single(up);
    ls = single(look);

    u = Pnorm(:,1) * rs(1) + Pnorm(:,2) * rs(2) + Pnorm(:,3) * rs(3);
    v = Pnorm(:,1) * us(1) + Pnorm(:,2) * us(2) + Pnorm(:,3) * us(3);
    w = Pnorm(:,1) * ls(1) + Pnorm(:,2) * ls(2) + Pnorm(:,3) * ls(3);

    axisCornersRaw  = box_corners(rp.axisInfo.rawBoxMin, rp.axisInfo.rawBoxMax);
axisCornersNorm = raw_to_norm(axisCornersRaw, rp.rawCenter, rp.rawScale);
[axisCornerU, axisCornerV, axisCornerW] = project_norm_points(axisCornersNorm, right, up, look);

% -------------------------------------------------------------------------
% 关键优化：
%   原脚本每一帧分别用当前 u/v 范围拉伸到 Nxy x Nxy。
%   这会导致旋转时横纵比例被动态改变。
%
%   现在改为：
%   1) 若 rp.fixedViewBounds 存在，则所有帧使用同一个 u/v/w 范围；
%   2) u 与 v 使用相同物理尺度；
%   3) 旋转时不再把立方体强行铺满画面；
%   4) 立方体不会随角度被压缩或拉伸。
% -------------------------------------------------------------------------

if isfield(rp, 'fixedViewBounds') && ~isempty(rp.fixedViewBounds)
    umin = single(rp.fixedViewBounds.umin);
    umax = single(rp.fixedViewBounds.umax);
    vmin = single(rp.fixedViewBounds.vmin);
    vmax = single(rp.fixedViewBounds.vmax);
    wmin = single(rp.fixedViewBounds.wmin);
    wmax = single(rp.fixedViewBounds.wmax);
else
    pad = single(rp.projectionPad);

    umin = min([min(u), single(min(axisCornerU))]);
    umax = max([max(u), single(max(axisCornerU))]);
    vmin = min([min(v), single(min(axisCornerV))]);
    vmax = max([max(v), single(max(axisCornerV))]);
    wmin = min([min(w), single(min(axisCornerW))]);
    wmax = max([max(w), single(max(axisCornerW))]);

    du = umax - umin;
    dv = vmax - vmin;
    dw = wmax - wmin;

    % 非锁定模式：保留旧逻辑
    umin = umin - pad * du; umax = umax + pad * du;
    vmin = vmin - pad * dv; vmax = vmax + pad * dv;
    wmin = wmin - pad * dw; wmax = wmax + pad * dw;
end

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

    vol = gaussblur3(vol, rp.sigmaVox);

    p999 = sample_percentile(vol, 99.90, 500000);
    if p999 <= 0
        I = zeros(Nxy, Nxy, 'single');
    else
        rho = vol / p999;
        rho = min(rho, rp.rhoCap);

        emit  = log1p(rp.emitLogK * rho) / log1p(rp.emitLogK * rp.rhoCap);
        alpha = 1 - exp(-rp.tau * rho);

        I = zeros(Nxy, Nxy, 'single');
        T = ones(Nxy, Nxy, 'single');

        depthWeight = single(exp(-rp.depthBeta * linspace(0, 1, Nz)));

        if rp.flipDepth
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
    end

    glow = gaussblur2(I, rp.glowSigma);
    I = I + rp.glowAmount * glow;

    camInfo.right = right;
    camInfo.up    = up;
    camInfo.look  = look;
    camInfo.umin  = double(umin);
    camInfo.umax  = double(umax);
    camInfo.vmin  = double(vmin);
    camInfo.vmax  = double(vmax);
    camInfo.Nxy   = Nxy;
    camInfo.cropBBox = [1, 1, Nxy, Nxy];
    camInfo.outSize  = rp.outSize;
    camInfo.rawCenter = rp.rawCenter;
    camInfo.rawScale  = rp.rawScale;
end

function I = apply_tone_mapping(Iraw, rp, toneLoFixed, toneHiFixed)
    I = Iraw;

    if isempty(toneLoFixed) || isempty(toneHiFixed)
        lo = sample_percentile(I, rp.clipLo, 200000);
        hi = sample_percentile(I, rp.clipHi, 200000);
    else
        lo = toneLoFixed;
        hi = toneHiFixed;
    end

    if hi <= lo
        hi = max(I(:));
        lo = min(I(:));
    end

    I = (I - lo) ./ max(eps('single'), single(hi - lo));
    I = min(max(I, 0), 1);

    I = asinh(rp.toneK * I) / asinh(rp.toneK);
    I = I .^ rp.gammaOut;
end

%% ========================= 视频帧合成：图像 + 坐标轴 =========================

function frameRGB = compose_frame_with_axes(RGB, axisInfo, camInfo, style, drawCubeFrame, showRenderWindow)

    if showRenderWindow
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

    if mod(canvasH, 2) == 1
        canvasH = canvasH + 1;
        bottomPad = bottomPad + 1;
    end
    if mod(canvasW, 2) == 1
        canvasW = canvasW + 1;
        rightPad = rightPad + 1;
    end

    canvasRGB = zeros(canvasH, canvasW, 3, 'single');

    r0 = topPad + 1;
    r1 = topPad + camInfo.outSize;
    c0 = leftPad + 1;
    c1 = leftPad + camInfo.outSize;

    canvasRGB(r0:r1, c0:c1, :) = single(RGB);

    fig = figure('Visible', vis, 'Color', 'k', ...
        'Name', 'Cosmic Web Rotation Video Frame', ...
        'Units', 'pixels', 'Position', [80, 80, canvasW, canvasH], ...
        'MenuBar', 'none', 'ToolBar', 'none', 'Resize', 'off');

    ax = axes('Parent', fig, 'Position', [0, 0, 1, 1]);
    image(ax, canvasRGB);
    axis(ax, 'image');
    axis(ax, 'off');
    hold(ax, 'on');

    cornersRaw = box_corners(axisInfo.rawBoxMin, axisInfo.rawBoxMax);
    cornersPix = project_raw_to_final_pixels(cornersRaw, camInfo);
    cornersPix(:,1) = cornersPix(:,1) + leftPad;
    cornersPix(:,2) = cornersPix(:,2) + topPad;

    axisEdges = select_matlab_style_axis_edges(cornersRaw, cornersPix, axisInfo);

    if drawCubeFrame
        draw_matlab_style_frame(ax, cornersPix, style, axisEdges);
    end

    cubeCenterPix = mean(cornersPix, 1);

    draw_edge_axis(ax, axisEdges.X, 1, axisInfo, style, cubeCenterPix);
    draw_edge_axis(ax, axisEdges.Y, 2, axisInfo, style, cubeCenterPix);
    draw_edge_axis(ax, axisEdges.Z, 3, axisInfo, style, cubeCenterPix);

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

    drawnow;

    if showRenderWindow
        fr = getframe(fig);
        frameRGB = fr.cdata;
    else
        tmpFile = [tempname, '.png'];
        try
            exportgraphics(fig, tmpFile, 'Resolution', 100, 'BackgroundColor', 'black');
            frameRGB = imread(tmpFile);
            delete(tmpFile);
        catch
            fr = getframe(fig);
            frameRGB = fr.cdata;
        end
    end

    close(fig);

    if size(frameRGB,1) ~= canvasH || size(frameRGB,2) ~= canvasW
        frameRGB = imresize(frameRGB, [canvasH, canvasW]);
    end

    if ~isa(frameRGB, 'uint8')
        frameRGB = uint8(round(255 * min(max(frameRGB,0),1)));
    end
end

%% ========================= 数学与投影函数 =========================

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

%% ========================= 坐标轴尺度函数 =========================

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

    if abs(a - ticks(1)) < 1e-6 * max(1, abs(step))
        ticks(1) = a;
    end
    if abs(b - ticks(end)) < 1e-6 * max(1, abs(step))
        ticks(end) = b;
    end
end

%% ========================= 卷积、采样与色表 =========================

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

function s = random_sample_vector(x, maxSamples)
    x = x(:);
    x = x(isfinite(x));

    n = numel(x);
    if n == 0
        s = single([]);
        return;
    end

    if n > maxSamples
        idx = randperm(n, maxSamples);
        s = single(x(idx));
    else
        s = single(x);
    end
end

function p = percentile_from_vector(x, pct)
    x = x(:);
    x = x(isfinite(x));

    if isempty(x)
        p = 0;
        return;
    end

    x = sort(double(x));
    k = round((pct / 100) * numel(x));
    k = max(1, min(numel(x), k));
    p = x(k);
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

%% ========================= 坐标轴绘制函数 =========================

function axisEdges = select_matlab_style_axis_edges(cornersRaw, cornersPix, axisInfo)
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
            for i = 1:numel(cand)
                score(i) = cand(i).mid(2);
            end
            [~, best] = max(score);

        case 'left'
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

    if dim == 3
        if pix(1,2) > pix(2,2)
            pMin = pix(1,:);
            pMax = pix(2,:);
        else
            pMin = pix(2,:);
            pMax = pix(1,:);
        end
    else
        if raw(1,dim) <= raw(2,dim)
            pMin = pix(1,:);
            pMax = pix(2,:);
        else
            pMin = pix(2,:);
            pMax = pix(1,:);
        end
    end

    edge.pMin = pMin;
    edge.pMax = pMax;
    edge.displayMin = axisInfo.displayMin(dim);
    edge.displayMax = axisInfo.displayMax(dim);
end

function draw_matlab_style_frame(ax, cornersPix, style, axisEdges)
    edges = box_edges();

    strongPairs = [
        sort(axisEdges.X.ids)
        sort(axisEdges.Y.ids)
        sort(axisEdges.Z.ids)
    ];

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
        'Color', style.axisColor, ...
        'LineWidth', style.lineWidth);

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
            'Color', style.axisColor, ...
            'LineWidth', style.lineWidth);

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

        labelPos = basePos + tickNormal * ...
            (style.tickLengthPx + style.tickLabelGapPx + gapPx);

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

function bounds = compute_fixed_orthographic_bounds(lookDirections, rawBoxMin, rawBoxMax, rawCenter, rawScale, projectionPad, fixedViewPadding, forceSquareMetricViewport)
    % 计算所有旋转帧共用的正交投影视野。
    %
    % 目标：
    %   1) 所有帧使用同一 u/v/w 范围；
    %   2) u/v 使用同一空间尺度；
    %   3) 防止旋转时因为每帧单独归一化造成压缩、拉伸；
    %   4) 保证三维单位长度在投影前保持各向同性。
    %
    % 注意：
    %   正交投影下，三维长度相等不意味着屏幕上每条边都等长。
    %   旋转时，部分边会因为朝向视线而自然投影变短。
    %   这是正确的几何效果，不是拉伸。

    cornersRaw  = box_corners(rawBoxMin, rawBoxMax);
    cornersNorm = raw_to_norm(cornersRaw, rawCenter, rawScale);

    maxAbsU = 0;
    maxAbsV = 0;
    maxAbsW = 0;

    for i = 1:size(lookDirections, 1)
        look = unitvec(lookDirections(i,:));
        up0  = [0, 0, 1];

        if norm(cross(up0, look)) < 1e-8
            up0 = [0, 1, 0];
        end

        right = unitvec(cross(up0, look));
        up    = unitvec(cross(look, right));

        [u, v, w] = project_norm_points(cornersNorm, right, up, look);

        maxAbsU = max(maxAbsU, max(abs(u)));
        maxAbsV = max(maxAbsV, max(abs(v)));
        maxAbsW = max(maxAbsW, max(abs(w)));
    end

    padFactor = (1 + projectionPad) * fixedViewPadding;

    if forceSquareMetricViewport
        % 关键：u/v 取同一个半范围。
        % 这相当于手动实现三维绘图中的 daspect([1 1 1]) + axis equal。
        halfUV = max(maxAbsU, maxAbsV) * padFactor;

        bounds.umin = -halfUV;
        bounds.umax =  halfUV;
        bounds.vmin = -halfUV;
        bounds.vmax =  halfUV;
    else
        % 不推荐，仅保留可选项。
        % 这种模式虽然固定了每帧视野，但 u/v 物理尺度可能不同。
        halfU = maxAbsU * padFactor;
        halfV = maxAbsV * padFactor;

        bounds.umin = -halfU;
        bounds.umax =  halfU;
        bounds.vmin = -halfV;
        bounds.vmax =  halfV;
    end

    halfW = maxAbsW * padFactor;

    if halfW <= 0
        halfW = 1;
    end

    bounds.wmin = -halfW;
    bounds.wmax =  halfW;

    % 防止极端情况下范围为 0
    if bounds.umax <= bounds.umin
        bounds.umin = -1;
        bounds.umax =  1;
    end

    if bounds.vmax <= bounds.vmin
        bounds.vmin = -1;
        bounds.vmax =  1;
    end

    if bounds.wmax <= bounds.wmin
        bounds.wmin = -1;
        bounds.wmax =  1;
    end
end