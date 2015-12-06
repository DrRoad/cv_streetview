imdir = 'C:/Users/lezhi/Dropbox/___6869/_streetview_valid/%s'; % change this
netdir = 'C:\Users\lezhi\Dropbox\cv project\city-alexnet-simplenn\net-epoch-31.mat';
imdbdir = 'C:\Users\lezhi\Dropbox\cv project\city-alexnet-simplenn\imdb.mat';

%% evaluate
% initialize MatConvNet
run(fullfile(fileparts(mfilename('fullpath')), ...
  '..', 'matlab', 'vl_setupnn.m')) ;

% load the pre-trained CNN
trainedstuff = load(netdir); % change this
net = trainedstuff.net;
net.layers{1,end}.type = 'softmax';
net.layers{1,end}.name = 'prob';

% loop through test images and estimate results
imdb = load(imdbdir); % change this
names = imdb.images.name(imdb.images.set==3);
labels = imdb.images.label(imdb.images.set==3);

% variables for storing test statistics
confusion = zeros(10); % confusion matrix
predLabels = zeros(1,length(names)); 
bestScores = zeros(1,length(names));
ownScores = zeros(1,length(names));
for i = 1:length(names)
im = imread(sprintf(imdir,names{i})); % change this
im_ = single(im) ; % note: 0-255 range
im_ = im_(1:256,:,:);
im_ = imresize(im_, net.normalization.imageSize(1:2));
for j = 1:3
  im_(:,:,j)=im_(:,:,j)-net.normalization.averageImage(j);
end

% run the CNN
res = vl_simplenn(net, im_) ;

% show the classification result
scores = squeeze(gather(res(end).x)) ;
[bestScore, best] = max(scores) ;
[sortedscores,index] = sort(scores,'descend');
ownscore = scores(labels(i)); 

% remember the prodicted category and their corresponding scores
predLabels(i) = best; 
bestScores(i) = bestScore;
ownScores(i) = ownscore;

% if categorized wrongly, 
% add the score difference between the top score and the score for the gound truth category
% to the corresponding cell in confusion matix
if best ~= labels(i) 
  score_diff = bestScore - ownscore;
  confusion(best,labels(i)) = confusion(best,labels(i)) + score_diff; % row for target label, column for ground truth label
end

i % print process
end

%% save stats
% divide confusion matrix by the total number in each category, to get
% false classification rates
tot = zeros(1,10);
for i = 1:10
  tot (i) = length(names(labels==i)); 
end
confusion_rate = confusion*100 ./ double(repmat(tot,10,1));
false_rate = sum(confusion_rate);

coords = zeros(length(names),2);
for i = 1:length(names)
coord = strsplit(names{i},{'/',',','_'},'CollapseDelimiters',true);
coords(i,:) = [str2double(coord{2}),str2double(coord{3})];
end

save('test_stats.mat','names','ownScores','labels','bestScores','predLabels','confusion','confusion_rate','false_rate')
csvwrite('test_stats_map.csv',[coords,labels',ownScores',predLabels',bestScores']);

%% visualization-top10
addpath('lib');
city_names = imdb.classes.name;
figure
ha = tight_subplot(5,10,[0.018,0.001]);%,[.1 .01],[.01 .01]);
for i = 6:10
b_scores_sub = bestScores(labels==i);
o_scores_sub = ownScores(labels==i);
names_sub = names(labels==i);
p_labels_sub = predLabels(labels==i);
[~,index] = sort(o_scores_sub,'ascend'); % highest possibilities in each category
for j = 1:10 
  axes(ha(10*(i-6)+j)); 
  im = imread(sprintf(imdir,names_sub{index(j)}));
  imagesc(im); 
  th = title(sprintf('certainty: %0.1f, pred: %d',o_scores_sub(index(j)),p_labels_sub(index(j))));
  set(th,'Fontname','Timesnewroman');
  set(th,'Fontsize',9);
  set(th,'Position',[128,279,0]);
end
set(ha(1:50),'XTickLabel',''); set(ha,'YTickLabel','');
end

%% visualization-confusion
% http://stackoverflow.com/questions/3942892/how-do-i-visualize-a-matrix-with-colors-and-values-displayed
mat = confusion_rate_c2;           
imagesc(mat);            
colormap(flipud(gray));  %# Change the colormap to gray (so higher values are
                         %#   black and lower values are white)

