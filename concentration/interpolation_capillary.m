data = readtable('intensity_profile_mean.csv');

x  = data.Dist_um;
y  = data.MeanIntensity;
sd = data.StdIntensity;

% choosing background regions
bg_mask = (x <= 10) | (x >= 35);
xb = x(bg_mask);
yb = y(bg_mask);


% interpolation methods
% quadraic polynomial
p = polyfit(xb, yb, 2);
bg_poly = polyval(p, x);

% cubic smoothing spline 
bg_spline = csaps(xb, yb, 0.9, x);  % smoothing parameter in [0,1]

% linear interpolation 
%    'extrap' ensures values are defined across full x range.
bg_lin = interp1(xb, yb, x, 'linear', 'extrap');


% Corrected profiles (signal - background)
corr_poly   = y - bg_poly;
corr_spline = y - bg_spline;
corr_lin    = y - bg_lin;

out = data; % keeps original columns
out.BG_Poly            = bg_poly;
out.BG_Spline          = bg_spline;
out.BG_LinearInterp    = bg_lin;

out.Corr_Poly          = corr_poly;
out.Corr_Spline        = corr_spline;
out.Corr_LinearInterp  = corr_lin;

writetable(out, 'concentration/intensity_profile_corrected_all.csv');


% Plots
figure;
fill([x; flipud(x)], [y-sd; flipud(y+sd)], [0.8 0.8 0.8], 'EdgeColor','none'); hold on;
plot(x, y, 'k', 'LineWidth', 1.5);
plot(x, bg_poly,   'r--', 'LineWidth', 1.5);
plot(x, bg_spline, 'b-.', 'LineWidth', 1.5);
plot(x, bg_lin,    'g-',  'LineWidth', 1.2);
xlabel('Distance (\mum)'); ylabel('Intensity');
title('Original Profile with Interpolation Techniques');
legend('\pm1 SD','Original','Poly (deg 2)','Cubic Spline','Linear Interp','Location','best');

figure;
plot(x, corr_poly,   'r-', 'LineWidth', 1.5); hold on;
plot(x, corr_spline, 'b-', 'LineWidth', 1.5);
plot(x, corr_lin,    'g-', 'LineWidth', 1.5);
yline(0,'k--');
xlabel('Distance (\mum)'); ylabel('Corrected Intensity');
title('Background-corrected profiles');
legend('Corrected (Poly)','Corrected (Spline)','Corrected (Linear Interp)','Baseline','Location','best');
