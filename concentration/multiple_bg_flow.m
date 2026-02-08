%% 1. Setup and Load
clear; clc; close all;

img_filename  = "../_images/flow_snaps/post1_OG.png"; 
mask_filename = "../_images/flow_snaps/post1_mask.png";

img = imread(img_filename);
mask_in = imread(mask_filename);

if size(img, 3) == 3, img = rgb2gray(img); end
if size(mask_in, 3) == 3, mask_in = rgb2gray(mask_in); end

% Convert to double [0, 1] for math
img_d = double(img);
mask  = imbinarize(mask_in); 

%% 2. Dilate Mask (CRITICAL STEP)
% We expand the mask so the inpainting starts from the BRIGHT tissue,
% ignoring the dark vessel edges completely.
dilation_amount = 25; % Increase if the "smudge" remains
se = strel('disk', dilation_amount);
mask_dilated = imdilate(mask, se);

%% 3. Generate Background (I_0)
% We use the Original Image for the background fill, but we pass the 
% DILATED mask so it knows to ignore the vessel entirely.
img_background = regionfill(img_d, mask_dilated);

% Visualization to confirm the "Dark Smudge" is gone
figure('Position', [100, 100, 1200, 400]);
subplot(1,3,1); imshow(img_d, []); title('Original (I)');
subplot(1,3,2); imshow(mask_dilated); title('Dilated Mask');
subplot(1,3,3); imshow(img_background, []); title('Estimated Background (I_0)');

%% 4. Extract Profiles for Beer-Lambert
% Coordinates (Adjust these to cut across the vessel)
x_1 = [200, 400];  
y_1 = [300, 320];  
y_min = 300;       
y_max = 320;        
num_lines = 30;

ys = linspace(y_min, y_max, num_lines);
N = round(hypot(diff(x_1), diff(y_1))) + 1;

prof_I   = zeros(num_lines, N); % From Original
prof_I0  = zeros(num_lines, N); % From Inpainted Background
lineXs   = zeros(num_lines, N);    
lineYs   = zeros(num_lines, N);

for i = 1:num_lines
    yi = ys(i);
    % 1. Get I from the Original Image (Preserving original values!)
    [lx, ly, p_raw] = improfile(img_d, x_1, [yi, yi], N, 'bilinear');
    prof_I(i, :) = p_raw(:).';
    
    % 2. Get I_0 from the Inpainted Background
    [~, ~, p_bg] = improfile(img_background, x_1, [yi, yi], N, 'bilinear');
    prof_I0(i, :) = p_bg(:).';
    
    lineXs(i, :) = lx(:).';
    lineYs(i, :) = ly(:).';
end

% Averages
mean_I   = mean(prof_I, 1, 'omitnan');
mean_I0  = mean(prof_I0, 1, 'omitnan');

%% 5. Calculate Optical Density (OD)
% Beer-Lambert: OD = -log10( I / I_0 )
% Note: Avoid division by zero or log of zero if image is black
OD_profiles = -log10(prof_I ./ prof_I0); 
mean_OD = mean(OD_profiles, 1, 'omitnan');

%% 6. Plotting
pix_um = 0.6;
dist_px = sqrt( (lineXs(1,:) - lineXs(1,1)).^2 + (lineYs(1,:) - lineYs(1,1)).^2 );
dist_um = dist_px * pix_um;

figure; 

% Subplot 1: Intensities (I vs I0)
subplot(2,1,1); hold on; grid on; box on;
plot(dist_um, mean_I, 'r-', 'LineWidth', 2, 'DisplayName', 'Original (I)');
plot(dist_um, mean_I0, 'b--', 'LineWidth', 2, 'DisplayName', 'Background (I_0)');
ylabel('Intensity');
legend; title('Intensity Profiles');

% Subplot 2: Optical Density
subplot(2,1,2); hold on; grid on; box on;
plot(dist_um, mean_OD, 'k-', 'LineWidth', 2);
ylabel('Optical Density (OD)');
xlabel('Distance (\mum)');
title('Optical Density (-log_{10}(I / I_0))');

%% 7. Save Data
T_out = table(dist_um(:), mean_I(:), mean_I0(:), mean_OD(:), ...
    'VariableNames', {'Dist_um', 'Mean_I', 'Mean_I0', 'Mean_OD'});
writetable(T_out, 'beer_lambert_data.csv');