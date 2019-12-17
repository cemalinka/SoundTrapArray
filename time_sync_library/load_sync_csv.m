function [csvout] = load_sync_csv(folder)
%
%% LOAD_SYNC_CSV 
%   Loads all sync data ('*.gps.csv' files) from a folder of sountrap data.
%   [CSVOUT] = LOAD_SYNC_CSV(FOLDER) loads all sync data from a SoundTrap FOLDER. 
%
%   CSVOUT is a structure with the following fields:
%   SYNCDATA has info on all sync pulses of the soundtrap and the 
%     correponding total sample count and wav file sample count. 
%   WAVDATA contains data on wav files and corresponding sync data sample counts. 
%
%   Used within function 'sync2wav_lookup.m'
%
%     CEM. Last modified July 2018.
%     chloe.e.malinka@bios.au.dk
%
%%
csvfiles = dir([folder '\' '*.gps.csv']);
counter=1; 
for jj = 1:length(csvfiles)
    filename = [folder '\' csvfiles(jj).name];
    disp(['    Extracting info from CSV # ' num2str(jj) '/' num2str(length(csvfiles))])
    fileID = fopen(filename);
    C = textscan(fileID,'%s');
    fclose(fileID);
    
    % Extract last column: Sync the time-of-arrival relative to audio sample #
    for rr=2:length(C{1,1}) % skip header, start at 2
        if rr==2
            %counter = counter; % so that empty header row isn't included as a blank row
        else
            counter = counter + 1;
        end
        data(counter).csvfilename = csvfiles(jj).name;
        data(counter).csvfilenum = jj;
        str = C{1,1}{rr}; % COLUMN names: rtime , mticks , ALPHA?, samplenum
        
        pos = strsplit(str,',');        
        % (first 2 columns are the time that the sync pulse arrived)
        data(counter).rtime  = str2num(pos{1}); % rtime is always a whole number;
        data(counter).mticks = str2num(pos{2}); % mticks is in microseconds     
        
        % Letters A-Z help match sync pulses between units 
        abc = pos{3};
        abc = erase(abc,'?');  %needs matlab2017 for erase function
        data(counter).abc = abc;
        
        % Use samples column to determine relative timing of audio data
        % Sample # column refers to sample count on the local device
        % ...(not the master) at time pulse from the master was received.
        data(counter).samp    = str2double(pos{4}); %MOST IMPORTANT LINE
        datestr0              = datetime(data(counter).rtime,'ConvertFrom','posixtime');
        jnk                   = data(counter).rtime + (data(counter).mticks*1e-6); %add converted microsecs-to-seconds
        datestr1              = datetime(jnk,'ConvertFrom','posixtime');                   
       
       
        data(counter).datenum = datenum(datestr0);
        data(counter).datestr = datestr(data(counter).datenum, 'dd-mmm-yyyy HH:MM:SS'); %datestr can only display to millsecond accuracy
        data(counter).datenum1 = datenum(datestr1);
        data(counter).datestr1 = datestr(data(counter).datenum1, 'dd-mmm-yyyy HH:MM:SS.FFF'); %datestr can only display to millsecond accuracy 
        
        data(counter).sec_counter = rr-1; %between pulses, ~1/sec        
    end %rr
end %jj

if (isempty(csvfiles))
    data=[]; 
   return;
end
csvout = data;

end % of function; back to 'sync2wav_lookup.m'