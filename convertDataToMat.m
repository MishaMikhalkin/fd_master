function [  ] = convertDataToMat( file )
%function [  ] = convertDataToMat( file ) - экспортирует файл с данными в
%MAT-файл. Файл с данными отметчика экспортируется в исходном виде,
%а так же в интерполированном виде.
%
%Аргументы:
%   file - имя экспортируемого файла.

loadedFile = loadData(file);
if loadedFile.frequency == 25000
    save(regexprep(file,'.txt$',''),'loadedFile','-v7');
elseif loadedFile.frequency == 100000
    save(regexprep(file,'.txt$',''),'loadedFile','-v7');
    newX = (0:1/25000:loadedFile.data(end,1))';
    interpolatedData = interp1(loadedFile.data(:,1),loadedFile.data(:,2:end),newX','linear');
    loadedFile.data = [newX, interpolatedData];
    loadedFile.frequency = 25000;
    loadedFile.interpolated = 1;
    save(regexprep(file,'.txt$','_interp'),'loadedFile','-v7');
end

end

