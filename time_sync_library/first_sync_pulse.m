function [startindexes, masterstart_abc] = first_sync_pulse(mastersync, slavesyncs)
%
%% FIRST_SYNC_PULSE 
%    Finds the first sync pulse which is shared by the master and the slaves.
%
%    [STARTINDEXES, MASTERSTART_ABC] = FIRST_SYNC_PULSE(MASTERSYNC,SLAVESYNCS)  
%    finds the first sync pulse from the MASTERSYNC list which is present
%    on all SLAVESYNCS devices. 
%   
%    STARTINDEXES gives the index at which the common start occurs on each
%       transmitting and receiving device. 
%    MASTERSTART_ABC gives the letter on the master at which this common
%       start occurred. 
%
%    MASTERSYNC is a structure of sync values; and
%    SLAVESYNCS is an array of sync structures of the slave (receiving) STs 
%
%    Used within script 'run_wav_timesync.m'
%    (No SoundTrap sync library functions are nested within this function).
%
%     CEM. Last modified April 2019.
%     chloe.e.malinka@bios.au.dk
%
%% Find common starts/stops of pings across all devices.
disp('--- Finding first common sync pulse across all devices')
starttimes(1) = mastersync(1).syncdata(1).datenum; %starttime of master
for i=1:length(slavesyncs) %starttimes of all slaves
    starttimes(i+1) = slavesyncs(i).sync(1).syncdata(1).datenum; %first datestamp at time first pulse was received on each slave
end
[commonstart, ~] = max(starttimes); % first common time across all devices on array

disp('--- Finding last common sync pulse across all devices')
endtimes(1)  = mastersync(1).syncdata(end).datenum; 
for i=1:length(slavesyncs) %starttimes of all slaves
    endtimes(i+1) = slavesyncs(i).sync.syncdata(end).datenum; %first datestamp at time first pulse was received on each slave
end
[commonstop, ~] = min(endtimes); % last common time across all devices on array

%% Now go to this time of first common pulse in the master list; 
idxs = find([mastersync.syncdata.datenum] > (commonstart+5/60/60/24)); %add a 5 sec buffer.
startindexes_allalignments = [];

indexstart = idxs(1);
masterstart_date = mastersync.syncdata(indexstart).datenum;
masterstart_abc  = mastersync.syncdata(indexstart).abc;
slaves_index  = [];

for i = 1:length(slavesyncs) % Loop over each slave
    %disp(['  Aligning start of SoundTrap Slave #' num2str(i) '/' num2str(length(slavesyncs)) ' to Master'])
    clear slavesync minval slave_index slave_abc slave_date idx2try caseflag  
    clear matchidx_forwards matchidx_backwards matchidx slave_index_corrected 
    
    wasbackwards = [];   
    slaves_index_offset = [];
    
    slavesync = slavesyncs(i).sync;    
    [minval, slave_index] = min(abs([slavesync.syncdata.datenum] - masterstart_date)); %closest slave time to master start time, for given outfile

    % Start a search for aligning ABC-letter around that data
    slave_abc  = slavesync.syncdata(slave_index).abc;
    slave_date = slavesync.syncdata(slave_index).datenum;

    for qq = 1:26 %ITERATE FORWARDS through the alphabet  
        %disp(['qq= ' num2str(qq)])
        if qq==1
            slave_abc = slavesync.syncdata(slave_index).abc;
        else
            if idx2try > length(slavesync.syncdata)
                disp(['Warning!: idx2try > length(slavesync.syncdata). Slave idx= ' num2str(slave_abc),...
                    ', slave length= ' num2str(length(slavesync.syncdata)),...
                    'slave i=' num2str(i) ', idxs pp=' num2str(pp)])
                return;
            end
            slave_abc = slavesync.syncdata(idx2try).abc;  
        end

        %disp(['     Going forwards: qq=' num2str(qq) ', abc=' slave_abc])
        if strcmp(slave_abc, masterstart_abc)==0
            idx2try = slave_index + qq;   
        else
            %disp(['     Found letter match going forwards, qq=' num2str(qq)])
            matchidx_forwards = qq;
            break 
        end        
    end %qq

    caseflag = 0;
    for qq = 1:26 %ITERATE BACKWARDS through alphabet as well
        %disp(['qq= ' num2str(qq)])
        if qq==1
            slave_abc = slavesync.syncdata(slave_index).abc;
        else
            slave_abc = slavesync.syncdata(idx2try).abc;
        end            
        %disp(['     Going backwards: qq=' num2str(qq) ', Slave abc=' slave_abc])
        if strcmp(slave_abc, masterstart_abc)==0
            idx2try = slave_index - qq;  
            %disp(['idx2try is ' num2str(idx2try)])
            if idx2try <=0
                caseflag = 1;
                break %exit for loop
            end
        else
            %disp(['     Found letter match going backwards, qq=' num2str(qq)])
            matchidx_backwards = qq;
            wasbackwards = 1;
            break 
        end        
    end %qq

    %disp(['     Match index forwards is ' num2str(matchidx_forwards-1),...
    %    ', Match index backwards is ' num2str(matchidx_backwards-1)])

    
    %% Go with the match with the fewest # of jumps
    if caseflag ==1
        matchidx = matchidx_forwards - 1; 
    else
        matchidx = min(matchidx_backwards, matchidx_forwards)-1;
    end
    
    if wasbackwards ==1
        matchidx = matchidx*-1;
    end
    slave_index_corrected = slave_index + matchidx; 

    
    %% Implement match decision
    slaves_index(1,i) = slave_index_corrected; %get the correct index
    slaves_index_offset(1,i) = abs(masterstart_date - (slavesync.syncdata(slaves_index(1,i)).datenum))*60*60*24; %time offset in seconds
    %disp(['     Going with match: ' num2str(matchidx)])

    if (slaves_index_offset(1,i)>2)
       disp(['Warning!: Time sync offset at the start is high '...
           num2str(slaves_index_offset(1,i)) 's for slave ' num2str(i) ])%' pp=' num2str(pp)] ) 
       % This could be a result of not syncing the sudar clock of all
       % master and slaves prior to deployment. Ideally this is done no
       % more than a few hours before the master starts sendings its pings.
    end   
    
    %disp(['i = ' num2str(i) ', slave_abc = ' slavesync.syncdata(slaves_index(1,i)).abc,...
    %    ', slave idx # = ' num2str(slaves_index(1,i))])  

end %for i loop over slaves
startindexes = [indexstart, slaves_index]; %first column is master, then all slaves
disp('Finished aligning common pulses')

end % of function; back to 'run_wav_timesync.m'
%%