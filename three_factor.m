%% ============ 烃源岩厚度、TOC、Ro 单因素评价 ============
% 每个因素分别输出插值图、赋分图、概率/CDF/等级占比图。
clear; clc; close all;

dx = 1000; dy = 1000;  % 网格间距（米）

factors(1).name = '厚度';
factors(1).unit = 'm';
factors(1).filename = 're_厚度.txt';
factors(1).edges = [0 200 500 1000];
factors(1).scores = [0.25 0.50 0.75 1.00];

factors(2).name = 'TOC';
factors(2).unit = '%';
factors(2).filename = 're_TOC.txt';
factors(2).edges = [0 1.0 1.5 2.0 4.0];
factors(2).scores = [0.25 0.25 0.50 0.75 1.00];

factors(3).name = 'Ro';
factors(3).unit = '%';
factors(3).filename = 're_Ro.txt';
factors(3).edges = [0 0.5 1.2 2.0 3.0];
factors(3).scores = [0.25 1.00 1.00 0.75 0.50];

for k = 1:numel(factors)
    evaluate_factor(factors(k), dx, dy);
end
fprintf('\n全部单因素评价完成。\n');

%% ================= 局部函数 =================
function evaluate_factor(cfg, dx, dy)
fprintf('\n========== %s 单因素评价 ==========\n', cfg.name);
[X, Y, Z] = read_contour_file(cfg.filename);

keep = Z ~= 0;
X = X(keep); Y = Y(keep); Z = Z(keep);
[~, ia] = unique([X Y], 'rows', 'stable');
X = X(ia); Y = Y(ia); Z = Z(ia);
if isempty(Z), error('%s 没有可用的非零数据。', cfg.filename); end

fprintf('读取散点个数 : %d\n', numel(Z));
fprintf('%s范围       : %.3f ~ %.3f %s\n', cfg.name, min(Z), max(Z), cfg.unit);

xmin = min(X); xmax = max(X); ymin = min(Y); ymax = max(Y);
xg = xmin:dx:xmax; yg = ymin:dy:ymax;
[Xg, Yg] = meshgrid(xg, yg);
mx = mean(X); my = mean(Y);
F = scatteredInterpolant(X-mx, Y-my, Z, 'natural', 'none');
Zg = F(Xg-mx, Yg-my);

x_km = xg/1000;
y_km = yg/1000;
[Xg_km, Yg_km] = meshgrid(x_km, y_km);

valid = ~isnan(Zg(:));
value = Zg(valid); Xv = Xg(valid); Yv = Yg(valid);
score = interp1(cfg.edges, cfg.scores, value, 'linear', 'extrap');
score = max(0.25, min(1.00, score));
grade = to_grade(score);
fprintf('赋分范围     : %.3f ~ %.3f\n', min(score), max(score));

figure('Name',[cfg.name '插值图'],'Color','w');
contourf(Xg_km,Yg_km,Zg,30,'LineStyle','none');
colorbar; colormap(gca,parula);
axis tight;              % 贴紧数据范围
pbaspect([1 1 1]);       % 强制正方形绘图区（Y 轴相应拉长，X/Y 单位长度不再相等）
set(gcf,'Units','pixels','Position',[60 60 680 640]);  % 正方形窗口
xlabel('X / km'); ylabel('Y / km');
title(sprintf('%s插值图 (%s)',cfg.name,cfg.unit));

grade_map = nan(size(Zg)); grade_map(valid) = grade;
figure('Name',[cfg.name '赋分图'],'Color','w');
cmap = [0.13 0.55 0.13; 0.56 0.93 0.56; 0.95 0.87 0.35; 0.85 0.20 0.20];
contourf(Xg_km,Yg_km,grade_map,[0.5 1.5 2.5 3.5 4.5],'LineStyle','none');
colormap(gca,cmap); caxis([0.5 4.5]);
cb = colorbar; set(cb,'Ticks',1:4,'TickLabels',{'优','较好','一般','差'});
axis tight;              % 贴紧数据范围
pbaspect([1 1 1]);       % 强制正方形绘图区（Y 轴相应拉长，X/Y 单位长度不再相等）
set(gcf,'Units','pixels','Position',[60 60 680 640]);  % 正方形窗口
xlabel('X / km'); ylabel('Y / km');
title([cfg.name '赋分图（等级）']);

