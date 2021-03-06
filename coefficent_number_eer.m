% This script is used in the Cepstral Coefficient methods, to look at the
% eer vs number of coefficients, without using PCA or Delta-coefficients

allFiles = 'allFiles.txt';
trainList = 'train_read_trials.txt';  
testList = 'test_read_trials.txt';

use_pca = 0;
pca_latent_knob = 0.99999;


use_delta = 0;
use_delta_delta = 0;

enable_fusion = 0;

max_num_coeff = 750;
incr = 3;
eer_array = zeros(length(1:incr:max_num_coeff), 1);

for num_coeffs = 1 : incr : max_num_coeff

    [trainEER, testScores, testLabels, eer] =  fun_lfcc( ...
    allFiles, trainList, testList, use_pca, pca_latent_knob, ...
    num_coeffs, use_delta, use_delta_delta, enable_fusion);
    
    eer_array(int64((num_coeffs-1)/incr)+1) = eer;
    fprintf("Current Coeff is %d.\n", num_coeffs);
    
end

figure()
plot(1:incr:max_num_coeff, eer_array);
