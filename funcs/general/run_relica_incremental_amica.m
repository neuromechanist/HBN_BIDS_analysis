function ICA_STRUCT = run_relica_incremental_amica(EEG,icaPath)
% runs RELCIA on incremental amica to get the most stable components.
%
%
% REV:
%       v0 @ 5/20/2019 adapted from REILCA_main
%       update: 5/25/2019: post process section may not work. Using
%       differernt number of compoenents (or actually channels) make RELICA
%       unstalbe. It seems basically that RELCIA it too sensitive to
%       changes in the weights, so remivng un-common chans or adding zeros
%       for the un-common chans make it not work as it is supposed to.
%
% Created by: Seyed Yahya Shirazi, BRaIN Lab, UCF
% email: shirazi@ieee.org
%
% Copyright 2019 Seyed Yahya Shirazi, UCF, Orlando, FL 32826

%% initialize
fs = string(filesep);
data = EEG.data;
if ~exist("icaPath","var") || isempty(icaPath)
    error("ICA path is mandatory");
end

sR=icassoStruct(data); 
sR.mode='both';
sR.whiteningMatrix = eye(128);
sR.dewhiteningMatrix = eye(128);

%% which channles are to be loaded?
incr0Dir = dir(icaPath + "incr0" + fs);
incr0Content = string({incr0Dir(:).name});
load(icaPath + "incr0" + fs + incr0Content(contains(incr0Content,"channels_frames.mat")),"ICA_INCR");

% let's find channles that are present in every ICA
bad_chan = [];
for i = 1:128
    for j = 1:length(ICA_INCR)
       if ~ismember(i,ICA_INCR(j).good_chans)
           bad_chan(end+1) = i;
           break
       end
    end    
end

univ_good_chans = 1:128; univ_good_chans(bad_chan) = [];
sR.whiteningMatrix = eye(length(univ_good_chans));
sR.dewhiteningMatrix = eye(length(univ_good_chans));

%% load ica weigths from different steps
foldContent = dir(icaPath);
foldName = string({foldContent(:).name});
if isempty(find(contains(foldName,"incr"),1))
    error("ICA path does not contain incremental folders.")
end

sR.index = [];
for i = foldName
    if foldContent(i == foldName).isdir == 1
        if contains(i, "incr")
            incrNum = split(i, "incr"); incrNum = str2double(incrNum(2));
            if incrNum > 0
                modout = loadmodout10(char(icaPath + i + fs + "amicaout"));
                disp("imported ICA parpmeter for incr. " + string(incrNum));
                Ws = modout.W * modout.S; As = pinv(Ws);
                A_ = zeros(128,size(modout.A,2)); W_ = zeros(size(modout.W,1),128); % adding zero cols for the chans that are ommitted.
                for j = 1:modout.data_dim
                    chanNum = ICA_INCR(incrNum).good_chans(j);
                    W_(:,chanNum) = Ws(:,j);
                    A_(chanNum,:) = As(j,:);                    
                end
                sR.A{incrNum} = A_;
                sR.W{incrNum} =W_;
%                 sR.A{incrNum} = As(~ismember(ICA_INCR(incrNum).good_chans,bad_chan),:); % this is to remove non-common chans
%                 sR.W{incrNum} = Ws(:,~ismember(ICA_INCR(incrNum).good_chans,bad_chan));
                n = size(sR.W{incrNum},1);
                k = incrNum;
                sR.index(end+1:end+n,:)=[repmat(k,n,1), transpose(1:n)];
%                 modout = [];
            end
        end
    end
end

%% clustering using ICASSO
% setting up clustering parameters.
M=icassoGet(sR,'M');
sR.cluster.simfcn = 'abscorr';
sR.cluster.s2d = 'sim2dis';
L = 100; % number of clusters, arbitraitly set at 100, should change it later.
sR.cluster.strategy = 'AL';

sR.cluster.similarity=abs(corrw(icassoGet(sR,'W'),icassoGet(sR,'dewhitemat')));
%just to make sure
sR.cluster.similarity(sR.cluster.similarity>1)=1;
sR.cluster.similarity(sR.cluster.similarity<0)=0;
D=feval(sR.cluster.s2d, sR.cluster.similarity); % change similarity to distance
[sR.cluster.partition,sR.cluster.dendrogram.Z,sR.cluster.dendrogram.order]=...
    hcluster(D,sR.cluster.strategy); % clustering or as in RELICA, "partitioning" 

