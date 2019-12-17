%% "plot_to_check_samples.m"
% 
% PLOT_TO_CHECK_SAMPLES 
%    - Gives a graphical confirmation that the sample counting within each
%       device is behaving as expected (whereby each device sample count
%       increases until it hits 2^32 and then resets). 
%    - If there is a SoundTrap behaving erratically, whereby the sample 
%       count resets randomly and before it hits 2^32, this should be noted
%    - Used after the script 'run_wav_timesync.m'
%    - Output is figures of sample count alignment for each deployment

%    (No SoundTrap sync library functions are nested within this function).
%
%     CEM. Last modified March 2019;
%     chloe.e.malinka@bios.au.dk
% 
%% USER INPUTS 
clear
cd('C:\Users\au574966\Google Drive\MatCode\SoundTrap\sync_lib_Chloe_publish\DSRI\')
SaveFig  = 0;% 1 if Save, 0 if no save
%folder_processed  = 'C:\ArrayData\processed_data\'; % Define where data is saved
folder_processed  = 'E:\processed_data\'; % Define where data is saved


%% LOAD ARRAY SUMMARY DATA  (output of "get_array_structure.m")
%load([folder_processed 'array_deploy_summary.mat']) %arraydates
load('C:\Users\au574966\Google Drive\MatCode\SoundTrap\sync_lib_Chloe_publish\Tenerife\array_deploy_summary_Tenerife.mat')

%% LOOP OVER DEPLOYMENTS
for pp = 5%1:length(arraydates); 
    clear deploydate masterserial slavenames fig odn ofn idx1 
    deploymentnum = pp;

    %% Load previously made matfiles if you've already aligned it
    deploydate     = arraydates(deploymentnum).deploydate;
    masterserial   = arraydates(deploymentnum).masterserial;
    if deploymentnum <10
        dn = [folder_processed '\time_synced_files\deployment0' num2str(deploymentnum) '\matfiles\'];
    else
        dn = [folder_processed '\time_synced_files\deployment' num2str(deploymentnum) '\matfiles\'];
    end
    fn = ['timesyncinfo_deployment_' num2str(deploymentnum) '.mat'];
    clear mastersync slavesyncs startindexes fs outputfolder folder deploymentnum masterstart_abc 
    load([dn fn]);
    clear dn fn
    
    
    %% Keep track of instances where file changes (Master only)
    idx1 = [];
    for rr=2:length([mastersync.syncdata])
        if [mastersync.syncdata(rr).csvfilenum] > [mastersync.syncdata(rr-1).csvfilenum]
            idx1 = [idx1; rr]; %these are indices for starts of new files
        end
    end %rr
    clear rr

    
    %% Get serial numbers of Receiving Soundtraps (Slaves) for plot legend
    slavenames = {};
    for qq=1:length(slavesyncs)
        jnk = [slavesyncs(qq).sync.wavdata(1).name(1:end-4)];
        %slavenames{qq}= extractBefore(jnk,'.'); %works in Matlab 2017a and above
        slavenames{qq} = jnk(1:findstr(jnk,'.')-1);
    end
    clear qq jnk 
    
    
    %% Plot
    fig = figure(1);
        clf
        set(gcf,'Position',[132 96 1702 879]);
        subplot(231)
            aa = plot([mastersync.syncdata.samp]);
            hold on
            bb = vline(idx1); %vertical lines show file divisions
            title({'Transmitting SoundTrap';'(Master) .samp'})
            legend([aa,bb],{num2str(masterserial),'Master file division'},'Location','northwest')

        subplot(232)
            aa = plot([mastersync.syncdata.samptotal]);
            hold on
            bb = vline(idx1);
            title({'Transmitting SoundTrap';'(Master) .samptotal'})
            legend([aa,bb],{num2str(masterserial),'Master file division'},'Location','northwest')

        subplot(233)
            aa = plot([mastersync.syncdata.wavsample]);
            hold on
            bb = vline(idx1);
            title({'Transmitting SoundTrap';'(Master) .wavsample'})
            legend([aa,bb],{num2str(masterserial),'Master file division'},'Location','northwest')

        subplot(234)
            for qq=1:length([slavesyncs.sync])
                plot([slavesyncs(qq).sync.syncdata.samp])
                hold on
                legendInfo{qq} = ['Slave row ' num2str(qq) ', ' slavenames{qq}]; 
            end %qq
            xlabel('Sample #')
            legend(legendInfo,'Location','northwest')
            title({'Receiving Soundtraps';'(Slaves) .samp'})

        subplot(235)
            for qq=1:length([slavesyncs.sync])
                plot([slavesyncs(qq).sync.syncdata.samptotal])
                hold on
                legendInfo{qq} = ['Slave row ' num2str(qq) ', ' slavenames{qq}]; 
            end %qq
            legend(legendInfo,'Location','northwest')
            xlabel('Sample #')
            title({'Receiving Soundtraps';'(Slaves) .samptotal'})

        subplot(236)
            for qq=1:length([slavesyncs.sync])
                plot([slavesyncs(qq).sync.syncdata.wavsample])
                hold on
                legendInfo{qq} = ['Slave row ' num2str(qq) ', ' slavenames{qq}]; 
            end %qq
            clear qq
            legend(legendInfo,'Location','northwest')
            xlabel('Sample #')
            title({'Receiving Soundtraps';'(Slaves) .wavsample'})
            
        suptitle(['Array deployment #' num2str(deploymentnum)])
        
        disp(' NB: "Slave row" refers to the row in the "slavesyncs" structure.')
        disp('     If any SoundTrap is behaving erratically, whereby the sample count resets randomly and prior to hitting 2^32, the cumulative sample count of the erratic device will not increase in a pattern parallel to other devices.')
        disp('     If this is the case for any of your SoundTraps, note the "slaverow" in which this occurs, and input this in "write_wavs" as the variable "to_exclude".')
            
    %% check master.syncdata.wavsample (should all be positive values)       
    idx = find([mastersync.syncdata.wavsample]<0);
    if isempty(idx)
        disp(['Deployment:' num2str(pp) ', No negative master wavesamples exist :) '])
    else
        disp(['Deployment:' num2str(pp) ', Negative master wavesamples exists, ' num2str(length(idx)) ' times'])
    end
    clear idx

    
    %% Save fig1
    if SaveFig ==1
        odn = [folder_processed 'time_synced_files\check_samples\'];
        if exist(odn)==0, mkdir(odn), end
        if deploymentnum <10
            ofn = ['check_samplecounts_deployment0' num2str(deploymentnum) '.tiff'];
        else
            ofn = ['check_samplecounts_deployment' num2str(deploymentnum) '.tiff'];
        end
        saveas(fig,[odn ofn],'tiff'); 
    end
    

end %pp loop over deployments