%% GNSS Pre-Frontends: Data Download and Prepare

% 确认下erp文件用哪个，brdm文件也需要下载,atx文件，ocnload文件

clc;close all;clearvars

%% Settings
obsSource  = 0; % 0 - website; 1 - local
ac         = 1; % Index for different ACs
obsWeb{1}  = 'ftp://igs.gnsswhu.cn/pub/gps/data/daily/';
ephPath{1} = 'ftp://igs.gnsswhu.cn/pub/gps/data/daily/';
igsWeb{1}  = 'ftp://igs.gnsswhu.cn/pub/whu/phasebias/';
orbPath{1} = '/orbit/';
erpPath{1} = '/orbit/';
clkPath{1} = '/clock/';
osbPath{1} = '/bias/';
snxPath{1} = 'ftp://igs.gnsswhu.cn/pub/gps/products/';%igs22P2204.snx.Z

obsType{1} = '/*.o'; obsType{2} = '/*.rnx'; obsType{3} = '/*.crx'; obsType{4} = '/*.crx.gz';


%% Set Path and Time

[obs_path] = uigetdir('Please select the data path');
obsTime = input('Please input [Year,Month,Day] or [Year,1,DOY], e.g.,[2022,1,1] \n');
dateNum = datenum(obsTime); dateVec = datevec(dateNum); %[year, month,day,0,0,0];
year = dateVec(1); doy = dateNum - datenum([year,1,1]) + 1;

%% Prepare Observation File

if obsSource == 0
    % Get observation from Internet
    stationList = input('Please input station name, e.g.,[''ALIC'';''PTGG''],\n');
    nStation = size(stationList,1);
    for i = 1 : nStation
        str_obsfile = [obsWeb{ac},num2str(year),'/',num2str(doy,'%03d'),'/',...
            num2str(year-2000,'%02d'),'d','/',stationList(i,:),'*.crx.gz'];
        [status,result] = system(['wget ',str_obsfile],'-echo');
        if status == 0
            movefile([stationList(i,:),'*.crx.gz'],obs_path);           
        end
    end
end        

