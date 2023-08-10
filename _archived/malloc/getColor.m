function [color] = getColor(idx)
    % Carey Rappaport (2023). CMRmap.m (https://www.mathworks.com/matlabcentral/fileexchange/2662-cmrmap-m), MATLAB Central File Exchange. Retrieved July 19, 2023. 
    CMRmap=[0 0 0;.15 .15 .5;.3 .15 .75;.6 .2 .50;1 .25 .15;.9 .5 0;.9 .75 .1;.9 .9 .5;1 1 1];
    color = CMRmap( idx, : );
    % param_colors = {'r', 'b', 'g', 'm'};
end