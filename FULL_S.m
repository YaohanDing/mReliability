function [S, P_O, P_C, SE, CI] = FULL_S(CODES, Q, SCALE, RATIO)
% Calculate the generalized form of the S index and its properties
%	[S, P_O, P_E, SE, CI] = FULL_S(DATA, Q, SCALE, RATIO)
%
%   CODES should be a numerical matrix where each row corresponds to a
%   single item of measurement (e.g., participant or question) and each
%   column corresponds to a single source of measurement (i.e., coder).
%   This function can handle any number of coders and values.
%
%   Q is an optional parameter that can be used to specify the number of
%   possible values. If this variable is not specified, then the number
%   of possible values is inferred from the CODES matrix. This inference 
%   can underestimate S if all possible values aren't included in CODES.
%
%	SCALE is a string corresponding to the weighting scheme to use:
%	-Use 'nominal' weights for unordered categories (default)
%	-Use 'ordinal' weights for ordered categories of unequal size
%	-Use 'interval' weights for ordered categories with equal spacing
%	-Use 'ratio' weights for ordered categories with a meaningful zero
%
%	RATIO is an optional parameter that can be used to specify the sampling
%   fraction for the current reliability experiment; it is used in the
%   calculation of SE and CI. To generalize from a sample of n items (this
%   is the number of items in CODES) to a population of N items (this is
%   the number of items in your entire dataset), set RATIO to the fraction
%   of n to N (i.e., n/N). The default of 0 can be used when N is unknown.
%
%   S is a chance-corrected index of agreement. It assumes that each
%   category has an equal chance of being selected at random. It ranges
%   from -1.0* to 1.0 where 0.0 means coders were no better than chance.
%   *The actual lower bound is determined by the number of possible values.
%
%	P_O is the percent agreement observed between coders.
%
%	P_C is the percent agreement expected to be due to chance. 
%   
%	SE is the standard error of the S estimate conditional on rater sample.
%
%	CI is a two-element vector containing the lower and upper bounds of
%	the 95% confidence interval for the S estimate (based on SE).
%
%   Example usage: [S, P_O, P_C, SE, CI] = FULL_S(smiledata,2,'nominal',0);
%   
%	(c) Jeffrey M Girard, 2015
%   
%	References:
%
%   Bennett, E. M., Alpert, R., & Goldstein, A. C. (1954).
%   Communication through limited response questioning.
%   The Public Opinion Quarterly, 18(3), 303�308.
%
%   Gwet, K. L. (2014). Handbook of inter-rater reliability:
%	The definitive guide to measuring the extent of agreement among raters
%	(4th ed.). Gaithersburg, MD: Advanced Analytics.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Calculate variables
if nargin < 3, RATIO = 0; end
CODES(all(~isfinite(CODES),2),:) = [];
[n,~] = size(CODES);
x = unique(CODES(:));
x(~isfinite(x)) = [];
q = length(x);

%% Calculate weights
w = nan(q,q);
for k = 1:q
    for l = 1:q
        switch SCALE
            case 'nominal'
                w = eye(q);
            case 'ordinal'
                if k==l
                    w(k,l) = 1;
                else
                    M_kl = nchoosek((max(k,l) - min(k,l) + 1),2);
                    M_1q = nchoosek((max(1,q) - min(1,q) + 1),2);
                    w(k,l) = 1 - (M_kl / M_1q);
                end
            case 'interval'
                if k==l
                    w(k,l) = 1;
                else
                    dist = abs(x(k) - x(l));
                    maxdist = max(x) - min(x);
                    w(k,l) = 1 - (dist / maxdist);
                end
            case 'ratio'
                w(k,l) = 1 - (((x(k) - x(l)) / (x(k) + x(l)))^2) / (((max(x) - min(x)) / (max(x) + min(x)))^2);
                if x(k)==0 && x(l)==0, w(k,l) = 1; end
            otherwise
                error('Type must be nominal, ordinal, interval, or ratio');
        end
    end
end

%% Calculate percent agreement for each item and overall
p_a_i = zeros(n,1);
for i = 1:n
    r_i = sum(isfinite(CODES(i,:)));
    if r_i >= 2
        for k = 1:q
            r_ik = sum(CODES(i,:)==x(k));
            rstar_ik = 0;
            for l = 1:q
                w_kl = w(k,l);
                r_il = sum(CODES(i,:)==x(l));
                rstar_ik = rstar_ik + (w_kl * r_il);
            end
            p_a_i(i) = p_a_i(i) + (r_ik * (rstar_ik - 1)) / (r_i * (r_i - 1));
        end
    end
end
P_O = sum(p_a_i) / sum(sum(isfinite(CODES),2)>=2);

%% Calculate percent chance agreement for each item and overall
p_e_i = zeros(n,1);
for i = 1:n
    T_w = sum(sum(w));
    p_e_i(i) = T_w / (q ^ 2);
end
P_C = mean(p_e_i);

%% Calculate K point estimate
S = (P_O - P_C) / (1 - P_C);

%% Return if variance is not requested
if nargout <=3
    SE = NaN;
    CI = [NaN,NaN];
    return;
end

%% Calculate variance of S point estimate
S_i = nan(n,1);
v_inner = 0;
for i = 1:n
    r_i = sum(isfinite(CODES(i,:)));
    if r_i >= 2
        nprime = sum(~isnan(p_a_i));
        S_i(i) = (n / nprime) * (p_a_i(i) - P_C) / (1 - P_C);
    else
        S_i(i) = 0;
    end
    v_inner = v_inner + (S_i(i) - S) ^ 2;
end
v = ((1 - RATIO) / n) * (1 / (n - 1)) * sum(v_inner);

%% Calculate the standard error and confidence interval
SE = sqrt(v);
CI = [S - 1.96 * SE, S + 1.96 * SE];

end