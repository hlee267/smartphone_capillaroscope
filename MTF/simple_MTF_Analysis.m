


%{
 Slant Edge Script
 File: MTFscript.m
 Written by: Patrick Granton, 
 September 2, 2010 
 Contact e-mail, patrick.granton@maastro.nl
 
Tested using Matlab 7.7.0.471 (R2008b)
including the imaging toolbox on a mac using OSX 10.5.8
 
A Gaussian fitting tool has been used in this code. You can download this 
tool on the Matlab central website here: http://www.mathworks.com/matlabcentral/fileexchange/11733-gaussian-curve-fit
 
 
%%%%%%%%%%%%%%%%%%%%Notes on Script%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
General comments:
 
This code can be used to measure the pre-sampled MTF of an image, which is a 
quantity that describes the resolution of linear imaging system. The code
is based on measuring the pre-sample MTF using a precision machined 
edge that is aligned - with respect to the columns or rows of an image - 
at an angle between 1-5 degrees.  
 
To learn more about the pre-sampled MTF consult the references at the end
of this script.

When you run this script your image containing the edge with appear with the 
cropping tool. Crop your image to the region containing only the edge. 
Double-click your cropped area for the script to continue. 


Samei, Flynn, and Reimann (Ref.2 ) have a good description on how to 
fabricate the edge to measure the pre-sampled MTF. 
 
%%%%%%%%%%%%%%%%%%%%%Begin Script%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
%}
%Identify and initialize all variables

NA = 0.79;

lambda = 532e-9;

isotropicpixelspacing = 0.00006686046; 
% isotropic detector pixel spacing in mm, (i.e. pixel pitch).  
% set this value to your detector
 
pixel_subdivision = 0.10; 
% keep between 0.03 - > 0.15  
% Samei, Flynn, and Reimann (Ref.2 )suggest that 0.1 subpixel bin spacing 
% provides a good trade-off between sampling uniformity and noise.
 
bin_pad = 0.0001;
% Bin_pad adds a small space so that all values are included the histogram 
% of edge spread distances.
 
span = 10;
% span is used to smooth the edge spread function 
% Samei, Flynn, and Reimann (Ref.2 ) use a forth weighted,
% Gaussian-weighted moving polynomial. 
 
edge_span = 4;
% Used to improve the location of the edge
 
boundplusminus = 2; 
% boundplusminus is a variable that is used to crop a small section of the
% edge in order to used to find the subpixel interpolated edge position.
 
 
boundplusminus_extra = 6;
% boundplusminus_extra incorperates addition pixel values near the edge to 
% include in the binned histogram. 
 
 
%%%%%%%%%%%%%%%%%%%%%%%%%LOAD IMAGE%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 

folder = uigetdir(pwd, 'Select folder with .tif images');
if isnumeric(folder)
    error('No folder selected');
end

files = dir(fullfile(folder,'*.tif'));
if isempty(files)
    error('No .tif files found in %s', folder);
end

