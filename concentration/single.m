img_tiff = "wide/C2-capillaries_green.tif";

t = Tiff(img_tiff, 'r');
img = read(t);
t.close();

% figure;
% imshow(img);
% hold on;

cropped_img = img(2500:3500, 3000:4500);
single_cap = cropped_img(560:1000, 900:1025);

figure;
imshow(cropped_img);
hold on;

single_cap_1 = cropped_img(480:800, 420:530);
figure;
imshow(single_cap_1);
hold on;

x_1 = [40, 65];
y_1 = [55, 55];

N = round(hypot(diff(x_1), diff(y_1))) + 1;           % samples ~ length in px
[line_x, line_y, intensity_profile] = improfile(single_cap_1, x_1, y_1, N, 'bilinear');

figure;
plot(intensity_profile);
xlabel('Position');
ylabel('Intensity');
title('Intensity Profile along Line');
grid on;

figure; 
imshow(single_cap_1, []); 
hold on;
plot(x_1, y_1, 'r-', 'LineWidth', 1.5);
title('Single Capillary with Profile Line');
axis on;


N     = numel(intensity_profile);
Imean = mean(intensity_profile);
Imin  = min(intensity_profile);
Imax  = max(intensity_profile);
Istd  = std(intensity_profile);
Imode = mode(intensity_profile);

fprintf('Number of samples (N): %d\n', N);
fprintf('Mean intensity      : %.3f\n', Imean);
fprintf('Min intensity       : %.3f\n', Imin);
fprintf('Max intensity       : %.3f\n', Imax);
fprintf('Std  deviation      : %.3f\n', Istd);
fprintf('Mode intensity      : %.3f\n', Imode);


% --- build a list (index, X, Y, distance, intensity)
pix_um = 0.6;                                         % your scale
idx      = (1:numel(intensity_profile))';
dist_px  = sqrt( (line_x - line_x(1)).^2 + (line_y - line_y(1)).^2 );
dist_um  = dist_px * pix_um;

T = table(idx, line_x(:), line_y(:), dist_px(:), intensity_profile(:), ...
    'VariableNames', {'Sample','X','Y','Dist_px','Intensity'});

disp(T);                                              % prints the full list
writetable(T, 'intensity_profile.csv');               % saves to CSV
