function [threshold, mask, meta] = os_cfar_1d(x_power, train_cells, guard_cells, order_idx, pfa)
% OS_CFAR_1D 1D Ordered-Statistic CFAR for power sequence
% x_power: 1D power sequence (abs(x).^2)
% train_cells: Total number of training cells (sum of both sides)
% guard_cells: Total number of guard cells (sum of both sides)
% order_idx: The k-th rank to select (if < 1, treated as fraction of train_cells)
% pfa: Target Probability of False Alarm

    N = length(x_power);
    x_power = x_power(:)'; % Make row vector
    
    half_train = round(train_cells / 2);
    half_guard = round(guard_cells / 2);
    
    if order_idx < 1
        k = round(order_idx * train_cells);
    else
        k = round(order_idx);
    end
    k = max(1, min(k, train_cells));
    
    % Find scaling factor alpha
    % Formula for OS-CFAR in exponential noise:
    % Pfa = k * nchoosek(train_cells, k) * beta(k, train_cells - k + 1 + alpha)
    % We use fzero to solve for alpha
    
    N_t = train_cells;
    
    % Safeguard for large combinations
    try
        % log-domain to avoid Inf in nchoosek
        log_k_choose_k = gammaln(N_t + 1) - gammaln(k + 1) - gammaln(N_t - k + 1);
        obj_fun = @(alpha) pfa - exp(log(k) + log_k_choose_k + gammaln(k) + gammaln(N_t - k + 1 + alpha) - gammaln(N_t + 1 + alpha));
        
        if obj_fun(0) * obj_fun(1000) < 0
            alpha = fzero(obj_fun, [0, 1000]);
        else
            alpha_search = linspace(0, 100, 10000);
            vals = arrayfun(obj_fun, alpha_search);
            [~, min_idx] = min(abs(vals));
            alpha = alpha_search(min_idx);
        end
    catch
        % Fallback scaling factor if numerical issues occur
        alpha = -log(pfa) * (N_t / k); % Crude approximation
    end
    
    threshold = zeros(1, N);
    
    for i = 1:N
        % Define window indices
        left_train_start = max(1, i - half_guard - half_train);
        left_train_end   = max(0, i - half_guard - 1);
        
        right_train_start = min(N + 1, i + half_guard + 1);
        right_train_end   = min(N, i + half_guard + half_train);
        
        % Extract training cells
        cells = [];
        if left_train_end >= left_train_start
            cells = [cells, x_power(left_train_start:left_train_end)];
        end
        if right_train_end >= right_train_start
            cells = [cells, x_power(right_train_start:right_train_end)];
        end
        
        if isempty(cells)
            threshold(i) = inf; % Cannot detect
            continue;
        end
        
        % Sort and select k-th order statistic
        actual_N = length(cells);
        actual_k = round(k * (actual_N / train_cells));
        actual_k = max(1, min(actual_k, actual_N));
        
        sorted_cells = sort(cells, 'ascend');
        noise_est = sorted_cells(actual_k);
        
        threshold(i) = alpha * noise_est;
    end
    
    mask = x_power > threshold;
    
    meta.alpha = alpha;
    meta.k = k;
    meta.train_cells = train_cells;
    meta.guard_cells = guard_cells;
    meta.pfa = pfa;
    meta.algorithm = 'Order-Statistic Adaptive Threshold';
end
