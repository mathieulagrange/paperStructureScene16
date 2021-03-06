function [config, store, obs] = tasuea1features(config, setting, data)                                     
% tasuea1features FEATURES step of the expLanes experiment talspStruct2016_supervised_earlyLate            
%    [config, store, obs] = tasuea1features(config, setting, data)                                         
%      - config : expLanes configuration state                                                             
%      - setting   : set of factors to be evaluated                                                        
%      - data   : processing data stored during the previous step                                          
%      -- store  : processing data to be saved for the other steps                                         
%      -- obs    : observations to be saved for analysis                                                   
                                                                                                           
% Copyright: gregoirelafay                                                                                 
% Date: 16-Dec-2016                                                                                        
                                                                                                           
% Set behavior for debug mode                                                                              
if nargin==0, talspStruct2016_supervised_earlyLate('do', 3, 'mask', {0 [1 2] 0 0 0 0}); return; else store=[]; obs=[]; end
                                                                                                           
%% setting
store.xp_settings.sr=44100;
store.xp_settings.classes = {'bus','busystreet','office','openairmarket','park','quietstreet','restaurant','supermarket','tube','tubestation'};

switch setting.features
    case 'scatT'
        
        fileId = fopen([config.inputPath 'sampleList_' setting.dataset '.txt']);
        store.xp_settings.sounds=textscan(fileId,'%s');store.xp_settings.sounds=store.xp_settings.sounds{1};
        fclose(fileId);
        
        store.xp_settings.sounds=cellfun(@(x) x(strfind(x,'/')+1:end),store.xp_settings.sounds,'UniformOutput',false);
        
        store.soundIndex=[];
        store.indSample=[];
        store.class=[];
        store.dataset=[];
        eval(['store.features.' setting.features '=[];']);
        
                load([config.inputPath  'scattering/dcase2013_timeQ8_' setting.dataset '.mat']);
                load([config.inputPath  'scattering/dcase2013_timeQ8_freqs.mat']);
                eval(['Y=dcase2013_timeQ8_' setting.dataset '.Y_' setting.dataset ';']);
                eval(['X=dcase2013_timeQ8_' setting.dataset '.X_' setting.dataset ';']);
                eval(['clearvars dcase2013_timeQ8_' setting.dataset ';']);
                
                store.xp_settings.Xfreqs=dcase2013_timeQ8_freqs;
                X=squeeze(X(:,:,3,:));
                
        store.class=Y(:)'+1;
        store.soundIndex=1:length(Y);
        
        nbTrame=size(X,2);
        
        for ii=1:size(X,3)
            eval(['store.features.' setting.features '=[store.features.' setting.features ' squeeze(X(:,:,ii))];']);
            store.indSample=[store.indSample ones(1,nbTrame)*ii];
        end
        
    case 'mfcc'
        
        %% setting framing
        
        store.xp_settings.hoptime = 0.025;
        store.xp_settings.wintime = 0.05;
        
        %% setting features
        
        store.xp_settings.melBand=40;
        store.xp_settings.minFreq=27.5;
        store.xp_settings.maxFreq=22050;
        
        store.xp_settings.mfccRank=40;
        store.xp_settings.mfccCoef0=1;

        
        %% select sound
        
        fileId = fopen([config.inputPath  'sampleList_' setting.dataset '.txt']);
        store.xp_settings.sounds=textscan(fileId,'%s');store.xp_settings.sounds=store.xp_settings.sounds{1};
        fclose(fileId);
        
        %% load sound
        
        store.xp_settings.soundIndex = 1:100;
        
        % init
        eval(['store.features.' setting.features ' = [];']);
        
        store.soundIndex=zeros(1,length(store.xp_settings.soundIndex));
        store.class=zeros(1,length(store.xp_settings.soundIndex));
        store.dataset=zeros(1,length(store.xp_settings.soundIndex));
        store.indSample=[];
        
        for jj=1:length(store.xp_settings.soundIndex)
            
            [signal,fs]=audioread([config.inputPath store.xp_settings.sounds{store.xp_settings.soundIndex(jj)}  '.wav']);
            
            if fs~=store.xp_settings.sr
                error('issue with sample rate')
            end
            
            % mono
            if min(size(signal)) > 1
                signal=mean(signal,2);
            end
            
            store.xp_settings.soundDuration = length(signal)/store.xp_settings.sr;
   
            % get features
            [ftrs.mfcc,~,~] = melfcc(signal(:),store.xp_settings.sr,'wintime',store.xp_settings.wintime,'hoptime',store.xp_settings.hoptime,'minfreq',store.xp_settings.minFreq,'maxfreq',store.xp_settings.maxFreq,'lifterexp',0,'preemph',0,...
                'nbands',store.xp_settings.melBand,'numcep',store.xp_settings.mfccRank);
            ftrs.size=size(ftrs.mfcc,2);
            
            % store features
            eval(['store.features.' setting.features ' = [store.features.' setting.features ' ftrs.' setting.features '];']);
            
            store.soundIndex(jj)=store.xp_settings.soundIndex(jj);
            store.indSample=[store.indSample ones(1,ftrs.size)*store.soundIndex(jj)];
            
            soundname=store.xp_settings.sounds{store.xp_settings.soundIndex(jj)}(1:end-2);
            
            soundname=soundname(strfind(soundname,'/')+1:end);
            store.class(jj)=find(strcmp(soundname,store.xp_settings.classes));
            
        end
end