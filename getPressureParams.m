function [result] = getPressureParams(pressure, psi, nQuants, windowLen, windowStep, dispType, levelCrossingValue)
%Назначение:
%Формат вызова:
%Вход:
%	pressure                - ординаты давления
%   psi                     - погрешность определения максимумов и
%                             минимумов давления
%   nQuants                 - количество квантов в секунду
%   windowLen               - длинна окна для расчета стационарности по
%   дисперсии
%   windowStep              - шаг окна для расчета стационарности по
%   дисперсии
%   dispType                - параметры отображения
%   levelCrossingValue      - аргумент определяет тип процесса - если
%   значение аргумента [], то процесс на входе - чистое сжатие, иначе
%   необходимо задать уровень по которому отсекать значение процесса

%Выход:
%	result                  - структура результата
%	result.pressurePeak     - значения пиков давления
%   result.pressurePeakTime - значения времени пиков давления
%Пример:
%   TODO: доделать обработку входных параметров
%   TODO: оценку рассчитанных параметров
%   TODO: сделать оценку параметров на лету

dt = 1/nQuants;
% максимальный глобальный элемент
max_elem = -inf;
% максимальный элемент за цикл
max_loc_elem = -inf;
% время максимального элемента за цикл
max_loc_time = 0;
% минимальный глобальный элемент
min_elem = inf;
% минимальный элемент за цикл
min_loc_elem = inf;
% индикатор последнего пика давления
currPeakIndicator = 0;
% индикатор последнего пика давления
lastPeakIndicator = 0;
% время последнего пика давления
lastPeakTime = 0;

% точность в долях единицы 
psi = 0.05;
% флаг поиска локального максимума
searchMaxFlag = 0;
% длинна последовательности
len = length(pressure);

% текущий тип диспрерсии по производной
currVarType = 0;

% массив значений давления в момент впрыска
injectionStart = [];
% массив времени впрыска
injectionStartTime = [];
% флаг записи момента впрыска в память
injectionStartSaveFlag = 1;

% массив времен опережения зажигания
injectionBeforeTime = [];
% массив времен длительности впрыска
injectionDurationTime = [];


% значение давления при окончании горения
injectionLast = 0;
% значение времени окончания горения
injectionLastTime = 0;
% массив сохраненных давлений окончания горения
injectionFinish = [];
% массив сохраненных времени окончания горения
injectionFinishTime = [];
% флаг записи значени давления при окончании горения в массив
injectionFinishSaveFlag = 1;
% окно для расчета стационарности производной по дисперсии
window = zeros(1, windowLen);
% значение дисперсии производной
windowDiffVar = [];

psiVar = 0.00005;
% значение мат ожидания производной
windowDiffMean = [];
% время расчетов параметров производной
windowDiffVarTime = [];

% значения пиков давления
pressurePeak = [];
% время пиков давления
pressurePeakTime = [];

% значениея минимумов давления
pressureMin = [inf];
% признак установки минимума
pressureMinFounded = 0;

% обработка входных параметров
if (nargin == 7) && (~isempty(levelCrossingValue))
    % уровень 
    pressureLevel = levelCrossingValue(1,1);
    clearPressureProcessFlag = 0;
else
    % уровень 
    pressureLevel = 0;
    clearPressureProcessFlag = 1;
end
% процент выставления уровня от максимального давления 
pressureLevelPercent = 60;
% флаг уровеня давления
pressureLevelFlag = 0;
% время пересечения уровня
pressureLevelTime = [];
pressureLevelPeak = [];

% флаг максимального давления
% если значение  1 - то значение давления близко к максимальному
% если значение -1 - то значение давления близко к минимальному
% если значение  0 - то значение промежуточное
pressureTypeFlag = 0;
% флаг означающий сохранение значения значения
pressurePeakSaveFlag = 1;

% флаг означающий сохранение локального минимума
pressureMinSaveFlag = 1;

% tmp var
t_max_elem = [];
t_max_elem_i = [];
t_min_elem = [];
t_min_elem_i = [];
t_pressureTypeFlag = [0];
t_pressurePeakSaveFlag = [0];
t_currVarType = [0];
t_injectionStartSaveFlag = [0];
t_injectionFinishSaveFlag = [0];
% перебираем последовательно все элементы
for i = 2 : len
    
