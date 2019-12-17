function [stitchstruct] = stitch_wav(mastersync, slavesyncs, startindexes, fs,...
           outputfolder, folder, masterserial, deploymentnum)
%
%% STITCH_WAV makes multi-chan time-aligned files, with master & all slaves
%
%   [STITCHSTRUCT] = STITCH_WAV(MASTERSYNC, SLAVESYNCS,...
%    STARTINDEXES, FS, OUTPUTFOLDER, FOLDER, MASTERSERIAL, DEPLOYMENTNUM)
%
%         STITCHSTRUCT : Structure that records the start and stop sample 
%               numbers, and the start and stop wavsamples of each device, 
%               as aligned to one another, for each second of the deployment
%               recording. Useful for troubleshooting. 
%
%         MASTERSYNC : structure containing GPS time, wavsample, and 
%               cumulative sample info for the master.% 
%         SLAVESYNCS : structure containing GPS time, wavsample, and 
%               cumulative sample info for all the slaves.
%         STARTINDEXES : first instance in MASTER in which all SLAVES have
%               received a sync pulse. Use this as the official 'start time'.
%         FS : audio sample rate in  Hz (must be the same across all chans).
%         OUTPUTFOLDER : where wav files are written to
%         FOLDER : folder for given deployment. Must contain subfolders of
%               all SoundTraps (master and all slaves), each named by their 
%               ST serial ID.
%         MASTERSERIAL : the ST serial ID of the MASTER soundtrap.
%         DEPLOYMENTNUM : the deployment number. 
%
%         Channel 1 is always the Master.  
%         Channel order of Slaves matches that as in SLAVESYNCS.
%         DC offset is removed for all channels. No filtering.
%
%     CEM. Last modified March 2019;
%     chloe.e.malinka@bios.au.dk
%
%
%% Define start index; 
first_master_startidx   = startindexes(1); %This is first instance of common pulse across all devices
first_slave_startidxs   = startindexes(2:end);
min_slavelength = [];
for pp=1:length(slavesyncs)
    min_slavelength = [min_slavelength; length(slavesyncs(pp).sync.syncdata)];
