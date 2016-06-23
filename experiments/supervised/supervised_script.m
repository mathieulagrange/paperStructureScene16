% Before running this script, the libraries scattering.m and rastamat must
% have been added to the path
dataset_path = '~/datasets/dcase2013/scenes_stereo';
modulations = 'time-frequency';
nfo = 8;
nAzimuths = 5;

dcase_scattering(dataset_path, 'time', 8, nAzimuths);
dcase_scattering([dataset_path,'_testset'], 'time', 8, nAzimuths);

dcase_scattering(dataset_path, 'time-frequency', 8, nAzimuths);
dcase_scattering([dataset_path,'_testset'], 'time-frequency', 8, nAzimuths);

%%
dcase_scattering(dataset_path, 'time', 4, nAzimuths);
dcase_scattering([dataset_path,'_testset'], 'time', 4, nAzimuths);

