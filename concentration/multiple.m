img_tiff = "_images/C2-20250829_001448.tif";
t = Tiff(img_tiff, 'r');
img = read(t);
t.close();

single_cap = img(7000:8500, 10000:10250);

figure;
imshow(single_cap, []);
hold on;

x_1 = [60, 105];
y_1 = [330, 330];

num_lines = 20;                     % ~20 profiles
y_min     = 320;                     % lowest row to sample (inclusive)
y_max     = 340;                     % highest row to sample (inclusive)

H = size(single_cap, 1);
y_min = max(1, y_min);
y_max = min(H, y_max);

% equally spaced y's between y_min and y_max
ys = linspace(y_min, y_max, num_lines);

% number of samples along each line (same as you used for a single line)
N = round(hypot(diff(x_1), diff(y_1))) + 1;

% preallocate: one row per line, N columns per profile
profiles = zeros(num_lines, N);
lineXs   = zeros(num_lines, N);    % store x samples (for completeness)
lineYs   = zeros(num_lines, N);

for i = 1:num_lines
    yi = ys(i);
    x_pair = x_1;
    y_pair = [yi, yi];  % horizontal line at this y

    [lx, ly, p] = improfile(single_cap, x_pair, y_pair, N, 'bilinear');
    profiles(i, :) = p(:).';
    lineXs(i, :)   = lx(:).';
    lineYs(i, :)   = ly(:).';
end

% distance axis (pixels and microns) using the first line's samples
pix_um = 1.74;  % your scale
dist_px = sqrt( (lineXs(1,:) - lineXs(1,1)).^2 + (lineYs(1,:) - lineYs(1,1)).^2 );
dist_um = dist_px * pix_um;

% average & std across lines (per-sample)
prof_mean = mean(profiles, 1, 'omitnan');
prof_std  = std(profiles, 0, 1, 'omitnan');

% -------- plots --------
% --- show where lines are sampled on the image (optional viz)
figure; imshow(single_cap, []); hold on;
for i = 1:num_lines
    plot([x_1(1) x_1(2)], [ys(i) ys(i)], 'r-', 'LineWidth', 0.75);
end
title(sprintf('Sampling lines (n=%d)', num_lines)); axis on;

% --- plot the profiles and label each with its y coordinate
figure; hold on; grid on; box on;

h_profiles = gobjects(num_lines,1);
for i = 1:num_lines
    % Use DisplayName so legend picks it up
    h_profiles(i) = plot(dist_um, profiles(i,:), 'LineWidth', 0.9, ...
        'DisplayName', sprintf('y = %.2f px', ys(i)));
end

% mean profile
h_mean = plot(dist_um, prof_mean, 'k-', 'LineWidth', 2, 'DisplayName', 'mean');

xlabel('Distance (\mum)'); ylabel('Intensity');
title('Intensity profiles (individual + mean)');
legend('show','Location','best'); legend boxoff

figure; hold on; grid on; box on;
fill([dist_um, fliplr(dist_um)], ...
     [prof_mean+prof_std, fliplr(prof_mean-prof_std)], ...
     [0.9 0.9 0.9], 'EdgeColor', 'none');                 % shaded band
plot(dist_um, prof_mean, 'k-', 'LineWidth', 2);
xlabel('Distance (\mum)'); ylabel('Intensity');
title('Average intensity profile (mean \pm 1 SD)');
set(gca,'Layer','top');

T_wide = array2table([dist_um(:), profiles.'], ...
                     'VariableNames', ['Dist_um', compose('Line_%02d',1:num_lines)]);
T_wide.Mean = prof_mean(:);
T_wide.Std  = prof_std(:);

T_mean = table((1:N).', dist_px(:), dist_um(:), ...
               prof_mean(:), prof_std(:), ...
    'VariableNames', {'Sample','Dist_px','Dist_um','MeanIntensity','StdIntensity'});

writetable(T_wide, 'intensity_profiles_wide.csv');
writetable(T_mean, 'intensity_profile_mean.csv');