sR.cluster.index.R=ones(M,1)*NaN; % our very own r vlaue.
sR.cluster.index.R(1:L,1)=rindex(D,sR.cluster.partition(1:L,:));  

%% projection
sR=icassoProjection(sR,'cca','s2d','sqrtsim2dis','epochs',75);
% outputDimension=2;
% method='cca';
% projectionparameters={'s2d','sqrtsim2dis','alpha',0.7,'epochs',75,...
% 	   'radius',max(icassoGet(sR,'M')/10,10)};
% num_of_args=length(projectionparameters);
% for i=1:2:num_of_args
%   switch lower(projectionparameters{i})
%    case 's2d'
%     sim2dis=projectionparameters{i+1};
%    case 'epochs'
%     epochs=projectionparameters{i+1};
%    case 'alpha'
%     alpha=projectionparameters{i+1};
%    case 'radius'
%     CCAradius=projectionparameters{i+1};
%    otherwise
%     error(['Indentifier ' projectionparameters{i} ' not recognized.']);
%   end
% end
% D=feval(sim2dis,sR.cluster.similarity);
% disp([char(13) 'Projection, using ' upper(method) char(13)]);
% switch method 
%  case 'mmds'
%   P=mmds(D); 
%   P=P(:,1:outputDimension);
%  otherwise
%   % Start from MMDS
%   initialProjection=mmds(D); initialProjection=initialProjection(:,1:2);
%   % 
%   dummy=rand(size(D,1),outputDimension);
%   % rand. init projection: set 
%   % initialProjection=dummy;
%   switch method
%    case 'sammon' % Use SOM Toolbox Sammon 
%     P=sammon(dummy,initialProjection,epochs,'steps',alpha,D);
%    case 'cca'    % Use SOM Toolbox CCA 
%     P=cca(dummy,initialProjection,epochs,D,alpha,CCAradius);
%   end
% end
% sR.projection.method=method;
% sR.projection.parameters=projectionparameters;
% sR.projection.coordinates=P;

%% post process
L=icassoGet(sR,'rdim');[Iq, A_centroid, W_centroid]=icassoResult(sR,L);
ncomp = size(sR.A{1},2);
A_boot_percomp{ncomp}=[]; W_boot_percomp{ncomp} =[]; indici_boot_percomp{ncomp} = [];
A_boot = sR.A; W_boot = sR.W;
nrun = length(A_boot);
indici = sR.cluster.partition(ncomp,:);
for i = 1 : length(indici)/ncomp
    b = indici(ncomp*(i-1)+1 : ncomp*i);
    for j=1:length(b) % all the components go into cluster j 
        A_boot_percomp{b(j)}(:,end+1) = A_boot{i}(:,j);
        W_boot_percomp{b(j)}(end+1,:) = W_boot{i}(j,:);
        indici_boot_percomp{b(j)}(end+1,:) = [i j];
    end
end
indici_boot_permatrice = reshape(indici,ncomp,length(sR.A));

real.A = sR.A{1};
real.W = sR.W{1};
real.S = sR.whiteningMatrix;
real.clustok_ord = 0;
indice = indici_boot_permatrice(:,1);
for i = 1:ncomp
    ind = find(indice == i);
    if ~isempty(ind)
        real.A_ord{i} = real.A(:,ind);
        real.Ind_ord{i} = ind;
        real.W_ord{i} = real.W(ind,:);
    else
        real.A_ord{i} = [];
        real.Ind_ord{i} = [];
        real.W_ord{i} = [];
    end        
end
RELICA.Iq = Iq;
RELICA.sR = sR;
RELICA.A_boot_percomp = A_boot_percomp;
RELICA.W_boot_percomp = W_boot_percomp;
RELICA.indici_boot_percomp = indici_boot_percomp;
RELICA.indici_boot_permatrice = indici_boot_permatrice;
RELICA.A_centroid = A_centroid;
RELICA.W_centroid = W_centroid;
RELICA.A_real = real.A;
RELICA.W_real = real.W;
RELICA.ind_real = indici_boot_permatrice(:,1); %which cluster they belong to
