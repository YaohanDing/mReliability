function [S, P_O, P_C, SE, CI] = FULL_S(CODES, CATEGORIES, SCALE, RATIO)
% Calculate the generalized form of Bennett's S index
%   [S, P_O, P_E, SE, CI] = FULL_S(DATA, CATEGORIES, SCALE, RATIO)
%
%   CODES should be a numerical matrix where each row corresponds to a
%   single item of measurement (e.g., participant or question) and each
%   column corresponds to a single source of measurement (i.e., rater).
%   This function can handle any number of raters and values.
%
%   CATEGORIES is an optional parameter specifying the possible categories
%   as a numerical vector. If this variable is not specified, then the
%   possible categories are inferred from the CODES matrix. This can
%   underestimate reliability if all possible categories aren't used.
%
%   SCALE is an optional parameter specifying the scale of measurement:
%   -Use 'nominal' for unordered categories (default)
%   -Use 'ordinal' for ordered categories of unequal size
%   -Use 'interval' for ordered categories with equal spacing
%   -Use 'ratio' for ordered categories with equal spacing and a zero point
%
%   RATIO is an optional parameter that can be used to specify the sampling
%   fraction for the current reliability experiment; it is used in the
%   calculation of SE and CI. To generalize from a sample of n items (this
%   is the number of items in CODES) to a population of N items (this is
%   the number of items in your entire dataset), set RATIO to the fraction
%   of n to N (i.e., n/N). The default of 0 can be used when N is unknown.
%
%   S is a chance-corrected index of agreement. It assumes that each
%   category has an equal chance of being selected at random. It ranges
%   from -1.0* to 1.0 where 0.0 means raters were no better than chance.
%   *The actual lower bound is determined by the number of categories.
%
%   P_O is the percent observed agreement (from 0.000 to 1.000).
%
%   P_C is the estimated percent chance agreement (from 0.000 to 1.000).
%   
%   SE is the standard error, conditional on rater sample.
%
%   CI is a two-element vector containing the lower and upper bounds of
%   the 95% confidence interval for the S estimate (based on the SE).
%
%   Example usage: [S, P_O, P_C, SE, CI] = FULL_S(smiledata,[0,1],'nominal',0);
%   
%   (c) Jeffrey M Girard, 2016
%   
%   References:
%
%   Bennett, E. M., Alpert, R., & Goldstein, A. C. (1954).
%   Communication through limited response questioning.
%   The Public Opinion Quarterly, 18(3), 303�308.
%
%   Gwet, K. L. (2014). Handbook of inter-rater reliability:
%   The definitive guide to measuring the extent of agreement among raters
%   (4th ed.). Gaithersburg, MD: Advanced Analytics.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Remove items with all missing codes
CODES(all(~isfinite(CODES),2),:) = [];
%% Calculate basic descriptives
[n,r] = size(CODES);
nprime = sum(sum(isfinite(CODES),2)>=2);
x = unique(CODES);
x(~isfinite(x)) = [];
if nargin < 2
    CATEGORIES = x;
    SCALE = 'nominal';
    RATIO = 0;
elseif nargin < 3
    SCALE = 'nominal';
    RATIO = 0;
elseif nargin < 4
    RATIO = 0;
end
if isempty(CATEGORIES)
    CATEGORIES = x;
end
CATEGORIES = sort(unique(CATEGORIES(:)));
q = length(CATEGORIES);
%% Output basic descriptives
fprintf('Number of items = %d\n',n);
fprintf('Number of raters = %d\n',r);
fprintf('Possible categories = %s\n',mat2str(CATEGORIES));
fprintf('Observed categories = %s\n',mat2str(x));
fprintf('Scale of measurement = %s\n',SCALE);
fprintf('Sampling fraction = %.3f\n',RATIO);
%% Check for valid data from more than one rater
if n < 1
    S = NaN;
    fprintf('S = NaN; At least 1 item is required.\n')
    return;
end
if r < 2
    S = NaN;
    fprintf('S = NaN; At least 2 raters are required.\n');
    return;
end
if any(ismember(x,CATEGORIES)==0)
    fprintf('ERROR: Categories were observed in CODES that were not included in CATEGORIES.\n');
    return;
end
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
                error('Scale must be nominal, ordinal, interval, or ratio');
        end
    end
end
%% Calculate percent agreement for each item and overall
p_o_i = zeros(n,1);
for i = 1:n
    r_i = sum(isfinite(CODES(i,:)));
    if r_i >= 2
        for k = 1:length(x)
            r_ik = sum(CODES(i,:)==x(k));
            rstar_ik = 0;
            for l = 1:length(x)
                w_kl = w(k,l);
                r_il = sum(CODES(i,:)==x(l));
                rstar_ik = rstar_ik + (w_kl * r_il);
            end
            p_o_i(i) = p_o_i(i) + (r_ik * (rstar_ik - 1)) / (r_i * (r_i - 1));
        end
    end
end
P_O = sum(p_o_i) / sum(sum(isfinite(CODES),2)>=2);
%% Calculate percent chance agreement for each item and overall
T_w = sum(sum(w));
P_C = T_w / (q ^ 2);
%% Calculate S point estimate
S = (P_O - P_C) / (1 - P_C);
%% Calculate variance of S point estimate
v_inner = 0;
for i = 1:n
    r_i = sum(isfinite(CODES(i,:)));
    if r_i >= 2
        s_i = (n / nprime) * (p_o_i(i) - P_C) / (1 - P_C);
    else
        s_i = 0;
    end
    v_inner = v_inner + (s_i - S) ^ 2;
end
v = ((1 - RATIO) / n) * (1 / (n - 1)) * sum(v_inner);
%% Calculate standard error and confidence interval
SE = sqrt(v);
CI = [S - 1.96 * SE, S + 1.96 * SE];
%% Output reliability and variance components
fprintf('Percent observed agreement = %.3f\n',P_O);
fprintf('Percent chance agreement = %.3f\n',P_C);
fprintf('\nS index = %.3f\n',S);
fprintf('Standard Error (SE) = %.3f\n',SE);
fprintf('95%% Confidence Interval = %.3f to %.3f\n',CI(1),CI(2));

end