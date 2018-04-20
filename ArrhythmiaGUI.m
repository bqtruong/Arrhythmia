classdef ArrhythmiaGUI < handle
    
    properties (SetObservable)
        Figure
        ECGAxisPanel
        ECGAxis
        ECGSlider
        SettingsBox
        DiagnosticHR
        HRText
        DiagnosticPR
        PRText
        DiagnosticST
        STText
        DiagnosticQS
        QSText
        ConditionReport
        ExportReport
        DataSelectionPanel
        DataSelectionButton
        DataSelectionList
        
        
        
        HRMat = [];
        HRThreshold = 10;
        HR = 0; %Initialize heart rate
        PRMat = [];
        PRThreshold = 0.2;
        PR = 0;
        STMat = [];
        STThreshold = 0.2;
        ST = 0;
        QS = 0;
        QSMat = [];
        QSThreshold = 0.1;
        RawDataMat = struct;
        Data = []; %Initialize data storage location
        FilteredData = [];
        ProjectionLength = 1000;
        DataLength = [];
        ProjectedMax = [];
        SavedData = zeros(10,5000); %Initialize Arrhythmia Storage (10 types, 5000 time points)
        SavedDataIdentifier = {};
        SavedDataVals = zeros(10,1);
        ErrorNum = 1;
        Fs = 360;
        Timer
        TimerUpdateRate = 1; %In s?
        
    end
    
    
    methods
        function app = ArrhythmiaGUI
            app.Figure = figure('MenuBar','none',...           % Main figure
                'NumberTitle','off','Name','ECG Arrythmia Detection',...
                'CloseRequestFcn',@app.closeApp);
            app.ECGAxisPanel = uipanel('Parent',app.Figure,...
                'Position',[0.05 0.50 0.70 0.46],'BorderType','none',...
                'BackgroundColor','white');
            app.ECGAxis = axes('Parent',app.ECGAxisPanel,...            % Axis for prices
                'Units','normalized','Position',[0.01 0.05 0.98 0.94],...
                'Box','on','XTickLabel',[],'XLimMode','manual',...
                'XLim',[0 app.ProjectionLength],'YTickLabel',[],'XTick',[],'YTick',[]);
            app.ECGSlider = uicontrol('Parent',app.ECGAxisPanel,...
                'Style','slider','Units','normalized',...
                'Position',[0.01 0.01 0.98 0.04],...
                'Min',app.ProjectionLength*2 + 1,'Max',app.ProjectionLength*2 + 2,'Callback',...
                @app.MoveAxis,'Value',app.ProjectionLength*2 + 1,'Visible','off');
            app.SettingsBox = uipanel('Parent',app.Figure,...
                'Position',[.05 .07 .70 .40],'BorderType','none');
            app.DiagnosticHR = uipanel('Parent',app.Figure,...
                'Position',[0.80 0.90 0.15 0.05],'BackgroundColor','white');
            app.HRText = uicontrol('Parent',app.DiagnosticHR,...
                'Units','normalized','Position',[0.05 0 0.9 0.9],...
                'Style','text','BackgroundColor','white',...
                'String',['HR: ',num2str(app.HR)]);
            app.DiagnosticPR = uipanel('Parent',app.Figure,...
                'Position',[0.80 0.85 0.15 0.05],'BackgroundColor','white');
            app.PRText = uicontrol('Parent',app.DiagnosticPR,...
                'Units','normalized','Position',[0.05 0 0.9 0.9],...
                'Style','text','BackgroundColor','white',...
                'String',['PR: ',num2str(app.PR)]);
            app.DiagnosticST = uipanel('Parent',app.Figure,...
                'Position',[0.80 0.80 0.15 0.05],'BackgroundColor','white');
            app.STText = uicontrol('Parent',app.DiagnosticST,...
                'Units','normalized','Position',[0.05 0 0.9 0.9],...
                'Style','text','BackgroundColor','white',...
                'String',['ST: ',num2str(app.ST)]);
            app.DiagnosticQS = uipanel('Parent',app.Figure,...
                'Position',[0.80 0.75 0.15 0.05],'BackgroundColor','white');
            app.QSText = uicontrol('Parent',app.DiagnosticQS,...
                'Units','normalized','Position',[0.05 0 0.9 0.9],...
                'Style','text','BackgroundColor','white',...
                'String',['D4: ',num2str(app.HR)]);
            app.DataSelectionPanel = uipanel('Parent',app.Figure,...
                'Position',[0.80 0.25 0.15 0.10],'BackgroundColor','white');
            app.DataSelectionButton = uicontrol('Parent',app.DataSelectionPanel,...
                'Style','pushbutton','Units','normalized','Position',[0.05 0.5 0.9 0.45],...
                'String','Select Data','Callback',@app.DataImport);
            app.DataSelectionList = uicontrol('Parent',app.DataSelectionPanel,...
                'Style','popupmenu','Units','normalized','Position',[0.05 0 0.9 0.45],...
                'Callback',@app.DataSelect,'Visible','off');
            CD = @(a,b) MoveAxis(app,a,b);
            hListen = addlistener(app.ECGSlider,'Value','PostSet',CD); %temporary to experiment with continuous sliders
        end
        
        function closeApp(app,hObject,eventdata)
            % This function runs when the app is closed
            try
            catch ME
                stop(app.Timer)
                delete(app.Timer)
            end
            delete(app.Figure)
        end
        
        function systemUpdateCallback(app,hObject,eventdata)
            app.updateDisplay
        end
        
        function updateDisplay(app,hObject,eventdata)
            FilterData(app);
            PeakFinder(app);
            cla(app.ECGAxis)
            tempLim = app.ECGAxis.XLim(1):app.ECGAxis.XLim(end);
            plot(app.ECGAxis,tempLim,app.FilteredData(app.ProjectionLength+1:end))
            app.ECGAxis.XTickLabel = [];
            app.ECGAxis.XTick = [];
            app.ECGAxis.YTick = [];
            app.ECGAxis.XLim = [tempLim(1) tempLim(end)];
            app.HRText.String = ['HR: ' num2str(app.HRMat)];
            app.PRText.String = ['PR: ' num2str(app.PRMat)];
            app.STText.String = ['ST: ' num2str(app.STMat)];
            app.QSText.String = ['QS: ' num2str(app.QSMat)];
        end
                
        function DataImport(app,hObject,eventdata)
            app.RawDataMat = uiimport;
            try
                DataSelect(app)
                app.DataSelectionList.String = {app.RawDataMat.labels.Description};
                app.DataSelectionList.Visible = 'on';
            catch ME
                warning('Incorrect Data Type')
            end
        end
        
        function DataSelect(app,hObject,eventdata)
            app.Data = app.RawDataMat.signal(:,app.DataSelectionList.Value);
            app.DataLength = length(app.Data);
            app.ECGSlider.Max = app.DataLength;
            app.ECGSlider.SliderStep = [25/(app.ECGSlider.Max), 25/(app.ECGSlider.Max)]; %conrols slider speed
            InitializeExpectedRatios(app)
            systemUpdateCallback(app)
            app.ECGSlider.Visible = 'on';
        end
        
        function MoveAxis(app,hObject,eventdata)
            app.ECGSlider.Value = round(app.ECGSlider.Value);
            app.ECGAxis.XLim = [app.ECGSlider.Value-app.ProjectionLength,app.ECGSlider.Value];
            systemUpdateCallback(app)
        end
        
        function FilterData(app,hObject,eventdata)
            Fn = app.Fs/2; %nyquest
            data = app.Data((app.ECGSlider.Value-app.ProjectionLength*2):app.ECGSlider.Value);
            b=fir1(48, [59.8 60.2]/Fn, 'stop'); %consider changing filter - "works" down to 2, might need to investigate w/o smoothing
            %In the case of needing to filter low frequency noise
            %b=fir1(48, [5 30]/Fn,'bandpass');
            data = smooth(filter(b,1,data));
            data = detrend(data,'constant');
            app.FilteredData = data;
        end
        
        function InitializeExpectedRatios(app,hObject,eventdata)
            FilterData(app)
            PeakFinder(app)
            app.HRMat = app.HR;
            app.PRMat = app.PR;
            app.STMat = app.ST;
            app.QSMat = app.QS;
            app.ProjectedMax = 0;
        end
            
        function PeakFinder(app,hObject,eventdata,init)
            % Extract Intervals
            % R waves
            complexes = zeros(length(app.FilteredData),10);
            [pks, lcs] = findpeaks(app.FilteredData,'MinPeakDistance',(.2*app.Fs));
            Rlcs_local = pks >= max(pks)*.7;
            Rlcs_global = lcs(Rlcs_local);
            Rpks = app.FilteredData(Rlcs_global);
            complexes(1:length(Rlcs_global),3) = Rlcs_global;
            complexes(1:length(Rlcs_global),3+5) = Rpks;
