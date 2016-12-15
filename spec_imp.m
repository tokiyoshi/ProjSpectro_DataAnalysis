import FileClass
clear
% import cell pressure
CellPress = FileClass('cell');
[CellPress.Name,CellPress.Path] = uigetfile('*.csv','Please choose Cell Pressure','file_cell_press.csv');
CellStruct = GetData(CellPress);
% import membrane pressures
MemPress = FileClass('press'); 
[MemPress.Name,MemPress.Path] = uigetfile('*.csv','Please choose Membrane Pressure','file_cell_press.csv');
MemStruct = GetData(MemPress);
% Combining the two structures, but they conflict on the time_s field so I
% just use the Cell one
names = [fieldnames(CellStruct); fieldnames(rmfield(MemStruct, 'time_s'))];
FullStruct = cell2struct([struct2cell(CellStruct); struct2cell(rmfield(MemStruct, 'time_s'))], names, 1);

% Asking questions up front
%video?
vidprompt = 'Do you want to write video? Y/N [N]: ';
vidstr = input(vidprompt,'s');
if isempty(vidstr)
    vidstr = 'N';
end
if vidstr == 'Y'
    vidprompt2 = 'What do you want to name the video?';
    if CellPress.Path == MemPress.Path
        vidname = [MemPress.Path input(vidprompt2, 's')];
    else
        vidname = input(vidprompt2, 's');
    end
    frameprompt = 'How many frames/sec?[25]: ';
        framestr = input(frameprompt,'s');
        if isempty(framestr)
            framestr = '25';
        end
end

exprompt = 'Do you want to save excel file? Y/N [N]: ';
exstr = input(exprompt,'s');
if isempty(exstr)
    exstr = 'N';
end
%excel?
if exstr == 'Y'
    exprompt2 = 'What do you want to name the file?';
    if CellPress.Path == MemPress.Path
        exname = [MemPress.Path input(exprompt2, 's')];
    else
        exname = input(prompt, 's');
    end
end


% importing picture names into the struct
oldFolder = cd(uigetdir(CellPress.Path, 'Please choose photo directory'));
pic_struct = dir( '*.bmp');
cd(oldFolder);
pic_list = {pic_struct.name};
[FullStruct(:).('pic_name')] = deal(cell(size(FullStruct.time_s)));
for i = 1:length(FullStruct.time_s)
    time = ['(_' sprintf('%0.2f',round(FullStruct.time_s(i),2)) '_*)'];
    is_a_match = ~cellfun(@isempty,regexp(pic_list,time));
    try
        FullStruct.pic_name(i) = pic_list(is_a_match);
    catch
        FullStruct.pic_name(i) = {'N/A'};
    end
end
% adding time diff calculation
[FullStruct(:).('time_diff')] = deal(NaN(size(FullStruct.time_s)));
for i = 2:length(FullStruct.time_s) % indexing from 2 b/c 1 = null
   try FullStruct.time_diff(i) = FullStruct.time_s(i)- FullStruct.time_s(i - 1);
   catch; end
end
% adding slew rate calculation
[FullStruct(:).('slew_rate')] = deal(NaN(size(FullStruct.time_s)));
field_name = char(names(~cellfun(@isempty,regexp(names,'(pressure_*)'))));
for i = 2:length(FullStruct.time_s) % indexing from 2 b/c 1 = null
   try 
       slew = ( FullStruct.(field_name)(i) - FullStruct.(field_name)(i - 1))/FullStruct.time_diff(i);
       FullStruct.slew_rate(i) = slew;
   catch; end
end
% adding hydrodiff calculation
[FullStruct(:).('hydro_diff')] = deal(NaN(size(FullStruct.time_s)));
for i = 2:length(FullStruct.hydro_GPa) % indexing from 2 b/c 1 = null
   try FullStruct.hydro_diff(i) = FullStruct.hydro_GPa(i)- FullStruct.hydro_GPa(i - 1);
   catch; end
end
% Smoothed Spline fit (very smooth, low accuracy at points, useful for
% derivitives)
FullStruct.hydro_GPa(isnan(FullStruct.hydro_GPa))=-1.997918830000000e+02; % no NaNs -200 is a fit fail
[f, gof] = fit(FullStruct.time_s, FullStruct.hydro_GPa, 'smoothingspline', 'SmoothingParam', 0.02, 'Exclude', FullStruct.hydro_GPa<0 | FullStruct.hydro_GPa>10);
disp('A Spline has been fit, Goodness of fit is:')
disp(gof)
[FullStruct(:).('spline_hydro')] = deal(NaN(size(FullStruct.time_s)));
for i = 1:length(FullStruct.time_s) % indexing from 2 b/c 1 = null
   try FullStruct.spline_hydro(i) = feval(f,FullStruct.time_s(i));
   catch; end
end
%writing video
if vidstr == 'Y'
    outputVideo = VideoWriter([vidname '.avi']);
    outputVideo.FrameRate = str2double(framestr);
    open(outputVideo)
    for ii = 1:length(FullStruct.pic_name)
       if ~(strcmp(FullStruct.pic_name{ii},'N/A'))
           img = imread(fullfile(CellPress.Path,FullStruct.pic_name{ii}));
           if isequal(img, []) % if its blank, we write a black frame
               img = uint8(zeros(outputVideo.Height,outputVideo.Width));
           end
           position =  [1 1; 1 20; 1 40; 1 60; 1 80; 1 100; 1 120];
           overlay = {['Picture Name : ' FullStruct.pic_name{ii}] ...
               ['Time(s) : ' sprintf('%.2f',FullStruct.time_s(ii))] ...
               ['Time Delta(s) : ' sprintf('%.2f',FullStruct.time_diff(ii))] ...
               ['Membrane Pressure(bar) : ' sprintf('%.2f',FullStruct.pressure_bar(ii))] ... % validate that it's bar??
               ['Slew Rate(bar) : ' sprintf('%.2f',FullStruct.slew_rate(ii))] ...
               ['Cell Pressure Hydro(GPa) : ' sprintf('%.4f',FullStruct.hydro_GPa(ii))] ...
               ['Cell Pressure Hydro Spline(GPa)  : ' sprintf('%.4f',FullStruct.spline_hydro(ii))] ...
               };
           box_color = {'blue','yellow', 'yellow', 'green', 'green', 'red', 'red'};
           img = insertText(img,position,overlay,'FontSize',11,'BoxColor',...
    box_color,'BoxOpacity',0.2,'TextColor','white');
           if rem(ii,100) == 0
               disp(['We are ' sprintf('%03.2f', (ii/length(FullStruct.pic_name)*100)) '% through video writing'])
           end
       end
       writeVideo(outputVideo,img)
    end
    close(outputVideo)
    disp('Video written')
end
%saving excel file
if exstr == 'Y'
    % we simply remove the fields which are not the full run and then print
    disp('Excel File writing started')
    CutStruct = rmfield(FullStruct, {'Path_cell', 'Path_press'});
    writetable(struct2table(CutStruct), [exname '.xlsx']);
    disp('Excel File written')
end
disp('Analysis Complete')
