function [threshold, mask, meta] = os_cfar_1d(x_power, train_cells, guard_cells, order_idx, pfa)
% OS_CFAR_1D 1D Ordered-Statistic CFAR for power sequence
% Strictly enforces full training window to avoid false edge detections.

    N = length(x_power);
    x_power = x_power(:)'; 
    
    half_train = round(train_cells / 2);
    half_guard = round(guard_cells / 2);
    
    if order_idx < 1
        k = round(order_idx * train_cells);
    else
        k = round(order_idx);
    end
    k = max(1, min(k, train_cells));
    
    N_t = train_cells;
    
    % Find scaling factor alpha
    try
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
        alpha = -log(pfa) * (N_t / k); 
    end
    
    threshold = inf(1, N); % Default to Inf at edges
    
    for i = 1:N
        left_train_start = i - half_guard - half_train;
        left_train_end   = i - half_guard - 1;
        
        right_train_start = i + half_guard + 1;
        right_train_end   = i + half_guard + half_train;
        
        % Edge check: Only detect if full window is available
        if left_train_start < 1 || right_train_end > N
            continue; 
        end
        
        cells = [x_power(left_train_start:left_train_end), x_power(right_train_start:right_train_end)];
        
        sorted_cells = sort(cells, 'ascend');
        noise_est = sorted_cells(k);
        
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
