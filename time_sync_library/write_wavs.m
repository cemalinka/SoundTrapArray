%% "write_wavs.m"
% 
% WRITE_WAVS runs the soundtrap wav file stitch. 
%     - It combines wav file from each slave that is synced to the 1 
%       transmitter/Master, and syncs sample times.
%     - Assumes that SUDAR clocks are all roughly synced when soundtraps 
%       are started.
%     - Note that all times in the SoundTrap CSVs are in UTC.
%
% WRITE_WAVS uses the following custom function:
%     'stitch_wav.m'
%
%     CEM. Last modified March 2019;
%     chloe.e.malinka@bios.au.dk
%
%% "write_wavs_STsalreadysynced.m"
%  This code picks up from run_wav_timesync, only if the user chose to
%  delay the writing of the wav files.

%% USER INPUT
clear
cd('C:\Users\au574966\Google Drive\MatCode\SoundTrap\sync_lib_Chloe_publish\DSRI\')
deploymentnum     = 1;
SaveFlag          = 1; % 1 if Save, 0 if no save
folder_processed  = 'C:\ArrayData\processed_data\'; % Define where data is saved
to_exclude        = [0, 0];  
    % If plot_to_check_samples.m" gave fine results, 
    %   to_exclude = [0,0];
    % If plot_to_check_samples.m" gave erratic results, 
    %   to_exclude = [deployment num, slaverow; deployment num, slaverow];
    %   whereby the 'slaverow' is the row # in the slavesyncs structure
    
    
%% LOAD ARRAY SUMMARY DATA (output of "get_array_structure.m")
load([folder_processed 'array_deploy_summary.mat']) %arraydates


%% LOAD MATFILES OF TIME ALIGNMENTS (output of "run_wav_timesync.m")
if deploymentnum <10
    dn = [folder_processed '\time_synced_files\deployment0' num2str(deploymentnum) '\matfiles\'];
else
    dn = [folder_processed '\time_synced_files\deployment' num2str(deploymentnum) '\matfiles\'];
end
fn = ['timesyncinfo_deployment_' num2str(deploymentnum) '.mat'];
load([dn fn]); % 'mastersync','slavesyncs','startindexes','fs','outputfolder','folder','masterserial','deploymentnum','masterstart_abc' 


%% Remove any Receiving Soundtrap (slave) channels where sample count was erratic
odd_deps = to_exclude(:,1);
if  any(ismember(odd_deps, deploymentnum))==1    
    idx = find(deploymentnum == odd_deps);    
    chan_to_exclude = to_exclude(idx,2); 
    ID_to_exclude   = slavesyncs(chan_to_exclude).sync.syncdata(1).csvfilename(1:10);
    disp([' Excluding slave row ' num2str(chan_to_exclude) ', ID: ',...
        ID_to_exclude ', from Deployment # ' num2str(deploymentnum)])
    all_slave_chans = 1:length(slavesyncs);
    to_include = all_slave_chans(find(all_slave_chans~=chan_to_exclude));    
    clear idx chan_to_exclude all_slave_chans    
    slavesyncs2 = struct();
    counter = 0;
    for qq= to_include
        counter = counter +1;
        slavesyncs2(counter).sync = slavesyncs(qq).sync;
    end
    startindexes = [startindexes(1), startindexes(to_include+1)];
    clear slavesyncs
    slavesyncs = slavesyncs2;
    clear slavesyncs2 counter qq odd_deps to_include ID_to_exclude
end
clear to_exclude odd_deps


%% Assign # to each letter for easier comparison
numbers=[1:26]; %ABCs
letters = char(numbers + 64);
for qq=1:length([mastersync.syncdata]) %Transmitting SoundTrap (Master)
    abc = mastersync.syncdata(qq).abc;
    num = strfind(letters,abc);
    mastersync.syncdata(qq).abc_number = num;
    if qq==1
        mastersync.syncdata(qq).self_jitter = fs;
    else
        mastersync.syncdata(qq).self_jitter = mastersync.syncdata(qq).samptotal - mastersync.syncdata(qq-1).samptotal;
    end    
end %qq

for qq=1:length(slavesyncs) % Loop over Receiving Soundtraps (Slaves)
    for rr = 1:length(slavesyncs(qq).sync.syncdata) %loop over rows
        abc = slavesyncs(qq).sync.syncdata(rr).abc;
        num = strfind(letters,abc);
        slavesyncs(qq).sync.syncdata(rr).abc_number = num;
    end
end
clear qq rr numbers letters abc num 


%% Get mininmum length of Receiving SoundTrap (slave) 
minslavelens = [];
for qq=1:length(slavesyncs)
    minslavelens = [minslavelens; length([slavesyncs(qq).sync.syncdata])];
end
minslavelen = min(minslavelens); 
clear qq minslavelens
minlength = min(length([mastersync.syncdata]), minslavelen); 


%% Keep track of instances of a skipped letter (which occurs for 1 letter when a new file starts recording) 
for qq=1:length([slavesyncs.sync])
    for rr = 1:minlength
        if strcmp(slavesyncs(qq).sync.syncdata(rr).abc, mastersync.syncdata(rr).abc) ==1
            slavesyncs(qq).sync.syncdata(rr).flag = 0; 
            mastersync.syncdata(rr).flag          = 0;
        else
            jnk = (slavesyncs(qq).sync.syncdata(rr).abc_number) - (mastersync.syncdata(rr).abc_number); 
            if  jnk==1 || jnk==-25 % Slave has skipped a letter (CASE 1)
                slavesyncs(qq).sync.syncdata(rr).flag = 1; %slave skipped
                mastersync.syncdata(rr).flag          = 1; %slave skipped
                % Then load master(start:end) && slave(stop-of-previous+fs-1 : stop-of-previous+fs-1+fs-1)   
                
            elseif jnk==-1 % Master has skipped a letter (CASE 2)
                slavesyncs(qq).sync.syncdata(rr).flag = 2; %master skipped 
                mastersync.syncdata(rr).flag          = 2; %master skipped
                % Then load master(start:end) && slave(start-of-next : start-of-next+fs-1)
            end
        end
    end %rr
end %qq
clear qq rr jnk 


%% Save the modified sync files & write the multi-chan time-synced WAVs
if SaveFlag ==1
    fn2 = ['timesyncinfo_deployment_' num2str(deploymentnum) '_v2.mat'];
    save([dn fn2],'mastersync','slavesyncs','outputfolder','masterstart_abc',...
        'masterserial','fs','folder','deploymentnum','startindexes','minlength'); 

    % Make a series of x-channel file with user-defined chunk lengths
    stitchstruct = stitch_wav(mastersync, slavesyncs, startindexes, fs,...
        outputfolder, folder, masterserial, deploymentnum); 
    fn3 = ['timesyncinfo_deployment_' num2str(deploymentnum) '_stitchstruct.mat'];
    save([dn fn3],'stitchstruct','mastersync','slavesyncs')    
end %SaveFlag


%% Now, multi-channel time-synchronised WAV files are created. 