% Find observation file
for i = 1 : 4
    obs_file = dir([obs_path,obsType{i}]);
    if ~isempty(obs_file)
        obs_file = [obs_file.folder,'\',obs_file.name];
        disp(['An observation file is found: ',obs_file]);
        break;
    end
    if i == 4, disp('Error: unable to find an observation file!'); end
end

[~,obsFileName,obsFileType] = fileparts(obs_file);
switch i
    case 1
        obsFileName = [lower(obsFileName(1:4)),num2str(doy,'%03d'),'0.',num2str(year-2000,'%02d'),'o'];
        new_obsfile = [obs_path,'\',obsFileName];
        movefile(obs_file,new_obsfile);
    case 2
        obsFileName = [lower(obsFileName(1:4)),num2str(doy,'%03d'),'0.',num2str(year-2000,'%02d'),'o'];
        new_obsfile = [obs_path,'\',obsFileName];
        movefile(obs_file,new_obsfile);
    case 3
        str_crx2rnx = ['crx2rnx ',obs_file];
        system(str_crx2rnx);
        rnx_file = [obs_path,'\',obsFileName,'.rnx'];
        obsFileName = [lower(obsFileName(1:4)),num2str(doy,'%03d'),'0.',num2str(year-2000,'%02d'),'o'];
        new_obsfile = [obs_path,'\',obsFileName];
        movefile(rnx_file,new_obsfile);
    case 4
        str_gzip = ['gzip -d ', obs_file];
        system(str_gzip);
        obs_file = obs_file(1:end-3);
        str_crx2rnx = ['crx2rnx ',obs_file];
        system(str_crx2rnx);
        rnx_file = [obs_path,'\',obsFileName(1:end-3),'rnx'];
        obsFileName = [lower(obsFileName(1:4)),num2str(doy,'%03d'),'0.',num2str(year-2000,'%02d'),'o'];
        new_obsfile = [obs_path,'\',obsFileName];
        movefile(rnx_file,new_obsfile);
end

%% Broadcast ephemeris

str_ephfile = [obsWeb{ac},num2str(year),'/',num2str(doy,'%03d'),'/',...
               num2str(year-2000,'%02d'),'p','/','BRDM','*.rnx.gz'];
[status,result] = system(['wget ',str_ephfile],'-echo');
if status == 0
    movefile(['BRDM','*.rnx.gz'],obs_path);           
end

% gzip
str_gzip = ['gzip -d ', obs_path,'\BRDM','*.rnx.gz'];
system(str_gzip);

%rename
eph_file = dir([obs_path,'\BRDM*.rnx']); 
ephFileName = eph_file.name;
ephFileName = [lower(ephFileName(1:4)),num2str(doy,'%03d'),'0.',num2str(year-2000,'%02d'),'p'];
eph_file = [eph_file.folder,'\',eph_file.name]; %original name
new_ephfile = [obs_path,'\',ephFileName]; % short name
movefile(eph_file,new_ephfile);

%% Products

[gps_week, gps_sow, gps_dow] = date2gps(dateVec);
switch ac
    case 1
        orb_file    = ['WUM0MGXRAP_',num2str(year), num2str(doy,'%03d'),'0000_01D_01M_ORB.SP3.gz'];
        str_orbfile = [igsWeb{ac},num2str(year),orbPath{ac},orb_file];
        str_getOrb  = ['wget ',str_orbfile];        
        [status,result] = system(str_getOrb,'-echo');
        system(['gzip -d ',orb_file]); 
        orb_file = orb_file(1:end-3);
        orb_file_s  = [lower(orb_file(1:3)),num2str(gps_week),num2str(gps_dow),'.sp3'];
        if status == 0
            movefile(orb_file,[obs_path,'\',orb_file_s]);
            disp(['successfully download: ',orb_file_s]);
        end
        
        clk_file    = ['WUM0MGXRAP_',num2str(year),num2str(doy,'%03d'),'0000_01D_30S_CLK.CLK.gz'];
        str_clkfile = [igsWeb{ac},num2str(year),clkPath{ac},clk_file];
        str_getClk  = ['wget ',str_clkfile];
        [status,result] = system(str_getClk,'-echo');
        system(['gzip -d ',clk_file]); 
        clk_file = clk_file(1:end-3);
        clk_file_s  = [lower(clk_file(1:3)),num2str(gps_week),num2str(gps_dow),'.clk'];
        if status == 0
            movefile(clk_file,[obs_path,'\',clk_file_s]);
            disp(['successfully download: ',clk_file_s]);
        end
        
        erp_file    = ['WUM0MGXRAP_',num2str(year), num2str(doy,'%03d'),'0000_01D_01D_ERP.ERP.gz'];
        str_erpfile = [igsWeb{ac},num2str(year),orbPath{ac},erp_file];
        str_getErp  = ['wget ',str_erpfile];        
        [status,result] = system(str_getErp,'-echo');
        if status == 0
            % gzip
            system(['gzip -d ',erp_file]);
            % rename
            erp_file = erp_file(1:end-3);
            erp_file_s  = [lower(erp_file(1:3)),num2str(gps_week),num2str(gps_dow),'.erp'];
            movefile(erp_file,[obs_path,'\',erp_file_s]);
            disp(['successfully download: ',erp_file_s]);
        end
        
end

%% SNX file
snx_file    = ['igs*',num2str(gps_week),'.snx.Z'];
str_snxfile = [snxPath{ac},num2str(gps_week),'/',snx_file];
str_getSnx  = ['wget ',str_snxfile];
[status,result] = system(str_getSnx,'-echo');
if status == 0
    movefile(snx_file,obs_path);
    snx_file = dir([obs_path,'\',snx_file]);
    % gzip
    str_gzip = ['gzip -d ', obs_path,'\',snx_file.name];
    system(str_gzip);
    % rename
    snx_file   = snx_file.name(1:end-2);
    snx_file_s = ['igs',num2str(gps_week),'.snx'];
    movefile([obs_path,'\',snx_file],[obs_path,'\',snx_file_s]);
end
