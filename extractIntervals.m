% function [HR, RR, PR, ST] = extractIntervals(data, bHR, bRR, bPR, bST)
% data: [npoints*2], first column time, second column values
% !!!Must have at least 3 PQRST waves to function without modification.
figure(100);
clf
hold on;
load 100m.mat;
%data = csvread('C:\Users\Brian\Downloads\drive-download-20180410T033801Z-001\Team21ECG-lead3.csv',0,3,'D1..E10000');
data = [tm' signal(:,1)];
filterData = data(:,2);
 
% Filtering
% sampleRate = 0.0028; %s
sampleRate = data(2,1)-data(1,1);
Fs = 1/sampleRate; %hz
Fn = Fs/2; %nyquest
fdata = filterData;
b=fir1(48, [59.8 60.2]/Fn, 'stop');
%In the case of needing to filter low frequency noise
%b=fir1(48, [5 30]/Fn,'bandpass');
fdata = smooth(filter(b,1,fdata));
filterData = detrend(fdata,'constant');

%% Extracting peak information
% R waves
[pks, lcs] = findpeaks(filterData,'MinPeakDistance',(.2/sampleRate));
Rlcs_local = find(pks >= max(pks)*.4); % This may need to be adjusted depending on the sample. 
Rlcs_global = lcs(Rlcs_local);
Rpks = filterData(Rlcs_global);
complexes = zeros(length(Rlcs_global),10);
complexes(1:length(Rlcs_global),3) = Rlcs_global;
complexes(1:length(Rlcs_global),3+5) = Rpks;

% May need to tweak estimates given heart rate
for i = 2:length(Rlcs_global)-1
%      if i == 1
%         forwardEstimate = round(mean([Rlcs_global(i+1) Rlcs_global(i)]));
%         if Rlcs_global(i)-(forwardEstimate-Rlcs_global(i)) < 1
%             backwardEstimate = 1;
%         else
%             backwardEstimate = forwardEstimate - Rlcs_global(i);
%         end
%     elseif i == length(Rlcs_global)
%         backwardEstimate = round(mean([Rlcs_global(i-1) Rlcs_global(i)]));
%         if Rlcs_global(i)+(Rlcs_global(i)-backwardEstimate) > size(data,1)
%             forwardEstimate = size(data,1);
%         else
%             forwardEstimate = Rlcs_global(i)+(Rlcs_global(i)-backwardEstimate);
%         end
%     else
%         forwardEstimate = round(mean([Rlcs_global(i+1) Rlcs_global(i)]));
%         backwardEstimate = round(mean([Rlcs_global(i-1) Rlcs_global(i)]));
%     end
    forwardEstimate = round(mean([Rlcs_global(i+1) Rlcs_global(i)]));
    backwardEstimate = round(mean([Rlcs_global(i-1) Rlcs_global(i)]));
    % P waves
    [pks, lcs] = findpeaks(filterData(backwardEstimate:Rlcs_global(i)), 'SortStr', 'descend');
    complexes(i,1) = lcs(1)+backwardEstimate-1;
    complexes(i,1+5) = pks(1);
    % Q waves
    [pks, lcs] = findpeaks(-filterData(backwardEstimate:Rlcs_global(i)), 'SortStr', 'descend');
    complexes(i,2) = lcs(1)+backwardEstimate-1;
    complexes(i,2+5) = -pks(1);
    % S waves
    [pks, lcs] = findpeaks(-filterData(Rlcs_global(i):Rlcs_global(i)+.2/sampleRate), 'SortStr', 'descend');
    complexes(i,4) = lcs(1)+Rlcs_global(i)-1;
    complexes(i,4+5) = -pks(1);
    % T waves
    [pks, lcs] = findpeaks(filterData(Rlcs_global(i):forwardEstimate), 'SortStr', 'descend');
    complexes(i,5) = lcs(1)+Rlcs_global(i)-1;
    complexes(i,5+5) = pks(1);
    % Show bounds of waveform
    %line([data(backwardEstimate,1) data(backwardEstimate,1)],[-.4 1.4]);
    %line([data(forwardEstimate,1) data(forwardEstimate,1)],[-.4 1.4]);
end

%% Post-processing complexes: removing excess.
% Given that a large number of waves will be inputted, the first and last
% waves are not processed in case the ends exceed the limits of the data.
complexes(1,:) = [];
complexes(end,:) = [];

% Intervals? How to find intervals rather than peaks?
RRm = mean(diff(data(complexes(:,3),1)));
RRs = std(diff(data(complexes(:,3),1)));
PRcom = complexes;
PRcom(PRcom(:,1) == 0) = [];
PRm = mean(data(PRcom(:,3),1)-data(PRcom(:,1),1));
PRs = std(data(PRcom(:,3),1)-data(PRcom(:,1),1));
STcom = complexes;
STcom(STcom(:,4) == 0 | STcom(:,5) == 0) = [];
STm = mean(data(STcom(:,5),1)-data(STcom(:,4),1));
STs = std(data(STcom(:,5),1)-data(STcom(:,4),1));
HRm = 60/RRm;
HMs = HRm*RRs;

QScom = complexes;
QScom(QScom(:,2) == 0 | QScom(:,4) == 0) = [];
QSm = mean(data(QScom(:,4),1)-data(QScom(:,2),1));
QSs = std(data(QScom(:,4),1)-data(QScom(:,2),1));

QRpm = mean(complexes(:,3+5)-complexes(:,2+5));
QRps = std(complexes(:,3+5)-complexes(:,2+5));
STpm = mean(STcom(:,5+5)-STcom(:,4+5));
STps = std(STcom(:,5+5)-STcom(:,4+5));
abnormalities = [];
for i = 1:size(complexes,1)
    if complexes(i,3+5)-complexes(i,2+5) > QRpm + 4*QRps % QR peak
        abnormalities = [abnormalities complexes(i,3)];
    end
    if complexes(i,5+5)-complexes(i,4+5) > STpm + 4*STps % ST peak
        abnormalities = [abnormalities complexes(i,3)];
    end
%     if data(complexes(i+1,3),1)-data(complexes(i,3),1) > RRm + 6*RRs % Missed beat (no R wave)
%         abnormalities = [abnormalities complexes(i,3)];
%     end
    if data(complexes(:,4),1)-data(complexes(:,2),1) > .1 % Premature ventricular contraction (wide QRS)
        abnormalities = [abnormalities complexes(i,3)];
    end
    if data(complexes(i,3),1)-data(complexes(i,1),1) > PRm + 4*PRs % Missed beat (no R wave)
        abnormalities = [abnormalities complexes(i,3)];
    end
end
abnormalitiesP = filterData(abnormalities);
plot(data(:,1),filterData,'b');
plot(data(complexes(:,1),1),complexes(:,6),'m*');
plot(data(complexes(:,2),1),complexes(:,7),'g*');
plot(data(complexes(:,3),1),complexes(:,8),'k*');
plot(data(complexes(:,4),1),complexes(:,9),'c*');
plot(data(complexes(:,5),1),complexes(:,10),'y*');
plot(data(abnormalities,1),abnormalitiesP,'ro');
%subplot(2,1,2);
%plot(data(1:end-1,1),diff(filterData));
%{
OLD CODE:

% PRindices = 1:size(complexes,1);
% PRindices(find(complexes(:,1) == 0)) = [];
% STindices = 1:size(complexes,1);
% STindices(find(complexes(:,5) == 0)) = [];
    if i == 1
        forwardEstimate = round(mean([Rlcs_global(i+1) Rlcs_global(i)]));
        if Rlcs_global(i)-(forwardEstimate-Rlcs_global(i)) < 1
            backwardEstimate = 1;
        else
            backwardEstimate = forwardEstimate - Rlcs_global(i);
        end
    elseif i == length(Rlcs_global)
        backwardEstimate = round(mean([Rlcs_global(i-1) Rlcs_global(i)]));
        if Rlcs_global(i)+(Rlcs_global(i)-backwardEstimate) > size(data,1)
            forwardEstimate = size(data,1);
        else
            forwardEstimate = Rlcs_global(i)+(Rlcs_global(i)-backwardEstimate);
        end
    else
        forwardEstimate = round(mean([Rlcs_global(i+1) Rlcs_global(i)]));
        backwardEstimate = round(mean([Rlcs_global(i-1) Rlcs_global(i)]));
    end
% filterData = filterData / max(filterData);
%filterData = smooth(filterData,5);
% ECG_data = ECG_data/max(ECG_data);
% data(:,2) = ECG_data;
% filterData = filterData/max(filterData);

% dt = 0.0002; %Seconds
% samples = length(data(:,2));
% sampleF = 1 / dt;
% cuttoff = 45;
% Wn = cuttoff / (sampleF / 2);
% [B,A] = butter(2, Wn, 'low'); % 4th order butterworth lowpass filter
% filterData = filter(B,A,filterData);

% What about this way of finding peaks?
% filterData_neg = filterData;
% filterData_neg(filterData_neg > 0) = 0; % showing peaks less than 0
% filterData_neg = filterData_neg.^2;
% filterData_pos = filterData;
% filterData_pos(filterData_pos < 0) = 0; % showing peaks greater than 0
% filterData_pos = filterData_pos.^2;
% for j = 1:length(Rlcs_global)
%     temp = 750;
%     if Rlcs_global(j)-temp <= 0
%         temp = Rlcs_global(j)-1;
%     end
%     [Pp, Pl] = findpeaks(filterData_pos(Rlcs_global(j)-temp:Rlcs_global(j)), 'SortStr', 'descend');
%     if ~isempty(Pl)
%         complexes(j,1) = Pl(1)+Rlcs_global(j)-temp;
%         complexes(j,1+5) = filterData(complexes(j,1));
%     end
%     
%     temp = 500;
%     if Rlcs_global(j)-temp <= 0
%         temp = Rlcs_global(j)-1;
%     end
%     [Qp, Ql] = findpeaks(filterData_neg(Rlcs_global(j)-temp:Rlcs_global(j)), 'SortStr', 'descend');
%     if ~isempty(Ql)
%         complexes(j,2) = Ql(1)+Rlcs_global(j)-temp;
%         complexes(j,2+5) = filterData(complexes(j,2));
%     end
%     
%     temp = 500;
%     if Rlcs_global(j)+temp > length(filterData)
%         temp = length(filterData)-Rlcs_global(j)-1;
%     end
%     [Sp, Sl] = findpeaks(filterData_neg(Rlcs_global(j):Rlcs_global(j)+temp), 'SortStr', 'descend');
%     if ~isempty(Sl)
%         complexes(j,4) = Sl(1)+Rlcs_global(j);
%         complexes(j,4+5) = filterData(complexes(j,4));
%     end
%     
%     temp = 1500;
%     if Rlcs_global(j)+temp > length(filterData)
%         temp = length(filterData)-Rlcs_global(j)-1;
%     end
%     [Tp, Tl] = findpeaks(filterData_pos(Rlcs_global(j):Rlcs_global(j)+temp), 'SortStr', 'descend');
%     if ~isempty(Tl)
%         complexes(j,5) = Tl(1)+Rlcs_global(j);
%         complexes(j,5+5) = filterData(complexes(j,5));
%     end
% end

%% Reliant on smoothed data
% filterData_dec = filterData;
% Rlcs_rem = [];
% Qpks = [];
% Qlcs = [];
% Spks = [];
% Slcs = [];
% Ppks = [];
% Plcs = [];
% Tpks = [];
% Tlcs = [];
% for j = 1:length(Rlcs_global)
%     complexes(j,3) = Rlcs_global(j);
%     complexes(j,8) = Rpks(j);
%     k_left = 1;
%     left = filterData_dec(Rlcs_global(j)-k_left);
%     left_hold = filterData_dec(Rlcs_global(j));
%     while left < left_hold
%         k_left = k_left + 1;
%         left_hold = left;
%         if Rlcs_global(j)-k_left == 0
%             break;
%         end
%         left = filterData_dec(Rlcs_global(j)-k_left);
%     end
%     Qpks = [Qpks left_hold];
%     Qlcs = [Qlcs Rlcs_global(j)-k_left+1];
%     complexes(j,2) = Rlcs_global(j)-k_left+1;
%     complexes(j,7) = left_hold;
%     k_right = 1;
%     right = filterData_dec(Rlcs_global(j)+k_right);
%     right_hold = filterData_dec(Rlcs_global(j));
%     while right < right_hold
%         k_right = k_right + 1;
%         right_hold = right;
%         if Rlcs_global(j)+k_right == length(data(:,2))
%             break;
%         end
%         right = filterData_dec(Rlcs_global(j)+k_right);
%     end
%     Spks = [Spks right_hold];
%     Slcs = [Slcs Rlcs_global(j)+k_right-1];
%     complexes(j,4) = Rlcs_global(j)+k_right-1;
%     complexes(j,9) = right_hold;
%     while left > left_hold
%         k_left = k_left + 1;
%         left_hold = left;
%         if Rlcs_global(j)-k_left == 0
%             break;
%         end
%         left = filterData_dec(Rlcs_global(j)-k_left);
%     end
%     Ppks = [Ppks left_hold];
%     Plcs = [Plcs Rlcs_global(j)-k_left+1];
%     complexes(j,1) = Rlcs_global(j)-k_left+1;
%     complexes(j,6) = left_hold;
%     while right_hold < complexes(j,6) && complexes(j,1) ~= 1
%         while right > right_hold
%             k_right = k_right + 1;
%             right_hold = right;
%             if Rlcs_global(j)+k_right == length(data(:,2))
%                 break;
%             end
%             right = filterData_dec(Rlcs_global(j)+k_right);
%         end
%         if Rlcs_global(j)+k_right == length(data(:,2))
%             break;
%         end
%         k_right = k_right + 1;
%         right_hold = right;
%         right = filterData_dec(Rlcs_global(j)+k_right);
%     end
%     Tpks = [Tpks right_hold];
%     Tlcs = [Tlcs Rlcs_global(j)+k_right-1];
%     complexes(j,5) = Rlcs_global(j)+k_right-1;
%     complexes(j,10) = right_hold;
%     Rlcs_rem = [Rlcs_rem Rlcs_global(j)-k_left:Rlcs_global(j)+k_right];
% end

% Rlcs_rem(Rlcs_rem <= 1) = [];
% Rlcs_rem(Rlcs_rem > length(data(:,1))) = [];
% filterData_dec(Rlcs_rem) = 0;
% [pks, lcs] = findpeaks(filterData_dec, 'MinPeakDistance', separationEstimate*.85, 'SortStr', 'descend');
% Tlcs_local = find(pks >= pks(1)*.8);
% Tlcs_global = lcs(Tlcs_local);
% Tpks = filterData(Tlcs_global);
% plot(data(Tlcs_global,1),Tpks,'g*');
% 
% Tlcs_rem = [];
% for j = 1:length(Tlcs_global)
%     Tlcs_rem = [Tlcs_rem Tlcs_global(j)-1000:Tlcs_global(j)+1000];
% end
% Tlcs_rem(Tlcs_rem <= 1) = [];
% Tlcs_rem(Tlcs_rem > length(data(:,1))) = [];
% filterData_dec(Tlcs_rem) = 0;
% [pks, lcs] = findpeaks(filterData_dec, 'MinPeakDistance', separationEstimate*.85, 'SortStr', 'descend');
% Plcs_local = find(pks >= pks(1)-.15);
% Plcs_global = lcs(Plcs_local);
% Tpks = filterData(Plcs_global);

%}