figure('Name',[cfg.name '概率统计图'],'Color','w');
subplot(1,2,1);
yyaxis left;
h_hist = histogram(score,30,'Normalization','probability', ...
    'FaceColor',[0.4 0.6 0.9],'EdgeColor','none');
hold on; yl = ylim;
h_mean = plot([mean(score) mean(score)],yl,'r--','LineWidth',1.5);
h_median = plot([median(score) median(score)],yl,'g--','LineWidth',1.5);
ylabel('概率');
yyaxis right;
score_sorted = sort(score);
cum_prob = (1:numel(score_sorted))'/numel(score_sorted);
h_cdf = plot(score_sorted,cum_prob,'b-','LineWidth',1.8);
ylabel('累计概率'); ylim([0 1]); xlabel('得分'); grid on; hold off;
title([cfg.name '得分概率分布与累计概率曲线']);
legend([h_hist h_mean h_median h_cdf], ...
    {'得分概率','均值','中位数','累计概率'},'Location','best');

subplot(1,2,2);
gc = histcounts(grade,0.5:1:4.5);
bar(1:4,gc/sum(gc),'FaceColor',[0.2 0.6 0.3]);
set(gca,'XTick',1:4,'XTickLabel',{'优','较好','一般','差'});
ylabel('占比'); ylim([0 1]); grid on; title([cfg.name '等级占比']);

fprintf('\n=== %s 得分统计（%d 个样本） ===\n',cfg.name,numel(score));
fprintf('  均值 = %.3f   中位数 = %.3f   标准差 = %.3f\n', ...
    mean(score),median(score),std(score));
fprintf('  最小 = %.3f   最大 = %.3f\n',min(score),max(score));
fprintf('  等级占比: 优 %.1f%%   较好 %.1f%%   一般 %.1f%%   差 %.1f%%\n', ...
    100*sum(grade==1)/numel(grade),100*sum(grade==2)/numel(grade), ...
    100*sum(grade==3)/numel(grade),100*sum(grade==4)/numel(grade));

%109-144导出结果
%T_out = table(Xv,Yv,value,score,grade, ...
%    'VariableNames',{'X','Y','原始值','赋分','等级'});
%outfile = [cfg.name '单因素评价结果.xlsx'];
%writetable(T_out,outfile);
%fprintf('已导出 %s（%d 个节点）\n',outfile,height(T_out));
end

function [X,Y,Z] = read_contour_file(filename)
fid = fopen(filename,'r','n','UTF-8');
if fid < 0, error('无法打开文件: %s',filename); end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fgetl(fid);  % 跳过 GmLine v3.0(Contour)

% 新格式：每个数据块的第一行为“点数  Z值”，随后是指定数量的
% “X  Y  -1”坐标行。第三列 -1 仅为占位符，不参与计算。
% 若块头 Z 值为空，则沿用上一块的 Z 值。
X = zeros(0,1); Y = zeros(0,1); Z = zeros(0,1);
currentZ = NaN;
while ~feof(fid)
    headerLine = fgetl(fid);
    if ~ischar(headerLine) || isempty(strtrim(headerLine)), continue; end
    header = strsplit(headerLine,'\t','CollapseDelimiters',false);

    pointCount = str2double(strtrim(header{1}));
    if isnan(pointCount) || pointCount < 0 || pointCount ~= floor(pointCount)
        warning('跳过无法识别的数据块头: %s',headerLine);
        continue;
    end

    if numel(header) >= 2 && ~isempty(strtrim(header{2}))
        newZ = str2double(strtrim(header{2}));
        if ~isnan(newZ), currentZ = newZ; end
    end

    for p = 1:pointCount
        if feof(fid)
            warning('%s 的最后一个数据块不足 %d 个点。',filename,pointCount);
            break;
        end
        coordLine = fgetl(fid);
        coord = strsplit(coordLine,'\t','CollapseDelimiters',false);
        if numel(coord) < 2, continue; end
        xv = str2double(strtrim(coord{1}));
        yv = str2double(strtrim(coord{2}));
        if ~isnan(xv) && ~isnan(yv) && ~isnan(currentZ)
            X(end+1,1)=xv;
            Y(end+1,1)=yv;
            Z(end+1,1)=currentZ;
        end
    end
end
end

function grade = to_grade(score)
grade = 3*ones(size(score));
grade(score<0.40)=4;
grade(score>=0.65)=2;
grade(score>=0.85)=1;
end
