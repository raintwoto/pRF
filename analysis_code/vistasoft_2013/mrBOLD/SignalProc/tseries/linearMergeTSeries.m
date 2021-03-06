function view=linearMergeTSeries(view,scanList,typeName,weights)
% view=linearMergeTSeries(view,scanList,typeName,weights)
%
% Merge tSeries data together using the weights specified. Weights can be
% negative as well as positive. There must be as many weights as tSeries.
% If weights does not exist, we assume that all the weights are '1': i.e.
% that we have a simple addition of all the tseries data.
%
% Creates dataType 'Merged' if it doesn't already exist.
%
% Output is a new set of tSeries files in a new Scan subdirectory
% under the Merged directory. (Or whatever name you asked for)
%
% Uses the current dataType of the view to determine which tSeries
% to average.
%
% Based on averageTSeries
% ARW 042105: Wrote it

mrGlobals

if (~exist('scanList','var') | isempty(scanList)), scanList = selectScans(view); end
if (~exist('typeName','var') | isempty(typeName)), typeName='Merged'; end
if ~existDataType(typeName), addDataType(typeName); end

checkScans(view,scanList);

if (ieNotDefined('weights')) 
    % Several options here: 1: just force all weights to 1
    % 2: set the weights to 1/n (so perform an average)
    % 3: Do two calls to 'select scans': First setting the positive scans,
    % then the -ve ones
    % 4: Write some new GUI where you can select scans and enter weights
    % next to them
    weights=ones(length(scanList),1);
end

% Open a hidden view and set its dataType to 'Averages'
switch view.viewType
    case 'Inplane'
        hiddenView = initHiddenInplane;
    case 'Volume'
        hiddenView = initHiddenVolume;
    case 'Gray'
        hiddenView = initHiddenGray;
    case 'Flat'
        hiddenView = initHiddenFlat(viewDir(view));
end
hiddenView = selectDataType(hiddenView,existDataType(typeName));

% Set dataTYPES.scanParams so that new merged scan has the same params as
% the 1st scan on scanList.
newScanNum = numScans(hiddenView)+1;
ndataType = hiddenView.curDataType;
dataTYPES(ndataType).scanParams(newScanNum) = dataTYPES(view.curDataType).scanParams(scanList(1));
dataTYPES(ndataType).blockedAnalysisParams(newScanNum) = dataTYPES(view.curDataType).blockedAnalysisParams(scanList(1));
dataTYPES(ndataType).eventAnalysisParams(newScanNum) = dataTYPES(view.curDataType).eventAnalysisParams(scanList(1));
dataTYPES(ndataType).scanParams(newScanNum).annotation = ['Lin merge of ',getDataTypeName(view),', scans: ',num2str(scanList)];
saveSession

% Get the tSeries directory for this dataType 
% (make the directory if it doesn't already exist).
tseriesdir = tSeriesDir(hiddenView);

% Make the Scan subdirectory for the new tSeries (if it doesn't exist)
scandir = fullfile(tseriesdir,['Scan',num2str(newScanNum)]);
if ~exist(scandir,'dir')
    mkdir(tseriesdir,['Scan',num2str(newScanNum)]);
end

% Double loop through slices and scans in scanList
nAvg = length(scanList);
% *** check that all scans have the same slices
waitHandle = waitbar(0,'Merging tSeries.  Please wait...');
nSlices = length(sliceList(view,scanList(1)));

for iSlice = sliceList(view,scanList(1));
    % For each slice...
    % disp(['Averaging scans for slice ', int2str(iSlice)])
    for iAvg=1:nAvg
        iScan = scanList(iAvg);
 
        tSeries = loadtSeries(view, iScan, iSlice);
        
        % Remove the mean. Why? Because if we subtract tSeries from each
        % other, we can drive the mean value very low. Then when we come to
        % compute percentTSeries, we get very high vals. 
        % A better way is to remove the mean now and linear merge the
        % modulations. Then add back the mean baseline later...
        
        
        % Do the weighting
        
        nFrames=size(tSeries,1);
         mts=mean(tSeries);
         tSeries=tSeries-repmat(mts,nFrames,1);
        tSeries=tSeries*weights(iAvg);
        
        bad = isnan(tSeries);
        tSeries(bad) = 0;
       
        
        
        if iAvg > 1;
            
            meanBaseline=meanBaseline+mts;
            
            tSeriesAvg = tSeriesAvg + tSeries;
            nValid = nValid + ~bad;
        else
            meanBaseline=mts;
            tSeriesAvg = tSeries;
            nValid = ~bad;
        end
    end
    meanBaseline=meanBaseline/nAvg;
    tSeriesAvg=tSeriesAvg+repmat(meanBaseline,nFrames,1);
    
    %tSeriesAvg = tSeriesAvg ./ nValid;
    tSeriesAvg(nValid == 0) = NaN;
    savetSeries(tSeriesAvg,hiddenView,newScanNum,iSlice);
    waitbar(iSlice/nSlices);
end

close(waitHandle);

% Loop through the open views, switch their curDataType appropriately, 
% and update the dataType popups
INPLANE = resetDataTypes(INPLANE,ndataType);
VOLUME  = resetDataTypes(VOLUME,ndataType);
FLAT    = resetDataTypes(FLAT,ndataType);

return;

function checkScans(view,scanList)
%
% Check that all scans in scanList have the same slices, numFrames, cropSizes
for iscan = 2:length(scanList)
    if find(sliceList(view,scanList(1)) ~= sliceList(view,scanList(iscan)))
        mrErrorDlg('Can not merge these scans; they have different slices.');
    end
    if (numFrames(view,scanList(1)) ~= numFrames(view,scanList(iscan)))
        mrErrorDlg('Can not merge these scans; they have different numFrames.');
    end
    if find(sliceDims(view,scanList(1)) ~= sliceDims(view,scanList(iscan)))
        mrErrorDlg('Can not merge these scans; they have different cropSizes.');
    end
end
return;