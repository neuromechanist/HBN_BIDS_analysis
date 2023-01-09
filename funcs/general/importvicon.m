function vicondata = importvicon(csvfilename)

% function for loading vicon data as csv
% delimiter = ,
% headerlines = 5
% assumes two force plates

temp = importdata(csvfilename,',',5);

vicondata.srate = str2double(temp.textdata{2,1});

varcommas = strfind(temp.textdata{4,1}, ',');
varnames{1} = temp.textdata{4,1}(1:varcommas(1)-1);
for c = 1:length(varcommas)-1
    varnames{c+1} = temp.textdata{4,1}(varcommas(c)+1:varcommas(c+1)-1);
end
varnames{length(varcommas)+1} = temp.textdata{4,1}(varcommas(c+1)+1:end);

comp = {'Fx' 'Fy' 'Fz' 'Mx' 'My' 'Mz'};
for f = 1:length(comp)
    eval(['vn = find(strcmp(''' comp{f} ''',varnames));']);
    varnames{vn(1)} = [varnames{vn(1)} '_L'];
    varnames{vn(2)} = [varnames{vn(2)} '_R'];
end

for v = 1:length(varnames)
    varnames{v} = strrep(varnames{v}, ' ', '_');
    eval(['vicondata.' varnames{v} ' = temp.data(:,v);']);
    vicondata.units{v} = temp.textdata{5,v};
end

vicondata.time_s = [1:length(vicondata.Frame)]'/vicondata.srate;
