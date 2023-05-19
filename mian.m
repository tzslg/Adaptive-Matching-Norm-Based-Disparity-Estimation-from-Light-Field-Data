clc; clear; close all;

%------------------------------------------------------------ Read (New) HCI Data
file_path = 'F:\Desktop\LightFieldDepthReconstruction-PhD\NormalizedMatchingNorm\src\LightFieldData\pens\';
LFformat = 'png';
flist = dir(strcat([file_path '*.' LFformat]));
nbFile = length(flist);

% Read and store the images in LF structure
for i = 1:nbFile
    LF(i).Img = im2double(imread(strcat(file_path, flist(i).name)));
end

% Experiment parameters: minimum disparity d_min, maximum disparity d_max, variance sigma, matching window size W: WxW
d_min = -1.7;
delta = 0.1;
d_max = 2.0;
sigma = 0.0025;
W = 5; % Parameters

%------------------------------------------------------------------- Core Code

% Create a Gaussian filter kernel
H = fspecial('gaussian', [W, W], 0.25 * W);

% Choose a reference view (LF(41).Img)
I = LF(41).Img;

% Get the dimensions of the reference view
[h, w, ~] = size(I);

% Initialize output disparity map
Xout = zeros(nbFile, h, w);

% Create disparity range vector d_
d_ = 1:length(d_min:delta:d_max);

% Initialize cost volume
CostV = zeros(length(d_), h, w);

% Pre-compute the meshgrid coordinates for later interpolation
y = repmat((1:w), h, 1);
x = repmat((1:h)', 1, w);

% Initialize variables for sub-aperture image indexing
u = sqrt(nbFile);
ur = floor(u/2);
v = sqrt(nbFile);
vr = floor(v/2);
oi = repmat((-ur:ur), v, 1);
oj = repmat((-vr:vr)', 1, u);

% Initialize iteration count and progress string
it = 1;
Str = '';

% Loop over each disparity value in the range
for d = d_min:delta:d_max
    % Display progress
    msg = sprintf('Processing: %d/%d done!\n', it, length(d_));
    fprintf([Str, msg]), Str = repmat(sprintf('\b'), 1, length(msg));
    
    % Loop over each sub-aperture image
    for k = 1:nbFile
        % Compute interpolated coordinates for sub-aperture image
        yj = y + d * oj(k);
        xi = x + d * oi(k);
        
        % Get the sub-aperture image
        g = LF(k).Img;
        
        % Perform bilinear interpolation of sub-aperture image channels
        g(:,:,1) = interp2(yj, xi, g(:,:,1), y, x, 'linear', 0);
        g(:,:,2) = interp2(yj, xi, g(:,:,2), y, x, 'linear', 0);
        g(:,:,3) = interp2(yj, xi, g(:,:,3), y, x, 'linear', 0);
        
        % Compute the difference between the interpolated image and the reference image
        Xout(k,:,:) = sum(min(max(g, 0), 1) - I, 3);
    end
    
    % Compute cost volume using a Gaussian filter and accumulate the results
    CostV(it,:,:) = sum(imfilter(normpdf(Xout, 0, sigma), H), 1);
    
    it = it + 1;
end

% Find the disparity index with the maximum cost value for each pixel location
[~, index] = max(CostV);

% Apply median filtering to the disparity map for noise reduction
Disparity = medfilt2(d_(squeeze(index)), [3, 3]);

% Display the disparity map
figure, imshow(Disparity, []);
title('Disparity');
