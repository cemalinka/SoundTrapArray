%% "run_wav_timesync.m"
% 
% RUN_WAV_TIMESYNC 
%     - Combines wav file from each slave that is synced to the 1 
%       transmitter/Master, and syncs sample times.
%     - Assumes that SUDAR clocks are all roughly synced when soundtraps 
%       are started.
%     - Note that all times in the SoundTrap CSVs are in UTC.
%
% RUN_WAV_TIMESYNC uses the following custom functions:
%     'confirm_master_presence.m'
%     'sync2wav_lookup.m'
%     'load_sync_csv.m'  <-- needs Matlab 2017 (called within 'sync2wav_lookup')
%     'first_sync_pulse.m'
%
%     CEM. Last modified March 2019;
%     chloe.e.malinka@bios.au.dk
%
%% USER INPUTS
clear
cd('C:\Users\au574966\Google Drive\MatCode\SoundTrap\sync_lib_Chloe_publish\DSRI_Octave\')
deploymentnum     = 1; % Run through each deployment
folder_raw        = 'C:\ArrayData\octave\raw_data\soundtrap\';  % Where raw recordings exist; 
folder_processed  = 'C:\ArrayData\octave\processed_data\';      % Define where data is saved. Place this at the same level as the ‘raw_data’ folder.
SaveFlag          = 1; % 1 if Save, 0 if no save


%% LOAD arraydates DATA
load([folder_processed 'array_deploy_summary.mat']) %arraydates
deploydate   = arraydates(deploymentnum).deploydate;
masterserial = arraydates(deploymentnum).masterserial; 


%% DEFINE WHERE RAW SOUNDTRAP DATA IS STORED
disp(['Running deployment # ' num2str(deploymentnum) ' on ' num2str(deploydate) ', master: ' num2str(masterserial)])
if deploymentnum <10
    folder = [folder_raw '\deployment0' num2str(deploymentnum) '\']; %This folder should contain subfolders named by SoundTrap ID.
else
    folder = [folder_raw '\deployment' num2str(deploymentnum) '\'];  %This folder should contain subfolders named by SoundTrap ID.
end
% Each SoundTrap has its own folder, named by its serial # (the same way in
%   which it is downloaded using the SoundTrap host).

outfolder = [folder_processed 'time_synced_files\']; 
if exist(outfolder)==0
    mkdir(outfolder) %where your time-algin-info MAT & multi-chan WAV files go
end


%% Determine which is the master folder and confirm it is there
[devices, masterfolder, fs] = confirm_master_presence(folder, masterserial);


%% Import GPS.CSV data from Transmitting SoundTrap (Master), which contains time sync info
disp(['--- Importing CSV data from Master (ST serial#:' num2str(masterserial) ')'])
mastersync   = sync2wav_lookup([folder masterfolder.name]);
if mastersync.syncdata(1).samp ~=0 
    disp('User-entered Master Serial # does not match data: check Master designation')
end


%% Import GPS.CSV data from the Receiving Soundtraps (Slaves)
n     = 1;
count = 0;
for i=1:length(devices)
    if (devices(i).isdir && ~contains(num2str(masterserial),devices(i).name) )
        count = count+1;
        disp(['--- Importing CSV data from Slave ' num2str(count) ' of ',...
            num2str(length(devices)-1) ' (ST serial#: ' devices(i).name ')'])
        sync = sync2wav_lookup([folder devices(i).name '\']);
        if (~isempty(sync))
            slavesyncs(n).sync = sync;
            n = n+1;
        end
    end
end
clear n i count


%% Find the first instance in the Transmitting SoundTrap (Master) in which 
%   all Receiving Soundtraps (Slaves) received a sync pulse. Use this as 
%   the official 'start time'.
[startindexes, masterstart_abc] = first_sync_pulse(mastersync, slavesyncs); 

% NB. If all slaves are plugged into the array and turned on before the
% master is plugged in, then all of the startindexes should be the
% same, even if the SoundTrap Slaves were turned on at different times.
% (This is due to the fact that slaves don't record sync-pulses from the 
% Master when the Master is not there to tell them what to do.) 
% Now we have the time at which everything is aligned.


%% Save time alignment info
if SaveFlag==1
    if deploymentnum<10
        mkdir([outfolder 'deployment0' num2str(deploymentnum) '\']);
        outputfolder = [outfolder 'deployment0' num2str(deploymentnum) '\'];
    else 
        mkdir([outfolder 'deployment' num2str(deploymentnum) '\']);
        outputfolder = [outfolder 'deployment' num2str(deploymentnum) '\'];
    end
    mkdir([outputfolder 'matfiles\']);
    odn = [outputfolder 'matfiles\'];    
    outputfilename_matfile = ['timesyncinfo_deployment_' num2str(deploymentnum) '.mat'];    
    save([odn outputfilename_matfile],...
        'mastersync','slavesyncs','startindexes','fs','outputfolder',...
        'folder','masterserial','deploymentnum','masterstart_abc'); 
end 
clear odn


%% next code: "plot_to_check_samples.m" to give visual confirmation / 
%   sanity check that time alignment is working as expected
%% or, next code: "write_wavs.m" to write the multi-channel, time-aligned 
%   wav files
%%