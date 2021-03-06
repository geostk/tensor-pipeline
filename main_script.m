% tensor main script that shows all the steps in the workflow
% all code written by Katharina Glomb except:
% simulations: Adrian Ponce
% surrogates: Rikkert Hindriks
% decomposition algorithms: Anh-Huy Phan, Jingu Kim

clearvars
% 1) create a tensor from your fMRI data, or simulate data using sim_script
% load(...)
data = rand(661,66,2);
[T,N,S] = size(data);
w = 60; % window width in frames
method = 'ph';
switch method
    case {'ph','abs','MI'}
        nonneg = 1;
    case 'corr'
        nonneg = 0;
end

% create tensors, decompose them and cluster resulting features for both
% real and surrogate data
for surr=[false,true]
    if ~surr
        fprintf('Creating tensors, using dFC measure %s, for original data...\n',method)
        tens = make_tensor(data,w,method);
        fname = ['features_',method];
    else
        fprintf('Creating tensors, using dFC measure %s, for surrogate data...\n',method)
        data_surr = zeros(size(data));
        for s=1:S
            % create surrogates that have no long-term FC
            data_surr(:,:,s) = surrogates_cov(data(:,:,s)',0)';            
        end
        tens = make_tensor(data_surr,w,method);
        fname = ['features_',method,'_surr'];
    end
    W = size(tens,3);
    
    % 2) decompose all tensors and store resulting features
    % use different numbers of features and thresholds to compare later
    fprintf('Decomposing tensors...\n')
    F = 3:5;%9;
    Thrs = [0,75,98];%[0,75,80,90:99];
    % save features, lambdas ("eigenvalues"), and errors
    spfeats = cell(length(F),length(Thrs));
    tfeats = cell(length(F),length(Thrs));
    lambdas = cell(length(F),length(Thrs));
    err = cell(length(F),length(Thrs)); % not tested yet
    % loop over number of features and thresholds
    f_count = 0;
    for f=F
        fprintf('F = %i\n',f)
        f_count = f_count+1;
        thr_count = 0;
        for thr=Thrs
            fprintf('Threshold = %i\n',thr)
            thr_count = thr_count+1;
            [spfeats{f_count,thr_count},tfeats{f_count,thr_count},lambdas{f_count,thr_count},err{f_count,thr_count}] = decomp_tens(tens,f,thr);
        end
    end
    
    % 3) use K-means clustering to determine best f and thr
    maxK = F(end)+1;
    fprintf('Clustering...\n')
    [silh_vals,clust_memb_IDs] = cluster_spfeats(spfeats,maxK);
    % store the results
    save(fname,'spfeats','tfeats','lambdas','err','F','Thrs',...
        'maxK','nonneg','silh_vals','clust_memb_IDs')
end

% 4) find best F, threshold, and number of clusters (by comparing silhouette
% values from real and surrogate data)
fprintf('Choosing best parameter setting and creating templates...\n')
real = load(['features_',method]);
surr = load(['features_',method,'_surr']);

[templates,bestF,bestK,bestThr,corr_feats] = make_templates(real.spfeats,real.clust_memb_IDs,real.silh_vals,surr.silh_vals,real.F,real.maxK,real.Thrs);

