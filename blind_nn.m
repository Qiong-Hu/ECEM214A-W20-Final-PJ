function [testScores] = blind_nn(allFiles, trainList, testList, blind_list, ...
    blind_trials, use_pca, pca_latent_knob)

% This function is used to generated test score for blind test data using
% a pretrained neural network

    eval_prediction = 'ziqi_qiong_yuchun_blind_label_nn.txt'; % change it to your group member's name

%% Extract features for original data
    featureName = 'featureVGGVox_x1.mat';
    ok = exist(featureName, 'file');
    if ok
        load(featureName, "featureDict", "myFiles", "cnt");
        featureDict1 = featureDict;
    else
        % Extract features
        featureDict = containers.Map;
        fid = fopen(allFiles);
        myData = textscan(fid,'%s');
        fclose(fid);
        myFiles = myData{1};
        for cnt = 1:length(myFiles)
            [snd, fs] = audioread(myFiles{cnt});
            try
                feat = vcc_vox_net(snd);
                featureDict(myFiles{cnt}) = feat;
            catch
                disp(["No features for the file ", myFiles{cnt}]);
            end

            if(mod(cnt,100)==0)
                disp(['Completed ',num2str(cnt),' of ',num2str(length(myFiles)),' files.']);
            end
        end
        save('featureVGGVox_x1');
    end

%% Extract Features for blind data
    
    featureName = 'featureVGGVox_x1_blind.mat';
    ok = exist(featureName, 'file');

    if ok
        load(featureName, "featureDict2", "myFiles", "cnt");
    else
        % Extract features
        featureDict2 = containers.Map;
        fid = fopen(blind_list);
        myData2 = textscan(fid,'%s');
        fclose(fid);
        myFiles2 = myData2{1}; 
        for cnt = 1:length(myFiles2)
            [snd,fs] = audioread(myFiles2{cnt});
            try
                feat = vcc_vox_net(snd);
                featureDict2(myFiles2{cnt}) = feat;
            catch
                disp(["No features for the file ", myFiles2{cnt}]);
            end

            if(mod(cnt,1)==0)
                disp(['Completed ',num2str(cnt),' of ',num2str(length(myFiles2)),' files.']);
            end
        end
        save('featureVGGVox_x1_blind');
    end
    
    %% do PCA if required
    old_dim = size(featureDict(myFiles{cnt}), 1);
    new_dim = old_dim;

    if use_pca
        fid = fopen(allFiles,'r');
        myData = textscan(fid,'%s');
        fclose(fid);
        fileList = myData{1};
        wholeFeatures = zeros(length(fileList), old_dim);

        for cnt = 1:length(fileList)
            wholeFeatures(cnt,:) = featureDict(fileList{cnt});
        end

        [coeff,score,latent] = pca(wholeFeatures);
        new_dim = sum(cumsum(latent)./sum(latent) < pca_latent_knob)+1;
        trans_mat = coeff(:,1:new_dim);
        % pca tranfer matrix is only calcualted on the original data, not
        % on the blind test data to ensure fairness
        % apply dimension reduction
        for cnt = 1:length(myFiles)
            featureDict(myFiles{cnt}) = transpose(featureDict(myFiles{cnt}))*trans_mat;
        end
        for cnt = 1:length(myFiles2)
            featureDict2(myFiles2{cnt}) = transpose(featureDict2(myFiles2{cnt}))*trans_mat;
        end
    end
    
    
    
     %% Train the classifier
    fid = fopen(trainList,'r');
    myData = textscan(fid,'%s %s %f');
    fclose(fid);
    fileList1 = myData{1};
    fileList2 = myData{2};
    trainLabels = myData{3};
    trainFeatures = zeros(length(trainLabels), new_dim);
    for cnt = 1:length(trainLabels)
        trainFeatures(cnt,:) = -abs(featureDict1(fileList1{cnt})-featureDict1(fileList2{cnt}));
    end

    Mdl = fitcknn(trainFeatures,trainLabels,'NumNeighbors',15000,'Standardize',1);

    %%
    % Test the classifierground_truth = 'blind_labels';
    %     fid = fopen(testList);
    %     myData = textscan(fid,'%f');
    %     fclose(fid);
    %     testLabels = myData{1};
    fid = fopen(testList);
    myData = textscan(fid,'%s %s %f');
    fclose(fid);
    fileList1 = myData{1};
    fileList2 = myData{2};
    testLabels = myData{3};
    testFeatures = zeros(length(testLabels), new_dim);
    for cnt = 1:length(testLabels)
        testFeatures(cnt,:) = -abs(featureDict1(fileList1{cnt})-featureDict1(fileList2{cnt}));
    end

    [~,prediction,~] = predict(Mdl,testFeatures);
    testScores = (prediction(:,2)./(prediction(:,1)+1e-15));
    [eer,~] = compute_eer(testScores, testLabels);
    disp(['The EER is ',num2str(eer),'%.']);

    %% Blind Evaluation

    % Test the classifier on eval data
    fid = fopen(blind_trials);
    myData = textscan(fid,'%s %s');
    fclose(fid);
    fileList1 = myData{1};
    fileList2 = myData{2};
    % testLabels = myData{3};
    testFeatures2 = zeros(length(fileList1), new_dim);
    for cnt = 1:length(fileList1)
        testFeatures2(cnt, :) = -abs(featureDict2(fileList1{cnt})-featureDict2(fileList2{cnt}));
    end

    [~,prediction,~] = predict(Mdl,testFeatures2);
    testScores = (prediction(:,2)./(prediction(:,1)+1e-15));
    fid=fopen(eval_prediction,'w');
    fprintf(fid,'%f\n',testScores);
    fclose(fid);

    filename = 'blind_testScore_nn.mat';
    save(filename)
end