%     if (mod(i, 10000) == 0)
%         i / 2000000 * 100
%     end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % поиск глобальных максимумов и минимумов
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % поиск максимального глобального элемента 
    if (max_elem < pressure(1,i))
        max_elem = pressure(1,i);
        %>>>%
        %t_max_elem = [t_max_elem max_elem];
        %t_max_elem_i = [t_max_elem_i i];
    end
    % поиск минимального глобального элемента 
    %if (min_elem > pressure(1,i))
    %    min_elem = pressure(1,i);
    %    %>>>%
    %    %t_min_elem = [t_min_elem min_elem];
    %    %t_min_elem_i = [t_min_elem_i i];
    %end
    
    % пока не найден хотя бы один локальный минимум, считаем его значением
    % текущее минимальное значение
    if (pressureMinFounded == 0) && (pressure(1,i) < pressureMin(1,1))
        pressureMin = [pressure(1,i)];
    end

%     i
%     pressure(1,i)
%     pressureLevel
%     pressure(1,(i-1))
    % поиск времени пересечения уровня
     if (pressurePeakSaveFlag == 1) && (pressureLevelFlag == 1) && (pressure(1,i) > pressureLevel) && (pressure(1,(i-1)) < pressureLevel) 
         pressureLevelPeak = [pressureLevelPeak pressure(1,i)];
         pressureLevelTime = [pressureLevelTime i];
     end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % установка флагов давления
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % устанавливаем флаг нормального давления
    pressureTypeFlag = 0;
    % поиск значений давления отличающегося от максимального на заданную
    % погрешность
    if (abs((max_elem - pressure(1,i))/max_elem) < psi) 
        % устанавливаем флаг максимального давления
        pressureTypeFlag = 1;
    end
    % поиск значений давления отличающихсф от минимального на заданную
    % погрешность
    %if (abs((pressure(1,i) - min_elem)/min_elem) < psi) 
    % поиск значений давления отличающихся от среднего минимального на
    % заданную погрешность
    if (abs((pressure(1,i) - mean(pressureMin))/mean(pressureMin)) < psi)
        % устанавливаем флаг минимального давления давления
        pressureTypeFlag = -1;
    end

    %>>>%
    %t_pressureTypeFlag = [t_pressureTypeFlag pressureTypeFlag];
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % поиск максимального давления
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % поиск локального максимального значения
    if (pressureTypeFlag == 1) && (max_loc_elem < pressure(1,i))
        max_loc_elem = pressure(1,i);
        max_loc_time = i;
        % устанавливаем флаг необходимости записи найденного значения
        pressurePeakSaveFlag = 0;
    end
    % поиск локального минимума
    if (pressureTypeFlag == -1) && (min_loc_elem > pressure(1,i))
       min_loc_elem = pressure(1,i);
       pressureMinSaveFlag = 0;
    end
    % запись найденного локального максимума
    if (pressureTypeFlag == -1) && (pressurePeakSaveFlag == 0) 

        % выставление уровня от максимального давления
        if (clearPressureProcessFlag == 1)
            pressureLevel = max_loc_elem * (pressureLevelPercent / 100);
        end
        pressureLevelFlag = 1;
        
        
        lastPeakIndicator = currPeakIndicator;
        % устанавливаем флаг для отсечения ненужных максимумов
        currPeakIndicator = (max_loc_time - lastPeakTime)/max_loc_time;
        lastPeakTime = max_loc_time;        
        if (currPeakIndicator < lastPeakIndicator)
            % записываем данные о максимальном давлении
            pressurePeak = [pressurePeak max_loc_elem];
            % записываем данные о времени максимального давления
            pressurePeakTime = [pressurePeakTime max_loc_time];
            % сбрасываем флаг поиска максимального давления
            pressurePeakSaveFlag = 1;
            % сбрасываем значения максимального давления
            max_loc_elem = -inf;
            % записываем время прошедшее от последнего зажигания
            if (length(injectionStartTime) > 0)
                injectionBeforeTime = [injectionBeforeTime (max_loc_time - last(injectionStartTime))];
            end

            
        else
            % записываем данные о максимальном давлении
            pressurePeak = [max_loc_elem];
            % записываем данные о времени максимального давления
            pressurePeakTime = [max_loc_time];
            % сбрасываем флаг поиска максимального давления
            pressurePeakSaveFlag = 1;
            % сбрасываем значения максимального давления
            max_loc_elem = -inf;
            % записываем время прошедшее от последнего зажигания
            if (length(injectionStartTime) > 0)
                injectionBeforeTime = [(max_loc_time - last(injectionStartTime))];
            end

            pressureLevelTime = [];
            pressureLevelPeak = [];
        end
        
    end
    
    %>>>%
    %t_pressurePeakSaveFlag = [t_pressurePeakSaveFlag pressurePeakSaveFlag];
    
    % добавляем найденный локальный минимум в вектор локальных минимумов
    if (pressureTypeFlag == 1) && (pressureMinSaveFlag == 0)
        if(pressureMinFounded == 0)
            pressureMin = [min_loc_elem];
            pressureMinFounded = 1;
        else
            pressureMin = [pressureMin min_loc_elem];
        end
        min_loc_elem = inf;
        pressureMinSaveFlag = 1;
    end
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % расчет опережения зажигания
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % вычисляем производную
    window(1, mod(i,windowLen) + 1) = pressure(1, i) - pressure(1, i-1);

    % вычисляем дисперсию c шагом равным половине окна
    if ((i > windowLen + 1) && (mod(i,floor(windowStep)) == 0))
        currVar = var(window);
        currMean = mean(window);
        
        % определяем тип стационарности по дисперсии производной давления
        if (currVar < psiVar)
            currVarType = 1;
        else
            currVarType = 0;
        end
        % записываем значение мат ожидания и дисперсии по производной
        %windowDiffVar = [windowDiffVar, currVar];
        %windowDiffMean = [windowDiffMean, currMean];
        %windowDiffVarTime = [windowDiffVarTime, i];
    end   
    
    % если мы достигли минимального давления то ждем следующего впрыска
    if (pressureTypeFlag == -1)
        injectionStartSaveFlag = 0;
    end
    % отсекаем начало впрыска
    if ((currVarType == 0) && (injectionStartSaveFlag == 0))
        if (length(pressurePeak) > 2)
            injectionStart = [injectionStart pressure(1,i)];
            injectionStartTime = [injectionStartTime i];
            injectionStartSaveFlag = 1; 
        end
    end
    
    % отсекаем окончание впрыска
    if (currVarType == 0) 
        injectionLast = pressure(1,i);
        injectionLastTime = i;
        injectionFinishSaveFlag = 0;
    end
    % записываем окончание впрыска
    if ((pressureTypeFlag == -1) && (injectionFinishSaveFlag == 0))
        if (length(pressurePeak) > 2)
            injectionFinish = [injectionFinish injectionLast];
            injectionFinishTime = [injectionFinishTime injectionLastTime];
            injectionFinishSaveFlag = 1;
            
            if (length(injectionStartTime) > 0)
                injectionDurationTime = [injectionDurationTime (injectionLastTime - last(injectionStartTime))];
            end
        end
    end

