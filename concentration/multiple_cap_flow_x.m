% 1. Load the Image
img_filename = "../_images/flow_snaps/pre2_OG.png"; 
img = imread(img_filename);

if size(img, 3) == 3
    img = rgb2gray(img); 
end

% --- CHANGE 1: Define Geometry for Vertical Lines ---
% y_range: The START and END pixel height (vertical length of the profile)
y_range = [130, 300];  

% x_min / x_max: The LEFT and RIGHT bounds to scan across
x_min = 420;       
x_max = 440; 

% Number of vertical lines to draw between x_min and x_max
num_lines = 30;                     

figure;
imshow(img, []); 
hold on;

H = size(img, 1); 
W = size(img, 2);

% Ensure bounds don't go outside the full image
x_min = max(1, x_min);
x_max = min(W, x_max);

% --- CHANGE 2: Iterate over X instead of Y ---
xs = linspace(x_min, x_max, num_lines);

% Calculate N based on the height (y_range), not width
N = round(diff(y_range)) + 1; 

profiles = zeros(num_lines, N);
lineXs   = zeros(num_lines, N);    
lineYs   = zeros(num_lines, N);

for i = 1:num_lines
    xi = xs(i);
    
    % --- CHANGE 3: X is constant, Y varies ---
    x_pair = [xi, xi];      % The line is vertical, so X is constant
    y_pair = y_range;       % The line runs from y_start to y_end
    
    [lx, ly, p] = improfile(img, x_pair, y_pair, N, 'bilinear');
    
    profiles(i, :) = p(:).';
    lineXs(i, :)   = lx(:).';
    lineYs(i, :)   = ly(:).';
end

pix_um = 0.6;  
dist_px = sqrt( (lineXs(1,:) - lineXs(1,1)).^2 + (lineYs(1,:) - lineYs(1,1)).^2 );
dist_um = dist_px * pix_um;

prof_mean = mean(profiles, 1, 'omitnan');
prof_std  = std(profiles, 0, 1, 'omitnan');

% Visualization on the full image
figure; imshow(img, []); hold on;
for i = 1:num_lines
    % --- CHANGE 4: Plot Vertical Lines ---
    plot([xs(i) xs(i)], [y_range(1) y_range(2)], 'r-', 'LineWidth', 0.75);
end
title(sprintf('Vertical Sampling lines (n=%d)', num_lines)); axis on;

% Plotting Profiles
figure; hold on; grid on; box on;
h_profiles = gobjects(num_lines,1);
for i = 1:num_lines
    h_profiles(i) = plot(dist_um, profiles(i,:), 'LineWidth', 0.9, ...
        'DisplayName', sprintf('x = %.2f px', xs(i)));
end

% Mean profile
h_mean = plot(dist_um, prof_mean, 'k-', 'LineWidth', 2, 'DisplayName', 'mean');
xlabel('Distance (\mum)'); ylabel('Intensity');
title('Intensity profiles (Vertical Cuts)');
legend('show','Location','best'); legend boxoff

figure; hold on; grid on; box on;
fill([dist_um, fliplr(dist_um)], ...
     [prof_mean+prof_std, fliplr(prof_mean-prof_std)], ...
     [0.9 0.9 0.9], 'EdgeColor', 'none'); 
plot(dist_um, prof_mean, 'k-', 'LineWidth', 2);
xlabel('Distance (\mum)'); ylabel('Intensity');
title('Average intensity profile (mean \pm 1 SD)');
set(gca,'Layer','top');

% Save results
T_wide = array2table([dist_um(:), profiles.'], ...
                     'VariableNames', ['Dist_um', compose('Line_%02d',1:num_lines)]);
T_wide.Mean = prof_mean(:);
T_wide.Std  = prof_std(:);

T_mean = table((1:N).', dist_px(:), dist_um(:), ...
               prof_mean(:), prof_std(:), ...
    'VariableNames', {'Sample','Dist_px','Dist_um','MeanIntensity','StdIntensity'});

writetable(T_wide, 'flow_intensity_profiles_wide_vertical.csv');
writetable(T_mean, 'flow_intensity_profile_mean_vertical.csv');