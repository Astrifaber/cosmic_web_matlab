% ==========================================
% 图片合并为 MP4 视频的 MATLAB 脚本
% ==========================================

% 1. 设置参数
imageFolder = 'D:\Cosmoscraft\cosmic_web_matlab\snapshots';  % 修改为包含图片的文件夹所在路径
outputVideoName = 'output_video.mp4';   % 导出的视频文件名（可包含绝对路径）
imageExtension = '*.png';               % 图片的扩展名，例如 '*.jpg' 或 '*.png'
frameRate = 2;                         % 设置视频帧率（每秒显示的图片数量），比如 10, 24, 30

% 2. 获取图片列表
% 使用 dir 函数获取该文件夹下所有指定格式的图片
imageFiles = dir(fullfile(imageFolder, imageExtension));

% 检查文件夹中是否有图片
if isempty(imageFiles)
    error('在指定的文件夹中未找到匹配的图片，请检查路径或后缀名。');
end

% 提示：MATLAB 的 dir 函数默认按字母顺序读取。
% 如果你的图片命名是类似 1.jpg, 2.jpg... 10.jpg，可能会按 1, 10, 2... 排序。
% 建议将图片命名为补零格式（如 001.jpg, 002.jpg... 010.jpg）以确保顺序正确。

% 3. 初始化视频对象
% 创建 VideoWriter 对象，'MPEG-4' 表示输出格式为 MP4
v = VideoWriter(outputVideoName, 'MPEG-4');
v.FrameRate = frameRate; % 设置帧率

% 打开视频对象准备写入
open(v);

% 4. 循环读取图片并写入视频
disp('开始合并视频，请稍候...');

for i = 1:length(imageFiles)
    % 拼接完整的图片路径
    currentImageName = fullfile(imageFolder, imageFiles(i).name);
    
    % 读取当前图片
    img = imread(currentImageName);
    
    % 将当前图片写入视频流
    writeVideo(v, img);
    
    % 在命令窗口打印进度
    fprintf('正在处理: %d / %d\n', i, length(imageFiles));
end

% 5. 关闭并保存视频
close(v);
disp(['视频合并完成！已保存为: ', outputVideoName]);