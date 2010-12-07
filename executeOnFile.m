function [ info ] = executeOnFile( path , func)
%function [ ] = executeOnFile( path , func) выполняет функцию над файлом.
% 
%Аргуметы:
%   path - имя файла, над которым должна быть выполнена функцию
%   func - функция, которая должна быть выполнена над фалом
%Результат:
%   info - структура с информацией о результатах работы функции:
%       file - имя файла
%       status - результат работы функции func (0 - возникла ошибка)
%       error - информация об ошибке
%       
%Ошибки:
%   Err:BadArg - неправильные аргументы
%
%Замечание:
%   Если path является папкой, то функция executeOnFile будет рекурсивно
%   вызвана для всех входящих в нее файлов (в том числе и папки).
if nargin<2
    error('Err:BadArg','Function require 2 arguments');
end

if ~ischar(path)
   error('Err:BadArg','Arguments path must be string');
end

if ~isa(func,'function_handle')
   error('Err:BadArg','Arguments func must be function handler');
end

info = struct('file',[],'status',[],'error',[]);

if isdir(path)
    files = dir(path);
    for i = 1:size(files,1)
        if ~strcmp(files(i,1).name,'.') && ~strcmp(files(i,1).name,'..')
            result = executeOnFile(fullfile(path,files(i,1).name),func);
            info.file = strvcat(info.file,result.file);
            info.status = [info.status; result.status];
            info.error = strvcat(info.error, result.error);
        end
    end
else
   try
       info.file = path;
       func(path);
   catch exception;
       info.status = 0;
       info.error = exception.message;
   end
end

end
