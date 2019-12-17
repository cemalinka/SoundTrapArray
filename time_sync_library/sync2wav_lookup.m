function [lookup] = sync2wav_lookup(folder)
%
%% SYNC2WAV_LOOKUP 
%   Creates a lookup table with the total # of audio samples for each WAV
%       file, and the running total # of samples for the soundtrap sync data.
%
% [LOOKUP] = SYNC2WAV_LOOKUP(FOLDER) 
%   Loads data from the RS484 data package log files ('*gps.csv') and wav 
%       files in a soundtrap raw data FOLDER and returns a structure, which has  
%       the device's total sample count and the sample count into the current 
%       wav file. SoundTraps can reset their sample count within a file, 
%       and this code sorts this out. Specifically, it adds columns 
%       .samptotal and .wavsample to the "syncdata" structure output from 'load_sync_csv'
%
%   LOOKUP has two structures, SYNCDATA and WAVDATA. 
%       SYNCDATA has info on all sync pulses of the soundtrap and the 
%           correponding total sample count and wav file sample count. 
%       WAVDATA contains data on wav files and corresponding sync data sample 
%           counts. 
%
% Used within script 'run_wav_timesync.m'
% SYNC2WAV_LOOKUP uses the following custom functions:
%     'load_sync_csv.m'  <-- needs Matlab 2017 (called within 'sync2wav_lookup')
%
%     CEM. Last modified July 2018.
%     chloe.e.malinka@bios.au.dk
%
%%
ULONGMAX= 4294967296; %=2^32 = maximum value of unsigned long on a SoundTrap DSP.
% Once this sample number %is reached the SoundTrap reverts back to zero.

%% Load wav files and calculate the total sample count for a given deployment.
wavfiles = dir([folder '\' '*.wav']);
wavcount = 0; %original
for i=1:length(wavfiles)
    disp(['  Checking wav file: ' num2str(i) ' of ' ...
        num2str(length(wavfiles)) ': '  wavfiles(i).name]);
    [y] = audioinfo([folder '\' wavfiles(i).name]);
    wavsamples(i).name          = wavfiles(i).name;
    wavsamples(i).filecount     = i;
    wavsamples(i).sampletotal   = wavcount;       % cumulative, AT START of file    
    wavsamples(i).samplecount   = y.TotalSamples; % # of samples in that file total
    wavcount                    = wavcount + y.TotalSamples;     
end

%% Load sync data and calculate the total sample count
[syncdata]  = load_sync_csv(folder);
samples     = [syncdata.samp];
nlongadd    = 0;
syncdata(1).samptotal = samples(1); % cumulative # samples, AT START of file
for i=2:length(samples)
    if (i>=2 && samples(i) < samples(i-1)) %if the sample count is less than the last sample count, 
        nlongadd = nlongadd + 1;   
    end
    synccount(i)          = samples(i) + (ULONGMAX*nlongadd);% add to cumulative sample count when upper limit is reached
    syncdata(i).samptotal = synccount(i);
end

%% Get indices for starts of new files
idx2=[];
for rr=2:length(syncdata)
    if [syncdata(rr).csvfilenum] > [syncdata(rr-1).csvfilenum]
        idx2 = [idx2; rr]; 
    end
end %rr

%% Find length of gap between files
wavsamples(1).startsample = 0;
for pp = 1:length(idx2)  
    wavsamples(pp+1).startsample = syncdata(idx2(pp)).samptotal - syncdata(idx2(pp)-1).samptotal; 
end

%% Find what the first sample in the wav file should be
for pp=1:length(wavsamples) 
    wavsamples(pp).sampletotalB = wavsamples(pp).sampletotal + wavsamples(pp).startsample; 
end 

%% Add wav file samples to structure. 
for i=1:length(syncdata)
    if (mod(i,20)==0)
        %disp(['  Indexing sync sample to wav sample: ' num2str(100*i/length(syncdata)) '% through']); 
    end    
    [~, index] = min(abs([wavsamples.sampletotal]-synccount(i)));
    
    % Get the wav file closest in time which started before that sample
    if (wavsamples(index).sampletotal > synccount(i))
        index = index-1; 
    end
    syncdata(i).wavsample = synccount(i)-wavsamples(index).sampletotal;
end

%% Create lookup structure
lookup.syncdata = syncdata;
lookup.wavdata  = wavsamples;

end