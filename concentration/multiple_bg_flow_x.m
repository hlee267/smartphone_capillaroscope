%% 1. Setup and Load
clear; clc; close all;

img_filename  = "../_images/flow_snaps/pre2_OG.png"; 
mask_filename = "../_images/flow_snaps/pre2_mask.png";

img = imread(img_filename);
mask_in = imread(mask_filename);

if size(img, 3) == 3, img = rgb2gray(img); end
if size(mask_in, 3) == 3, mask_in = rgb2gray(mask_in); end

% Convert to double for math, preserving 0-255 scale
img_d = double(img);
mask  = imbinarize(mask_in); 

%% 2. Dilate Mask & Generate Background (I_0)
dilation_amount = 25; 
se = strel('disk', dilation_amount);
mask_dilated = imdilate(mask, se);
img_background = regionfill(img_d, mask_dilated);

% Visualization 
figure('Position', [100, 100, 1200, 400]);
subplot(1,3,1); imshow(img_d, []); title('Original (I)');
subplot(1,3,2); imshow(mask_dilated); title('Dilated Mask');
subplot(1,3,3); imshow(img_background, []); title('Estimated Background (I_0)');

%% 3. Define Vertical Sampling Coordinates
% --- CONFIGURATION FOR VERTICAL SCANS ---
% y_range: The START and END pixel height (Vertical length of the profile)
y_range = [130, 300];  

% x_min / x_max: The LEFT and RIGHT bounds to scan across
x_min = 420;       
x_max = 440; 
num_lines = 30;

% Iterate over X coordinates
xs = linspace(x_min, x_max, num_lines);
N = round(diff(y_range)) + 1; % Length of the line is now vertical distance

% Initialize arrays
prof_I   = zeros(num_lines, N); 
prof_I0  = zeros(num_lines, N); 
lineXs   = zeros(num_lines, N);    
lineYs   = zeros(num_lines, N);

%% 4. Loop & Extract Profiles
for i = 1:num_lines
    xi = xs(i);
    
    % Define Vertical Line: X is constant, Y varies
    x_pair = [xi, xi];
    y_pair = y_range;
    
    % 1. Get I from Original Image
    [lx, ly, p_raw] = improfile(img_d, x_pair, y_pair, N, 'bilinear');
    prof_I(i, :) = p_raw(:).';
    
    % 2. Get I_0 from Inpainted Background
    [~, ~, p_bg] = improfile(img_background, x_pair, y_pair, N, 'bilinear');
    prof_I0(i, :) = p_bg(:).';
    
    lineXs(i, :) = lx(:).';
    lineYs(i, :) = ly(:).';
end

% Averages
mean_I   = mean(prof_I, 1, 'omitnan');
mean_I0  = mean(prof_I0, 1, 'omitnan');

%% 5. Calculate Optical Density (OD)
% Beer-Lambert: OD = -log10( I / I_0 )
OD_profiles = -log10(prof_I ./ prof_I0); 
mean_OD = mean(OD_profiles, 1, 'omitnan');

%% 6. Visualization: Show Sampling Lines
figure('Name', 'Sampling Locations', 'Position', [100, 500, 600, 600]);
imshow(img_d, []); 
hold on;
title('Vertical Sampling Lines on Original Image');
% Draw the vertical red lines
for i = 1:num_lines
    plot([xs(i), xs(i)], [y_range(1), y_range(2)], 'r-', 'LineWidth', 1);
end
axis on;

%% 7. Plot Results (Intensity & OD)
pix_um = 0.6;
dist_px = sqrt( (lineXs(1,:) - lineXs(1,1)).^2 + (lineYs(1,:) - lineYs(1,1)).^2 );
dist_um = dist_px * pix_um;

figure('Name', 'Analysis Results (Vertical)', 'Position', [750, 500, 600, 600]); 

% Subplot 1: Raw Intensities
subplot(2,1,1); hold on; grid on; box on;
plot(dist_um, mean_I, 'r-', 'LineWidth', 2, 'DisplayName', 'Original (I)');
plot(dist_um, mean_I0, 'b--', 'LineWidth', 2, 'DisplayName', 'Background (I_0)');
ylabel('Intensity (0-255)');
legend('Location', 'best'); 
title('Average Intensity Profiles (Vertical Cuts)');

% Subplot 2: Optical Density
subplot(2,1,2); hold on; grid on; box on;
plot(dist_um, mean_OD, 'k-', 'LineWidth', 2);
ylabel('Optical Density (OD)');
xlabel('Distance (\mum)');
title('Optical Density (-log_{10}(I / I_0))');

%% 8. Save Data
T_out = table(dist_um(:), mean_I(:), mean_I0(:), mean_OD(:), ...
    'VariableNames', {'Dist_um', 'Mean_I', 'Mean_I0', 'Mean_OD'});
writetable(T_out, 'beer_lambert_data_vertical.csv');