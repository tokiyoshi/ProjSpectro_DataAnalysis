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
%saving excel file
prompt = 'Do you want to save excel file? Y/N [N]: ';
str = input(prompt,'s');
if isempty(str)
    str = 'N';
end
if str == 'Y'
    prompt = 'What do you want to name the file?';
    if CellPress.Path == MemPress.Path
        filename = [MemPress.Path input(prompt, 's')];
    else
        filename = input(prompt, 's');
    end
    % we simply remove the fields which are not the full run and then print
    CutStruct = rmfield(FullStruct, {'Path_cell', 'Path_press'});
    writetable(struct2table(CutStruct), [filename '.xlsx']);
end
