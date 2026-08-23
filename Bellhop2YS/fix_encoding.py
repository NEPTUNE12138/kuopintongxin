import os
files = [
    'figure_sparsity_comparison.m', 
    'figure_param_vs_range.m', 
    'figure_param_vs_depth.m', 
    'demo_sparsity_analysis.m', 
    'batch_depth_sweep.m', 
    'batch_range_sweep.m', 
    'generate_report_figures.m'
]
for fname in files:
    if os.path.exists(fname):
        try:
            with open(fname, 'r', encoding='utf-8') as f:
                content = f.read()
            content = content.replace("'宋体'", "'Microsoft YaHei'")
            with open(fname, 'w', encoding='gbk') as f:
                f.write(content)
            print(f"Fixed {fname}")
        except Exception as e:
            print(f"Error processing {fname}: {e}")