%     t_currVarType = [t_currVarType currVarType];    
%     t_injectionStartSaveFlag = [t_injectionStartSaveFlag injectionStartSaveFlag];
%     t_injectionFinishSaveFlag = [t_injectionFinishSaveFlag injectionFinishSaveFlag];
end

result.fs = nQuants;
result.psi = psi;
result.windowLen = windowLen;
result.windowStep = windowStep;
result.pressurePeak = pressurePeak;
result.pressurePeakTime = pressurePeakTime .* dt;
result.injectionStart = injectionStart;
result.injectionStartTime = injectionStartTime .* dt;
result.injectionBeforeTime = injectionBeforeTime .* dt;
result.injectionFinish = injectionFinish;
result.injectionFinishTime = injectionFinishTime .* dt;
result.injectionDurationTime = injectionDurationTime .* dt;
result.windowDiffVar = windowDiffVar;
result.windowDiffMean = windowDiffMean;
result.windowDiffVarTime = windowDiffVarTime .* dt;
result.pressureLevel = pressureLevel;
result.pressureLevelPercent = pressureLevelPercent;
result.pressureLevelPeak = pressureLevelPeak;
result.pressureLevelTime = pressureLevelTime .* dt;

result.t_max_elem = t_max_elem;
result.t_max_elem_i = t_max_elem_i .* dt;
result.t_min_elem = t_min_elem;
result.t_min_elem_i = t_min_elem_i .* dt;
result.t_pressureTypeFlag = t_pressureTypeFlag ;
result.t_pressurePeakSaveFlag = t_pressurePeakSaveFlag;
result.t_currVarType = t_currVarType;
result.t_injectionStartSaveFlag = t_injectionStartSaveFlag;
result.t_injectionFinishSaveFlag = t_injectionFinishSaveFlag;

