function [devices, masterfolder, fs] = confirm_master_presence(folder, masterserial)
%
%% CONFIRM_MASTER_PRESENCE
%   Confirms the presence of a Master (Transmitting SoundTrap) folder,
%   containing SoundTrap data.
%
% [DEVICES, MASTERFOLDER, FS] = CONFIRM_MASTER_PRESENCE(FOLDER, MASTERSERIAL) 
%   DEVICES is a structure of folders indicating devices on the array, 
%       including the Master. 
%   MASTERFOLDER is the folder containing data from the Master SoundTrap.
%   FS is the sample rate (in Hz) of audio data on the Master.
%
%   Used within script 'run_wav_timesync.m'
%   (No SoundTrap sync library functions are nested within this function).
%
%   CEM. Last modified July 2018.
%   chloe.e.malinka@bios.au.dk
%
%%
files_tmp = dir(folder);
idxs = [];
for qq=1:length(files_tmp)
    if strcmp(files_tmp(qq).name(1), '.') ==0
        idxs = [idxs; qq];
    end
end 
devices = files_tmp(idxs);
clear idxs files_tmp qq 

masterfolder = [];
for i = 1:length(devices)
    if (devices(i).isdir && strcmp(num2str(masterserial), devices(i).name))
        masterfolder = devices(i);
        break
    end
end
clear i 

if (isempty(masterfolder))
    disp('ERROR: Could not find the master folder. The folder name must contain just the serial number ID of the SoundTrap');
    return
end

%% Extract audio sampling rate
wavfiles = dir([folder num2str(masterserial) '\' '*.wav']);
jnk     = audioinfo([wavfiles(1).folder '\' wavfiles(1).name]);
fs      = jnk.SampleRate; %must be same for all devices or time alignment won't work.
clear jnk wavfiles
disp(['Audio sampling rate is ' num2str(fs) ' Hz'])

end 