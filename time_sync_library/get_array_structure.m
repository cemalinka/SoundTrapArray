%% "get_array_structure.m"
% 
% GET_ARRAY_STRUCTURE outputs a structure summarising deployments
%     - This code is for easy reading in of deployments into "run_wav_timesync.m"  

%     CEM. Last modified March 2019;
%     chloe.e.malinka@bios.au.dk

%% USER INPUTS
clear
cd('C:\Users\au574966\Google Drive\MatCode\SoundTrap\sync_lib_Chloe_publish\')
folder_processed = 'D:\bench_test\processed_data\'; % Define where data is saved
SaveFlag = 1;               % 1 if Save, 0 if no save

% Summary of array deployments. An example is shown below.
% Columns are:
% 1) Array deployment number;
% 2) SoundTrap ID of the Transmitting/Master SoundTrap;
% 3) Date of deployment;
dat = [1	1342451724	20190718]; %<- only row that matters

    
%% Make into structure
arraydates = struct();
for qq=1:length(dat(:,1))
    arraydates(qq).deploynum    = dat(qq,1);
    arraydates(qq).masterserial = dat(qq,2);
    arraydates(qq).deploydate   = dat(qq,3);
end %qq


%% Save
if SaveFlag ==1
    file = 'array_deploy_summary.mat';
    save([folder_processed file], 'arraydates')
end
%% 