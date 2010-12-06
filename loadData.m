function [ data ] = loadData( fileName )
%function [data] = loadData(fileName) загружает файл с данными
%
%Аргументы:
%  fileName - полное имя загружаемого файла
%Выходные параметры:
%  data - структура с загруженными данными:
%    data.source - название исходного файла с данными;
%	 data.frequency - частота;
%	 data.data - матрица данных, в которой:
%		     data.data(:,1) - время поступления;
%            data.data(:,2:end) - считанные данные.
%Ошибки:
%  Err:BadArg - некорректный аргумент функции
%  Err:File - ошибка при работе с файлом
%

if nargin < 1
   error('Err:BadArg','Argument fileName must be a specified'); 
end

if ~ischar(fileName)
   error('Err:BadArg','Argument fileName must be a string'); 
end

convFileName = convertInputFile(fileName);

data.source = convFileName;
data.data = dlmread(convFileName);
data.frequency = data.data(1,1);
data.data = data.data(2:end,:);
data.data = [(0:size(data.data,1)-1)', data.data];
data.data(:,1) = data.data(:,1)/data.frequency;
end

function [convFileName] = convertInputFile(fileName)

convFileName = fileName;

[inputFile, err] = fopen(convFileName,'r+');
if inputFile == -1
   error('Err:File',err); 
end

temp = fscanf(inputFile,'%d %d\n',2);
originalData = textscan(inputFile,'%[^\n]\n');
fclose(inputFile);
[outputFile, err] = fopen(convFileName,'w');
if outputFile == -1
   error('Err:File',err); 
end
fprintf(outputFile,'%d %d\n',temp(1),temp(2));
for i=1:size(originalData{1})
   originalData{1}{i} = regexprep(regexprep(originalData{1}{i},',','.'),'[^0-9 .,+-Ee]',' ');
   fprintf(outputFile,'%s\n',originalData{1}{i});
end

fclose(outputFile);

end