%             separationEstimate = mean(diff(sort(Rlcs_global)));
%             sortedRlcs = sort(Rlcs_global);

            % May need to tweak estimates given heart rate
            for i = 2:length(Rlcs_global)-1
                forwardEstimate = round(mean([Rlcs_global(i+1) Rlcs_global(i)]));
                backwardEstimate = round(mean([Rlcs_global(i-1) Rlcs_global(i)]));
                % P waves
                [pks, lcs] = findpeaks(app.FilteredData(backwardEstimate:Rlcs_global(i)), 'SortStr', 'descend');
                complexes(i,1) = lcs(1)+backwardEstimate-1;
                complexes(i,1+5) = pks(1);
                % Q waves
                [pks, lcs] = findpeaks(-app.FilteredData(backwardEstimate:Rlcs_global(i)), 'SortStr', 'descend');
                complexes(i,2) = lcs(1)+backwardEstimate-1;
                complexes(i,2+5) = -pks(1);
                % S waves
                [pks, lcs] = findpeaks(-app.FilteredData(Rlcs_global(i):forwardEstimate), 'SortStr', 'descend');
                complexes(i,4) = lcs(1)+Rlcs_global(i)-1;
                complexes(i,4+5) = -pks(1);
                % T waves
                [pks, lcs] = findpeaks(app.FilteredData(Rlcs_global(i):forwardEstimate), 'SortStr', 'descend');
                complexes(i,5) = lcs(1)+Rlcs_global(i)-1;
                complexes(i,5+5) = pks(1);
                % Show bounds of waveform
                %line([data(backwardEstimate,1) data(backwardEstimate,1)],[-.4 1.4]);
                %line([data(forwardEstimate,1) data(forwardEstimate,1)],[-.4 1.4]);
            end
            
            complexes(1,:) = [];
            complexes(end,:) = [];
            del = find(complexes(:,1) == 0 & complexes(:,2) == 0,1,'first');
            complexes(del:end,:) = [];
            % Intervals? How to find intervals rather than peaks?
            RR = mean(diff(complexes(:,3),1))/app.Fs;
            app.PR = mean(complexes(:,3)-complexes(:,1))/app.Fs;
            app.ST = mean(complexes(:,5)-complexes(:,4))/app.Fs;
            app.HR = 60/RR;
            app.QS = mean(complexes(:,4)-complexes(:,2))/app.Fs;
            
            try
                if app.ProjectedMax < app.ECGSlider.Value
                    if abs(app.HRMat - app.HR) <= app.HRThreshold
                        app.HRMat = mean([app.HRMat app.HR]);
                    else
                        warndlg('HR Error')
                        app.SavedDataVals(app.ErrorNum) = app.ECGSlider.Value;
                        app.SavedDataIdentifier{app.ErrorNum} = 'HR';
                        app.ErrorNum = app.ErrorNum + 1;
                        
                    end
                    if abs(app.PRMat - app.PR) <= app.PRThreshold
                        app.PRMat = mean([app.PRMat app.PR]);
                    else
                        warndlg('PR Error')
                        app.SavedDataVals(app.ErrorNum) = app.ECGSlider.Value;
                        app.SavedDataIdentifier{app.ErrorNum} = 'PR';
                        app.ErrorNum = app.ErrorNum + 1;
                    end
                    if abs(app.STMat - app.ST) <= app.STThreshold
                        app.STMat = mean([app.STMat app.ST]);
                    else
                        warndlg('ST Error')
                        app.SavedDataVals(app.ErrorNum) = app.ECGSlider.Value;
                        app.SavedDataIdentifier{app.ErrorNum} = 'ST';
                        app.ErrorNum = app.ErrorNum + 1;
                    end
                    if abs(app.QSMat - app.QS) <= app.QSThreshold
                        app.QSMat = mean([app.QSMat app.QS]);
                    else
                        warndlg('QS Error')
                        app.SavedDataVals(app.ErrorNum) = app.ECGSlider.Value;
                        app.SavedDataIdentifier{app.ErrorNum} = 'QS';
                        app.ErrorNum = app.ErrorNum + 1;
                    end
                    app.ProjectedMax = app.ECGSlider.Value;
                end
            catch ME
            end
        end
    end
end
