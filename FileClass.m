classdef FileClass
    %FILECLASS Imported Files go in here
    %   We attempt to import csvs through this scheme 
    properties
        Name
        Path
        Type
        HeadInd
        Headers
        Data
        Struct
    end
    properties (Constant)
        head_dict = containers.Map({'cell', 'spec', 'press'},[4, 2, 1]);
    end
    methods
        function obj = FileClass(type)
            obj.Type = type;
            obj.HeadInd = obj.head_dict(obj.Type); %setting where HeadInd is based off type
        end
        function name = FullPath(obj)
            name = strcat(obj.Path, obj.Name);
        end
        function ret_struct = GetData(obj)
            data = importdata(FullPath(obj),',', obj.HeadInd);
            obj.Headers = data.colheaders;
            obj.Data = data.data;
            obj.Struct = struct(strcat('Path_',obj.Type),FullPath(obj));
            for i = 1:length(obj.Headers)
                % We create a structure which is based off of the
                % headers/data, we replace all whitespace, brakets and
                % dashes with underscores for MatLab to accept
                head = regexprep((obj.Headers{i}),'[\(\-\s]', '_');
%                 head = regexprep(head,'[\(]', '_in_');
                head = regexprep(head,'[\)]', '');
                head = regexprep(head,'(__)', '_');
                head = regexprep(head,'_$', '');
                obj.Struct.(head) = obj.Data(:,i); 
            end
            ret_struct = obj.Struct;
        end
    end
    
end