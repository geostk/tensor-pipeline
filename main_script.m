% tensor main script that shows all the steps in the workflow
clearvars
% 1) create a tensor from your fMRI data with dimensions time x brain
% regions/channels x subjects; we use correlation because that's fastest
%data = load('ex_data');
data = load_petradata;
[T,N,S] = size(data);
w = 60;
method = 'corr';

% create tensors, decompose them and cluster resulting features for both
% real and surrogate data
for surr=[false,true]
    if ~surr
        tens = make_tensor(data,w,method);
        fname = ['features_',method];
    else
        data_surr = zeros(size(data));
        for s=1:S
            % create surrogates that have no long-term FC
            data_surr(:,:,s) = surrogates_cov(data(:,:,s)',0)';
            tens = make_tensor(data_surr,w,method);
            fname = ['features_',method,'_surr'];
        end
    end
    W = size(tens,3);
    
    % 2) decompose all tensors and store resulting features
    % use different numbers of features and thresholds to compare later
    tens = tens(:,:,:,1:10);
    F = 3:5;
    Thrs = [75,90,99];
    nonneg = 0; % method = correlation --> not non-negative
    % save features, lambdas ("eigenvalues"), and errors
    spfeats = cell(length(F),length(Thrs));
    tfeats = cell(length(F),length(Thrs));
    lambdas = cell(length(F),length(Thrs));
    err = cell(length(F),length(Thrs)); % not workind yet
    % loop over number of features and thresholds
    f_count = 0;
    for f=F
        f_count = f_count+1;
        thr_count = 0;
        for thr=Thrs
            thr_count = thr_count+1;
            [spfeats{f_count,thr_count},tfeats{f_count,thr_count},lambdas{f_count,thr_count},err{f_count,thr_count}] = decomp_tens(tens,f,thr,nonneg);
        end
    end
    
    % 3) use K-means clustering to determine best f and thr
    maxntemplates = 5;
    [silh_vals,clust_memb_IDs] = cluster_spfeats(spfeats,maxntemplates);
    % store the results
    save(fname,'spfeats','tfeats','lambdas','err','F','Thrs',...
        'maxntemplates','nonneg','silh_vals','clust_memb_IDs')
end

% 4) find best F, threshold, and number of clusters (by comparing silhouette
% values from real and surrogate data)
[templates,bestF,bestK,bestThr,corr_feats] = make_templates(['features_',method]);

%% plot
real = load(['features_',method],'silh_vals','Thrs');
surr = load(['features_',method,'_surr'],'silh_vals');
% silhouette values
silh_vals_diff = real.silh_vals-surr.silh_vals;
imagesc(silh_vals_diff(:,:,real.Thrs==bestThr))
colormap(esa)
set(gca,'XTick',1:length(F(1):maxntemplates))
set(gca,'XTickLabel',F(1):maxntemplates)
xlabel('# clusters')
set(gca,'YTick',1:length(F))
set(gca,'YTickLabel',F)
ylabel('# features')
h = colorbar;
ylabel(h,'silh val diff');