end
numofsecs = min([length(mastersync.syncdata), min_slavelength']); % or insert the # of seconds you want
numofsecs = numofsecs - 7; % just relevant for writing last file
clear pp min_slavelength


%% Load in and write multi-channel WAV files
counter         = 0;   % counts up to 60 and then resets
filecounter     = 0;   % 0; number of files already written, if not starting at beginning
if filecounter == 0
    start= 1;
else
    start = filecounter*60;
end
wavout = [];
stitchstruct = struct();
for rr =start:numofsecs;  % Loop through each second, reading in 1 sec of data at a time;
    counter = counter + 1; % counts up to 60 and then resets
    disp(['Seconds aligned through data: ' num2str(counter) ' s ----------'])
    
    %% Get MASTER start & stop samples for this second
    if rr==1
        master_firstsample = mastersync.syncdata(first_master_startidx).wavsample; %first sample of master chunk
        master_startidx    = first_master_startidx;
    else
        master_startidx    = first_master_startidx + rr - 1; %ALWAYS THE CASE FOR MASTER
        if master_startidx > length([mastersync.syncdata])
            % then write file now and exit this loop; need to move this down below
            disp('warning: Master_startidx > length([mastersync.syncdata]')
        end
        master_firstsample = mastersync.syncdata(master_startidx).wavsample; %first sample of master chunk
    end
    master_chunkend = master_firstsample + fs-1;  %last sample of master chunk, duration of one second       
    wavidx    = mastersync.syncdata(master_startidx).csvfilenum; 
    wav2load  = mastersync.wavdata(wavidx).name;     
    jnk = audioinfo([folder num2str(masterserial) '\' wav2load]); 
    if jnk.TotalSamples < master_chunkend %possibly the case for the last file
        master_chunkend = jnk.TotalSamples;
    end
    y_master = audioread([folder num2str(masterserial) '\' wav2load],[master_firstsample, master_chunkend]);    
    
    stitchstruct(rr).master_STid        = masterserial;
    stitchstruct(rr).filecounter        = filecounter + 1;
    stitchstruct(rr).master_startidx    = master_startidx;
    stitchstruct(rr).master_startabc    = mastersync.syncdata(master_startidx).abc;
    stitchstruct(rr).master_firstsample = master_firstsample;
    stitchstruct(rr).master_chunkend    = master_chunkend;
    stitchstruct(rr).master_wavidx      = wavidx;
    stitchstruct(rr).master_wav2load    = wav2load;
    stitchstruct(rr).master_wavfolder   = folder;
    stitchstruct(rr).master_samptotal   = mastersync.syncdata(master_startidx).samptotal;
    stitchstruct(rr).master_flag        = mastersync.syncdata(master_startidx).flag;
    if rr == 1
        stitchstruct(rr).master_selfjitter = fs; 
    else
        stitchstruct(rr).master_selfjitter = stitchstruct(rr).master_samptotal -  stitchstruct(rr-1).master_samptotal; 
    end    
    
    % Remove the DC offset from MASTER wav channel
    offset = mean(y_master(:,1));
    for ss = 1:length(y_master) 
        y_master(ss,1) = y_master(ss,1) - offset;
    end %ss
    clear ss offset jnk    
        
    
    %% Get each SLAVE start & stop samples for this second
    y_slave       = [];
    num_zeros2add = 0;
    for ss=1:length(first_slave_startidxs) %loop over each Slave
        %disp(['--- Merging audio data of Master with slave ' num2str(ss) ' of ' num2str(length(slave_startidxs))])
        slave_startidx=[];
        zerofill_flag = 0;
        if rr==1 %if first second of minute
            slave_firstsample = slavesyncs(ss).sync.syncdata(first_slave_startidxs(ss)).wavsample;
            slave_startidx  = first_slave_startidxs(ss);
        else
            slave_startidx = first_slave_startidxs(ss) + rr - 1;    
            if slavesyncs(ss).sync.syncdata(slave_startidx).flag ==0; %ABC as usual
                slave_firstsample = slavesyncs(ss).sync.syncdata(slave_startidx).wavsample;
                disp([' File ' num2str(filecounter+1) ', case 0, slave ' num2str(ss) ', rr=' num2str(rr) ', row ' num2str(rr+7)])
                
            elseif slavesyncs(ss).sync.syncdata(slave_startidx).flag ==1; % CASE 1, slave skipped, load slave(stop-of-previous+fs-1: stop-of-previous+fs-1+fs-1)
                slave_firstsample = slavesyncs(ss).sync.syncdata(slave_startidx-1).wavsample;         
                disp([' File ' num2str(filecounter+1) ', case 1, slave ' num2str(ss) ', rr=' num2str(rr) ', row ' num2str(rr+7)])
                slave_startidx = slave_startidx -1;  %account for this in the csv file 2 load      
                
            elseif slavesyncs(ss).sync.syncdata(slave_startidx).flag ==2; % CASE 2, master skipped, load slave(start-of-next: start-of-next+fs-1)
                slave_firstsample = slavesyncs(ss).sync.syncdata(slave_startidx+1).wavsample;
                slave_startidx = slave_startidx +1;  %account for this in the csv file 2 load                 
                disp([' File ' num2str(filecounter+1) ', case 2, slave ' num2str(ss) ', rr=' num2str(rr) ', row ' num2str(rr+7)])                
            end               
            disp(['    Matching MASTER ' mastersync.syncdata(master_startidx).abc ' with SLAVE #',...
                num2str(ss) ', ' slavesyncs(ss).sync.syncdata(slave_startidx).abc])                       
        end %rr
                  
        % Account for situation where files change, and there's a skip in the beat (i.e. missing GPS-time letter). 
        % Fill with zeros (for that second, for that channel only).
        if slave_firstsample <0 
            y_slave_tmp = zeros(fs,1); % Fill with zeros to account for time lost during file changeover, for 1 sec duration
        else % Read in audio data               
            slave_chunkend = slave_firstsample + fs-1;            
            wavidx_slave = slavesyncs(ss).sync.syncdata(slave_startidx).csvfilenum; %first line of that file            
            wav2loadA    = slavesyncs(ss).sync.wavdata(wavidx_slave).name; %original
            pos          = strsplit(wav2loadA,'.');    
            slave_ST     = str2num(pos{1});
            jnk          = audioinfo([folder num2str(slave_ST) '\' wav2loadA]);
            %disp(['  Max samples available for slave ' num2str(ss) ' is ' num2str(jnk.TotalSamples)])
            
            num_zeros2add =0;
            if jnk.TotalSamples < slave_chunkend
                disp('    Total file is shorter than chunk_end')
                num_zeros2add  = slave_chunkend - jnk.TotalSamples; 
                slave_chunkend = jnk.TotalSamples;
            end            
            y_slave_tmp = audioread([folder num2str(slave_ST) '\' wav2loadA], [slave_firstsample, slave_chunkend]); %read in 1 sec of audio data

            if num_zeros2add>0 
                zeros2add   = zeros(num_zeros2add,1);
                y_slave_tmp = [y_slave_tmp; zeros2add];
            end
            clear zeros2add 
            
            % Remove DC offset of each SLAVE channel
            offset = mean(y_slave_tmp(:,1)); 
            for tt=1:length(y_slave_tmp(:,1))
                y_slave_tmp(tt,1) = y_slave_tmp(tt,1) - offset;
            end %tt  
            clear tt jnk pos
           
            stitchstruct(rr).slave(ss).STid              = slave_ST; 
            stitchstruct(rr).slave(ss).filecounter       = filecounter + 1; %aligns with string in output stitched wavfile
            stitchstruct(rr).slave(ss).slave_startidx    = slave_startidx;
            stitchstruct(rr).slave(ss).slavestart_abc    = slavesyncs(ss).sync.syncdata(slave_startidx).abc;
            stitchstruct(rr).slave(ss).slave_firstsample = slave_firstsample;
            stitchstruct(rr).slave(ss).slave_chunkend    = slave_chunkend;
            stitchstruct(rr).slave(ss).num_zerosadded    = num_zeros2add;
            stitchstruct(rr).slave(ss).slave_wavidx      = wavidx_slave;
            stitchstruct(rr).slave(ss).slave_wav2load    = wav2loadA;
            stitchstruct(rr).slave(ss).slave_wavfolder   = folder;
            stitchstruct(rr).slave(ss).slave_samptotal   = slavesyncs(ss).sync.syncdata(slave_startidx).samptotal;
            stitchstruct(rr).slave(ss).flag              = slavesyncs(ss).sync.syncdata(slave_startidx).flag;
            if rr == 1
                stitchstruct(rr).slave(ss).slave_selfjitter = fs;
                stitchstruct(rr).slave(ss).jitter2master    = 0; 
            else
                stitchstruct(rr).slave(ss).slave_selfjitter = stitchstruct(rr).slave(ss).slave_samptotal - stitchstruct(rr-1).slave(ss).slave_samptotal;
                stitchstruct(rr).slave(ss).jitter2master =  stitchstruct(rr).master_selfjitter - stitchstruct(rr).slave(ss).slave_selfjitter;
            end
        end
        y_slave(:,ss) = y_slave_tmp; %multi channel audio data of all slaves        
        clear slave_firstsample str slave_ST y_slave_tmp wav2load idx idx2 offset slave_chunkend
    end %ss loop over each slave            
    
       
    %% Combine MASTER wav data with SLAVE wav data  && Write multi-chan audiofile    
    if counter == 1 % Timestamp of file name indicates time of start of first, starting second in 60 sec file
        outfiletimestamp = datestr(mastersync.syncdata(master_startidx).datenum,'yyyymmdd_HHMMSS');   %start time extracted for naming wavfile
    end
    wavout = [wavout; y_master, y_slave]; %combine 1 sec chunks until it reaches a minute long   
    if counter ==60 || rr==numofsecs % Write a new audiofile every minute
        filecounter = filecounter +1;
        if filecounter <10
            filename = ['mergedwav_master_' num2str(masterserial) '_deployment',...
                num2str(deploymentnum) '_file00' num2str(filecounter) '__' outfiletimestamp '.wav'];
        elseif filecounter >=10 && filecounter < 100
            filename = ['mergedwav_master_' num2str(masterserial) '_deployment',...
                num2str(deploymentnum) '_file0' num2str(filecounter) '__' outfiletimestamp '.wav'];
        elseif filecounter >=100
            filename = ['mergedwav_master_' num2str(masterserial) '_deployment',...
                num2str(deploymentnum) '_file' num2str(filecounter) '__' outfiletimestamp '.wav'];
        end        
        outputfolder2 = [outputfolder '\wavfiles\' ];
        if ~exist(outputfolder2)
            mkdir(outputfolder2)
        end
        audiowrite([outputfolder2 '\' filename], wavout, fs); %write wavfile 
        disp(['---- Wrote audiofile #' num2str(filecounter) ' ----'])
        wavout  = []; %reset each minute
        counter = 0; %reset minute clock at end of each minute
        clear y_master y_slaves outfiletimestamp
    end % counter for each minute
end %rr
end %function; back to 'write_wavs.m'