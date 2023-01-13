function write_amica_param(fileName,varargin)

%% parse out inputs

if length(varargin) == 1 % Now you can input an string array containing options.
    arg = string(varargin{:});
else
    arg = string(varargin);
end
 

if mod(length(arg),2)~=0
    error("you need to provide paired arguments, the first argument should be" ...
        + "an AMICA param and the second argument should be its value");
end

load("sample_AMICA_defs.mat","sample_AMICA_defs")

amParam = sample_AMICA_defs;

for i = 1:length(arg)/2
    n = 2 * i - 1; %feature index
    m = 2 * i; % value index
   try
       amParam{amParam{:,"feature"}==arg(n),2} = arg(m);
   catch
       warning("could not find " + arg(n) + ", this pair is skipped.")
   end
end

writetable(amParam,fileName,"FileType","text","WriteRowNames",false,"WriteVariableNames",false,...
    "Delimiter"," ")