% Loop over each TIFF
for idx = 1:numel(files)
    image_file = files(idx).name;
    path_name  = files(idx).folder;
    
    % Read into your original variable
    % image = double(imread(fullfile(path_name,image_file)));
    imgRaw = imread(fullfile(path_name,image_file));
    if ndims(imgRaw) > 2
        image = rgb2gray(imgRaw);
    else
        image = imgRaw;
    end
    image = double(image);
    
    fprintf('Processing %s (%d of %d)\n', image_file, idx, numel(files));
    
    % — now jump straight into your existing crop + MTF pipeline —
    
    % crop image to 50% air / 50% edge 
    h = figure('Name',['Please select region for ',image_file]); %#ok<UNRCH>
    imshow(image,[]);
    image = imcrop(h);
    close(h);
    
    % crop image to 50 % air and 50 % edge 
 
    h = figure('Name','Please select a region contain 50% Air and 50% of the edge'); hold on
    
    imshow(image,[]);
    
    image = imcrop(h);
    
    close(h);
    
    
    %{
    Threshold image using Otsu's threshold criterion on cropped image
    
    Then find the average of the two regions (i.e. air, Plexiglas)
    
    The difference between's Otsu's threshold and the mean threshold is small 
    %}
    
    level = graythresh(image);
    
    threshold =  double(((max(max(image)) - min(min(image))))*level + min(min(image)));
    
    BW1 = roicolor(image,threshold,max(max(image)));
    
    BW2 = roicolor(image,min(min(image)),threshold);
    
    Area1 = sum(image(BW1))/sum(sum(BW1));
    
    Area2 = sum(image(BW2))/sum(sum(BW2));
    
    threshold = (Area1 - Area2)/2 + Area2;  
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Detect edge and orientation
    
    BW_edge = edge(double(image),'canny',level);
    
    % Locate edge positions
    
    [A_row_pos, B_column_pos] = find(BW_edge==1);
    
    % Fit edge positions
    
    P = polyfit(B_column_pos,flipud(A_row_pos),1);
    
    % determine rough edge angle to determine orientation
    
    Angle_radians = atan(P(1));

    Angle_degrees = abs(Angle_radians/pi * 180);
    
    % show the determined edge
    
    % imshow(image + BW_edge*edge_intensity,[])
    
    [rowlength, columnlength] = size(image);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    % Determine the sub pixel edge in a particular direction. 
    % 
    
    
    if abs(Angle_radians) > pi/4 % i.e. edge is vertical
        
        % if the edge is vertical the image keeps the same orientation
        % else we transpose the image

        fprintf('Image is vertical \n');
        
        start_row = boundplusminus_extra;
        end_row = rowlength - boundplusminus_extra;
        
    else % the edge is horizontal and the image is transposed
        
        fprintf('Image is horizontal \n');

        image = image';
        
        [rowlength, columnlength] = size(image);
    
        start_row = boundplusminus_extra;
        end_row = rowlength - boundplusminus_extra;
    end
        
        
        for i = start_row:end_row
            
            %%%%%%%%%%%%%%%%%%%  USED FOR finding edge %%%%%%%%%%%%%%%%%
    
            ii = i - start_row +1;
            
            strip = image(i,:);
            
            % smooth edge to find approximate edge area
            
            window = ones(edge_span,1)/edge_span;
            
            strip_smoothed = convn(strip',window,'valid');
            
            app_edge = find(abs(diff(strip_smoothed))== max(abs(diff(strip_smoothed)))) + 2;
            
            %  in case there are more than one maxima, take the first one
            
            bound_edge_left = app_edge(1) - boundplusminus;
            
            bound_edge_right = app_edge(1) + boundplusminus;
            
            strip_cropped = (image(i,bound_edge_left:bound_edge_right));
            
            temp_y = 1:length(strip_cropped);
            
            % edge_position_temp = interp1(strip_cropped,temp_y,threshold,'pchip');  
            
            % edge_position(ii) = edge_position_temp + bound_edge_left - 1;
            [xUnique, uidx] = unique(strip_cropped);
            yUnique        = temp_y(uidx);
            edge_position_temp = interp1(xUnique, yUnique, threshold, 'pchip');
            edge_position(ii) = edge_position_temp + bound_edge_left - 1;
            
            
            %%%%%%%%%%%%%%%%%%%  USED FOR HISOGRAM %%%%%%%%%%%%%%%%%%%%
            
            
            bound_edge_left_expand = app_edge(1) - boundplusminus_extra;   
            
            bound_edge_right_expand = app_edge(1) + boundplusminus_extra;   
    
            array_values_near_edge(ii,:) = (image(i,bound_edge_left_expand:bound_edge_right_expand)); 
    
            arraypositions(ii,:) = [bound_edge_left_expand:bound_edge_right_expand];
            
        
        end
        
        %{
        
            Fit a curve to the edge of a polynomial degree 1 
            y = ax^2 + bx + c, x = (y-b)/m
        
        
            *some use a degree 2 polynomial fit though for lens aberrations in XRI. 
            Padgett and Kotre (Ref.1) suggest an iteration process could be used to
            optimize the angle of the edge but generally not necessary. 
        
        %}
        
            y = 1:length(edge_position);
            
            P = polyfit(edge_position,y,1); 
    
            m = P(1);
    
            b = P(2);
    
            xfit = ((y - b)/m);
            
            distance_from_edge = edge_position - xfit;
    
            
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% generate edge bins %%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
            
    
            array_positions_by_edge = arraypositions - (edge_position')*(ones(1,(1 + 2*boundplusminus_extra)));
        
            % size of matrix
            
            [m n] = size(array_positions_by_edge);
            
            array_values_by_edge = array_values_near_edge(1:(m*n)); 
            
            array_positions_by_edge = array_positions_by_edge(1:(m*n));
            
        
    
    % Determine bin spacing 
    
    topEdge = ((max(array_positions_by_edge))+ bin_pad + pixel_subdivision);
    botEdge = ((min(array_positions_by_edge))- bin_pad);
    binEdges = botEdge:pixel_subdivision:topEdge;
    numBins = length(binEdges) - 1;
    
    binPositions = binEdges(1:end-1) + 1/2*pixel_subdivision;
    
    % Rebinning portion
    
    [h,whichBin] = histc(array_positions_by_edge,binEdges);
    
    for i = 1:numBins
        flagBinMembers = (whichBin == i);
        binMembers = array_values_by_edge(flagBinMembers);
        binMean(i) = mean(binMembers);
        
    end
    
    
    
    ESF = binMean(2:numBins - 1); % Eliminate first, second and last array position
    
    xESF = binPositions(2:numBins - 1); % same as above comment
    
    % fill in missing data
    
    ESF_nonan = ESF(logical(1-isnan(ESF)));
    
    xESF_nonan = xESF(logical(1-isnan(ESF)));
    
    ESF = interp1(xESF_nonan,ESF_nonan,xESF,'pchip');
    
    
    % smooth the edge spread function
    
    window = ones(span,1)/span;
    
    smoothed = convn(ESF,window','valid');
    
    subplot(2,2,1)
    
    plot(xESF,ESF,xESF(round(span/2):round((length(xESF)-span/2))),smoothed);
    
    title('\fontname{Arial} The Edge Spread Function')
    
    legend('Raw ESF','Smoothed ESF (Gaussian)')
    
    xlabel('distance along the edge in pixels')
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    % Perform the MTF calculations
    
    LSF_raw = diff(ESF);
    
    LSF = -diff(smoothed);
    
    
    Nans = isnan(LSF); % remove any Nans
    
    LSF(Nans==1) = 0;
    
    
    % Normalize the LSF
    
    LSF = LSF/sum(LSF);
    
    xLSF_fit = 1:length(LSF);
    
    LSF_base_raw= LSF_raw/sum(LSF_raw);
    
    LSF_raw = LSF_raw(span/2:1:(length(LSF_raw)-span/2));
    
    LSF_raw = LSF_raw/sum(LSF_raw);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%Fit a Gaussian to the LSF fit%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    % acquire this function
    % here:http://www.mathworks.com/matlabcentral/fileexchange/11733-gaussian-curve-fit
    
    [sigma,mu,A] = mygaussfit(xLSF_fit,LSF); 
    
    yLSF_fit = A*exp(-(xLSF_fit-mu).^2/(2*sigma^2));
    
    
    
    subplot(2,2,2)
    
    plot(xESF(round(span/2):round((length(xESF)-span/2)-1)),LSF,xESF(round(span/2):round((length(xESF)-span/2)-1)),yLSF_fit,xESF(1:(length(xESF)-1)),LSF_base_raw);
    
    title('\fontname{Arial} The Line Spread Function of the Edge')
    
    legend('Smoothed LSF','Fitted LSF (Gaussian)','Raw LSF')
    
    xlabel('distance along the edge in pixels')
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    % Convert the spatial domain to frequency domain
    
    N = length(LSF);
    
    %generate the frequency axis
    
    if mod(N,2)==0
    q=-N/2:N/2-1; % N even
    else
    q=-(N-1)/2:(N-1)/2; % N odd
    end
        
    %{
    
    % Convert the spatial domain to frequency domain
    
    %}
    
    
    Fs = 1/(isotropicpixelspacing*pixel_subdivision);% sampling rate in samples per mm
    
    T = N/Fs;
        
    freq = q/T;


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %%%%Generate your MTF%%%%%
        
    MTF= abs(fft(LSF));  
    
    MTF_fit = abs(fft(yLSF_fit));
    
    MTF_raw = abs(fft(LSF_raw));
    
    subplot(2,2,3)
    
    plot(freq,fftshift(MTF),freq,fftshift(MTF_fit),freq,fftshift(MTF_raw));
    
    title('\fontname{Arial} The Modulation Transfer Function of the Edge')
    
    legend('Smoothed MTF','Fitted LSF (Gaussian)','Raw MTF')
    
    xlabel('frequency distribution')
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    zero_freq = find(freq == 0);
    
    freq = freq(zero_freq:length(freq));
    
    MTF = fftshift(MTF);
    
    MTF = MTF(zero_freq:length(MTF));
    
    MTF_fit = fftshift(MTF_fit);
    
    MTF_fit = MTF_fit(zero_freq:length(MTF_fit));
    
    MTF_raw = fftshift(MTF_raw);
    
    MTF_raw = MTF_raw(zero_freq:length(MTF_raw));
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    % Equivalent line pairs per mm @ 10% MTF
    % 2.5 LPP is equivalent to 200 um, DU et al
    % Other institutions use 50% 
    
        
    YMTFfine = 0:0.01:1;
    
    mtfpoint = find(MTF<0.05);
    
    YMTF = interp1(MTF(1:mtfpoint(1)),freq(1:mtfpoint(1)),YMTFfine,'pchip');
    
    mtfpoint = find(MTF<0.05);
    
    YMTFit = interp1(MTF_fit(1:mtfpoint(1)),freq(1:mtfpoint(1)),YMTFfine,'pchip');
    
    mtfpoint = find(MTF<0.05);
    
    YMTraw = interp1(MTF_raw(1:mtfpoint(1)),freq(1:mtfpoint(1)),YMTFfine,'pchip');
    
    
    LPP = YMTF(YMTFfine==0.09);
    
    Resolution_smoothed = (1/(LPP*2)); % in mm 
    Resolution_smoothed_LPMM_MTF9 = 1 / (2*Resolution_smoothed);
    
    LPP = YMTFit(YMTFfine==0.1);
    
    Resolution_fit = (1/(LPP*2)); % in mm 
    Resolution_fit_LPMM_MTF9 = 1 / (2*Resolution_fit);
    
    LPP = YMTraw(YMTFfine==0.1);
    
    Resolution_raw = (1/(LPP*2)); % in mm 
    Resolution_raw_LPMM_MTF9 = 1 / (2*Resolution_raw);
    
    % Calculate Ideal MTF 
    u_cutoff_meters = 2*NA/lambda;
    u_cutoff_mm = u_cutoff_meters * 1e-3;
    shortaxis = length(freq)/4;
    u_mm = linspace(0,u_cutoff_mm, length(1:round(shortaxis)));

    % Calculate the MTF using the ideal diffraction-limited formula
    MTFIdeal = (2 / pi) * ( acos(u_mm / u_cutoff_mm) - (u_mm / u_cutoff_mm) .* sqrt(1 - (u_mm / u_cutoff_mm).^2));


    subplot(2,2,4)
    
    shortaxis = length(freq)/4;
    
    plot(freq(1:round(shortaxis)),MTF(1:round(shortaxis)),freq(1:round(shortaxis)),MTF_fit(1:round(shortaxis)),freq(1:round(shortaxis)),MTF_raw(1:round(shortaxis)), u_mm, MTFIdeal);
    
    title('\fontname{Arial} The Modulation Transfer Function of the Edge (ZOOMED)')
    
    legend(sprintf('Smoothed MTF Resolution = %3.3f microns',1000*Resolution_smoothed), sprintf('Fitted LSF (Gaussian) MTF Resolution = %3.3f microns', 1000*Resolution_fit),sprintf('Raw MTF Resolution = %3.3f microns',1000*Resolution_raw), sprintf('Ideal MTF'));
    
    xlabel('The pre-sampled MTF in line pairs per mm')
    
    
    
    % … all the way to your final subplot(2,2,4) …
    % (A) Save the figure
    figName = fullfile(path_name, [image_file '_MTF.png']);
    saveas(gcf, figName);
    
    % (B) Save the numeric results
    outFile = fullfile(path_name, [image_file '_MTFresults.mat']);
    save(outFile, ...
         'ESF', 'LSF', 'MTF', ...
         'Resolution_smoothed', ...
         'Resolution_fit', ...
         'Resolution_raw');

    % Optional: pause before next
    uiwait(msgbox(sprintf('Finished %s',image_file),'Continue'));
    

end

disp('Done with all images.');
return  % prevent any stray code from running again

 
%{
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
 
References:
 
(1) Padgett and Kotre, 
    "Development and application of programs to measure modulation transfer
    function, noise power spectrum and detective quantum efficiency,"
    Radiation Protection Dosimetry, Vol. 117, No. 1-3, pp 283-287, (2005)
 
(2) Samei, Flynn, and Reimann,
    "Measuring the presampled MTF of digital radiographic systems"
    Medical Physics, Vol. 25, No.1, pp 102-113, (1998)
 
(3) Judy,
    "The line spread function and modulation transfer function of a computer
    tomographic scanner,"
    Medical Physics, Vol.3, No.4, pp 233-236, (1975)
 
(4) Fujitia et al. 
    " A simple Method for determining the modulation transfer function in 
    digital radiography,"
    IEEE transactions on medical imaging, Vol. 11, No.1, (1992)
 
(5) Du et al. 
    " A quality assurance phantom for the performance evaluation of
    volumetric micro-CT systems,"
    Physics Medicine Biology, Vol. 52, pp 7087-7108, (2007)
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
%}
 
 
 
 
 
 
 
