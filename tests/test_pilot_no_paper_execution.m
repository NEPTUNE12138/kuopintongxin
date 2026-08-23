function test_pilot_no_paper_execution()
% TEST_PILOT_NO_PAPER_EXECUTION Ensure Pilot runner cannot launch Paper mode.
    threw = false;
    try
        run_paper2_full_pipeline('paper');
    catch ME
        if strcmp(ME.identifier, 'MATLAB:error') || ~isempty(strfind(ME.message, 'PILOT_BLOCKED'))
            threw = true;
        end
    end
    
    assert(threw, 'Pipeline must block Paper mode execution during Round 9.');
    
    disp('test_pilot_no_paper_execution passed.');
end
