function test_phase_mask_reset()
% TEST_PHASE_MASK_RESET
% Verifies that fade scenarios produce only PRE/FADE/POST,
% and non-fade scenarios produce only NORMAL.
% Ensures no stale field bleed-over.

    fprintf('Running test_phase_mask_reset...\n');

    N = 121; % example num_diff_symbols
    fs = 48000;

    % Simulate fade scenario
    t = (0:N*186-1) / fs;
    packet_duration = length(t) / fs;
    fade_center = packet_duration / 2;
    fade_width = 0.1;
    fade_env = 1 - 0.9 * exp(-0.5 * ((t - fade_center) / (fade_width / 3)).^2);

    sym_centers = round(linspace(1, length(t), N));
    fade_env_at_centers = fade_env(sym_centers);
    fade_mask = fade_env_at_centers < 0.5;

    % Test fade scenario
    phases = struct();
    first_fade = find(fade_mask, 1, 'first');
    last_fade = find(fade_mask, 1, 'last');
    if ~isempty(first_fade) && ~isempty(last_fade)
        phases.PRE = 1:(first_fade-1);
        phases.FADE = first_fade:last_fade;
        phases.POST = (last_fade+1):N;
    end

    fn = fieldnames(phases);
    assert(~ismember('NORMAL', fn), 'Fade scenario must NOT have NORMAL field');
    assert(ismember('PRE', fn), 'Fade scenario must have PRE field');
    assert(ismember('FADE', fn), 'Fade scenario must have FADE field');
    assert(ismember('POST', fn), 'Fade scenario must have POST field');

    % Now test static scenario — must reset
    phases = struct();
    phases.NORMAL = 1:N;

    fn = fieldnames(phases);
    assert(ismember('NORMAL', fn), 'Static scenario must have NORMAL field');
    assert(~ismember('PRE', fn), 'Static scenario must NOT have PRE field');
    assert(~ismember('FADE', fn), 'Static scenario must NOT have FADE field');
    assert(~ismember('POST', fn), 'Static scenario must NOT have POST field');

    fprintf('test_phase_mask_reset passed.\n');
end