if (nargin == 6) 
    if (dispType == 1)
        disp('Results:')
        disp(sprintf('pressure peaks  -> min: %1.2f   max: %1.2f   mean: %1.2f   var: %1.4f     %%: %2.2f', ...
            min(pressurePeak), max(pressurePeak), mean(pressurePeak), var(pressurePeak), ...
            std(pressurePeak)/mean(pressurePeak)*100 ));
        timeDiffs = diff(result.pressurePeakTime);
        disp(sprintf('time cycles     -> min: %1.4f max: %1.4f mean: %1.4f var: %1.8f %%: %2.2f', ...
            min(timeDiffs), max(timeDiffs), mean(timeDiffs), var(timeDiffs), std(timeDiffs)/mean(timeDiffs)*100));
        if ((length(injectionStart)) > 0)
            disp(sprintf('injection peaks -> min: %1.2f   max: %1.2f   mean: %1.2f   var: %1.4f     %%: %2.2f', ...
                min(injectionStart), max(injectionStart), mean(injectionStart), var(injectionStart), ...
                std(injectionStart)/mean(injectionStart)*100));
        end
        if ((length(injectionStart)) > 1)
            timeDiffs = diff(result.injectionStartTime);
            disp(sprintf('injection time  -> min: %1.4f max: %1.4f mean: %1.4f var: %1.8f %%: %2.2f', ...
                min(timeDiffs), max(timeDiffs), mean(timeDiffs), var(timeDiffs), std(timeDiffs)/mean(timeDiffs)*100));
            disp(sprintf('inj&peak time   -> min: %1.4f max: %1.4f mean: %1.4f var: %1.8f %%: %2.2f', ...
                min(result.injectionBeforeTime), max(result.injectionBeforeTime), ...
                mean(result.injectionBeforeTime), var(result.injectionBeforeTime), ...
                std(result.injectionBeforeTime)/mean(result.injectionBeforeTime)*100));
        end
        if ((length(injectionFinish)) > 1)
        disp(sprintf('dying peak      -> min: %1.2f   max: %1.2f   mean: %1.2f   var: %1.4f     %%: %2.2f', ...
            min(injectionFinish), max(injectionFinish), mean(injectionFinish), var(injectionFinish), ...
            std(injectionFinish)/mean(injectionFinish)*100));
        timeDiffs = diff(result.injectionFinishTime);
        disp(sprintf('dying time      -> min: %1.4f max: %1.4f mean: %1.4f var: %1.8f %%: %2.2f', ...
            min(timeDiffs), max(timeDiffs), mean(timeDiffs), var(timeDiffs), std(timeDiffs)/mean(timeDiffs)*100));
        end
        if ((length(injectionDurationTime)) > 1)
        disp(sprintf('injection durat -> min: %1.4f max: %1.4f mean: %1.4f var: %1.8f %%: %2.2f', ...
            min(result.injectionDurationTime), max(result.injectionDurationTime), ...
            mean(result.injectionDurationTime), var(result.injectionDurationTime), ...
            std(result.injectionDurationTime)/mean(result.injectionDurationTime)*100));
        end
        
        figure
        hold on
        plot(((1:len).*dt), pressure, '-k');
        stem(result.injectionStartTime, result.injectionStart, 'r');
        stem(result.injectionFinishTime,result.injectionFinish, 'b');
        stem(result.pressurePeakTime,result.pressurePeak, 'g');
        hold off
        
    end
end