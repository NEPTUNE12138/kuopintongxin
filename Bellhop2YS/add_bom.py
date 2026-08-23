import os
import codecs

files = [
    'figure_sparsity_comparison.m', 
    'figure_param_vs_range.m', 
    'figure_param_vs_depth.m', 
    'generate_report_figures.m'
]

for fname in files:
    if os.path.exists(fname):
        try:
            with open(fname, 'r', encoding='utf-8') as file:
                content = file.read()
            # Write with utf-8-sig to add BOM
            with open(fname, 'w', encoding='utf-8-sig') as file:
                file.write(content)
            print(f"Added BOM to {fname}")
        except Exception as e:
            print(f"Error processing {fname}: {e}")