textStrings = num2str(mat(:),'%0.2f');  %# Create strings from the matrix values
textStrings = strtrim(cellstr(textStrings));  %# Remove any space padding
[x,y] = meshgrid(1:10);   %# Create x and y coordinates for the strings
hStrings = text(x(:),y(:),textStrings(:),...      %# Plot the strings
                'HorizontalAlignment','center');
midValue = mean(get(gca,'CLim'));  %# Get the middle value of the color range
textColors = repmat(mat(:) > midValue,1,3);  %# Choose white or black for the
                                             %#   text color of the strings so
                                             %#   they can be easily seen over
                                             %#   the background color
set(hStrings,{'Color'},num2cell(textColors,2));  %# Change the text colors

set(gca,'XTick',1:10,...                         %# Change the axes tick marks
        'XTickLabel',imdb.classes.name,...  %#   and tick labels
        'YTick',1:10,...
        'YTickLabel',imdb.classes.name,...
        'TickLength',[0 0]);
    
%% evaluate - histogram swapping
% initialize MatConvNet
run(fullfile(fileparts(mfilename('fullpath')), ...
  '..', 'matlab', 'vl_setupnn.m')) ;

% load the pre-trained CNN
trainedstuff = load(netdir); % change this
net = trainedstuff.net;
net.layers{1,end}.type = 'softmax';
net.layers{1,end}.name = 'prob';

% loop through test images and estimate results
imdb = load(imdbdir); 
names = imdb.images.name(imdb.images.set==3);
labels = imdb.images.label(imdb.images.set==3);
names_cat = {};
for i = 1:10
names_cat{end+1} = names(labels==i);
end

% variables for storing test statistics
confusion_c = zeros(10); % confusion matrix

for k = [1,9] % swap singapore and boston
for i = 1:length(names_cat{k})
  im = imread(sprintf(imdir,names_cat{k}{i})); 
  if (k==1), k2 = 9; else k2 = 1; end;
  i2 = randi(length(names_cat{k2}));
  imcolor = imread(sprintf(imdir,names_cat{k2}{i2}));
  im = imhistmatch(im, imcolor);
  im_ = single(im) ; % note: 0-255 range
  im_ = im_(1:256,:,:);
  im_ = imresize(im_, net.normalization.imageSize(1:2));
  for j = 1:3
    im_(:,:,j)=im_(:,:,j)-net.normalization.averageImage(j);
  end

  % run the CNN
  res = vl_simplenn(net, im_) ;

% show the classification result
  scores = squeeze(gather(res(end).x)) ;
  [bestScore, best] = max(scores) ;
  [sortedscores,index] = sort(scores,'descend');
  ownscore = scores(k); 
 
  % if categorized wrongly, 
  % add the score difference between the top score and the score for the gound truth category
  % to the corresponding cell in confusion matix
  if best ~= k 
    score_diff = bestScore - ownscore;
    confusion_c(best,k) = confusion_c(best,k) + score_diff; % row for target label, column for ground truth label
  end

  [k,i] % print process
end
end

% divide confusion matrix by the total number in each category, to get
% false classification rates
tot = zeros(1,10);
for i = 1:10
  tot (i) = length(names(labels==i)); 
end
confusion_rate_c = confusion_c*100 ./ double(repmat(tot,10,1));
false_rate_c = sum(confusion_rate_c);

confusion_rate_c2 = confusion_rate;
confusion_rate_c2(:,[1,9]) = confusion_rate_c(:,[1,9]);

%% four histogram change images
im1 = imread(sprintf(imdir,'Boston/42.347651,-71.063051_0.jpg'));
im2 = imread(sprintf(imdir,'Singapore/1.273867,103.842282_6.jpg'));
im1s = imhistmatch(im1, im2);
im2s = imhistmatch(im2, im1);
figure 
subplot(2,2,1), imshow(im1), title('Boston');
subplot(2,2,2), imshow(im2), title('Singapore');
subplot(2,2,3), imshow(im1s), title('Boston with Singapore color');
subplot(2,2,4), imshow(im2s); title('Singapore with Boston color');
