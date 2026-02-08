clear; clc; close all;

% --- 1. Load Original Capillary Image ---
img_tiff = "../_images/RAW_debayered/20250620_contrast.tif";
try
    t = Tiff(img_tiff, 'r');
    img = read(t);
    t.close();
catch ME
    fprintf('Error loading original image: %s\n', img_tiff);
    rethrow(ME);
end

% --- 2. Load the PRE-SAVED BACKGROUND Image from Python ---
bg_tiff_path = 'estimated_background.tiff'; % File saved from Python
try
    t_bg = Tiff(bg_tiff_path, 'r');
    bg_crop = read(t_bg); % Load the image directly
    t_bg.close();
    if ~isfloat(bg_crop)
         bg_crop = single(bg_crop); 
    end
catch ME
    fprintf('Error loading background image: %s\n', bg_tiff_path);
    fprintf('Make sure "estimated_background.tiff" (saved from Python) is in the correct path.\n');
    rethrow(ME);
end

% --- 3. Define Coordinates & Crop Original Image ---

% **FIX: Adjust crop to match Python's 0-indexed slicing convention**
% Python's [960:1200] is 240 pixels. MATLAB's equivalent is 960:1199.
crop_rows = 960:1199; % (1199 - 960 + 1 = 240)
crop_cols = 1890:1949; % (1949 - 1890 + 1 = 60)
% --- End of FIX ---

single_cap = img(crop_rows, crop_cols);

bg_crop = bg_crop * 65535;

% --- 4. Validate Image Sizes ---
% This check should now pass
if ~isequal(size(single_cap), size(bg_crop))
    fprintf('Size of capillary crop: [%d, %d]\n', size(single_cap,1), size(single_cap,2));
    fprintf('Size of background image: [%d, %d]\n', size(bg_crop,1), size(bg_crop,2));
    error('Dimension mismatch: The capillary image crop and the loaded background image are not the same size.');
else
    fprintf('Capillary crop and background image sizes match: [%d, %d]\n', size(single_cap,1), size(single_cap,2));
end

% --- 5. Define Sampling Parameters ---
x_1 = [15, 25];
num_lines = 30;                     
y_min     = 65;                     
y_max     = 75;                     
H = size(single_cap, 1); % Height of the cropped image
y_min = max(1, y_min);
y_max = min(H, y_max);
ys = linspace(y_min, y_max, num_lines);
N = round(hypot(diff(x_1), diff([y_min, y_min]))) + 1; % N based on x-coords

% --- 6. Get Profiles from BACKGROUND image ---
profiles_bg = zeros(num_lines, N);
lineXs_bg   = zeros(num_lines, N);    
lineYs_bg   = zeros(num_lines, N);

fprintf('Sampling background image across %d lines...\n', num_lines);
for i = 1:num_lines
    yi = ys(i);
    x_pair = x_1;
    y_pair = [yi, yi];  
    
    [lx, ly, p] = improfile(bg_crop, x_pair, y_pair, N, 'bilinear');
    
    profiles_bg(i, :) = p(:).';
    lineXs_bg(i, :)   = lx(:).';
    lineYs_bg(i, :)   = ly(:).';
end

% --- 7. Find the Minimum Intensity ---
min_intensity = min(profiles_bg(:));

% --- 8. Output and Save Results ---
fprintf('\n--- Background Analysis Results ---\n');
fprintf('Overall Minimum Intensity from Background Profiles: %f\n', min_intensity);
fprintf('Mean Intensity from Background Profiles: %f\n', mean(profiles_bg(:), 'omitnan'));

% (Rest of plotting and saving code follows...)

figure; 
imshow(bg_crop, []); 
hold on;
for i = 1:num_lines
    plot([x_1(1) x_1(2)], [ys(i) ys(i)], 'c-', 'LineWidth', 0.75);
end
title(sprintf('Background Sampling Lines (n=%d)', num_lines)); 
axis on;

pix_um = 0.6;
dist_px = sqrt( (lineXs_bg(1,:) - lineXs_bg(1,1)).^2 + (lineYs_bg(1,:) - lineYs_bg(1,1)).^2 );
dist_um = dist_px * pix_um;
prof_mean_bg = mean(profiles_bg, 1, 'omitnan');
prof_std_bg  = std(profiles_bg, 0, 1, 'omitnan');
prof_min_bg  = min(profiles_bg, [], 1, 'omitnan');
T_bg_stats = table((1:N).', dist_px(:), dist_um(:), ...
               prof_mean_bg(:), prof_std_bg(:), prof_min_bg(:), ...
    'VariableNames', {'Sample','Dist_px','Dist_um','MeanIntensity','StdIntensity', 'MinIntensity'});
writetable(T_bg_stats, 'background_profile_stats.csv');
fprintf('Saved background profile stats to "background_profile_stats.csv"\n');
