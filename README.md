# SoundTrapArray

This MATLAB library has been written to time-synchronise WAV files for all channels on a SoundTrap array for a given deployment. This is supplementary material for the following peer-reviewed publication: 

<b>Malinka CE, Atkins J, Johnson MP, Tonnesen PH, Dunn CA, Claridge DE, Aguilar de Soto N, Madsen PT (2019). "An autonomous hydrophone array to study the acoustic ecology of deep-water toothed whales." Deep Sea Research I. [doi].</b>

The library has been tested on MATLAB version 9.2 (release 2017a). The output is a series of multi-channel time-synchronised WAV files with a default length of one minute (this is user modifiable but longer files at this sampling rate can be difficult to work with). 

This repository also contains:
- a download for the 3D print file for the breakouts.
- downloads for the firmware used in both the 'transmitter' and 'receiver' configurations of the SoundTrap.

## How to use the library to time synchronise recordings

For details on how to configure the soundtraps, please refer to the published paper.

First, organise your raw data from all SoundTraps, with all continuous recordings from individual devices in their own folder, named by their SoundTrap serial ID number, so that, for example:
-	…\ArrayData\raw_data\soundtrap\deployment01\1409810481\
-	…\ArrayData\raw_data\soundtrap\deployment01\1409810481\

Also make a folder called ‘processed_data’ at the same level as the ‘raw_data’ folder so that:
-	…\ArrayData\processed_data\

The user then opens <b>“get_array_structure.m”</b> and inputs, for their field season: 1) the deployment number; 2) the serial ID of the transmitting SoundTrap for that deployment; and 3) the date of that deployment. This saves a structure which is called on in the following script.

Secondly, the user opens <b>“run_wav_timesync.m”</b>, and inputs: 1) the deployment number; 2) the folder that contains all of the raw SoundTrap data for all deployments; and 3) the location where the multi-channel WAV files and time-alignment MAT files are to be saved. This script then calls on several functions, and makes a structure for each deployment that specifies aligning sample numbers across all devices, for every second of the deployment.

The user can optionally run <b>“plot_to_check_samples.m”</b>. This gives a visual confirmation that the sample-counting within each device is behaving as expected (whereby they should increase until they hit 2^32, and then reset. If there is a SoundTrap which is behaving erratically (whereby the sample count resets randomly, and prior to hitting 2^32), it will be evident in the plots since the cumulative sample count of the erratic device will not increase in a pattern parallel to the other devices. The deployment number and erratic device should be noted (its input is prompted in the following script, “write_wavs.m”). (We found this to be the case for only one of the 26 SoundTraps used in all 34 array deployments to date.) 

Then the user opens <b>“write_wavs.m”</b>. Here, the user inputs the deployment number and runs the script, which outputs the multi-channel WAV files. If there are any channels which behaved erratically, the user can specify the deployment number and relevant channel on which this occurs. The user can sanity-check the time alignment by finding the recommended physical taps between the Transmitter and each Receiver SoundTrap at the beginning and/or the end of each deployment. 

These time-aligned acoustic recordings can then be analysed as desired. Since the time-delays of sounds arriving at different channels can be trusted, they can be used in acoustic localisation applications.

