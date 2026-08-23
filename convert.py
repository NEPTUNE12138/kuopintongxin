import markdown
import os

files = ["导师汇报_项目总结与创新点.md", "答辩讲稿_稳健水声通信系统.md"]
html_template = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body {{ font-family: "Microsoft YaHei", sans-serif; line-height: 1.6; padding: 40px; }}
        h1, h2, h3 {{ color: #333; }}
        code {{ background-color: #f4f4f4; padding: 2px 4px; border-radius: 4px; font-family: Consolas, monospace; }}
        blockquote {{ border-left: 4px solid #ccc; margin: 0; padding-left: 10px; color: #666; }}
        ul, ol {{ margin-top: 0; margin-bottom: 10px; }}
    </style>
</head>
<body>
    {content}
</body>
</html>'''

for file in files:
    with open(file, "r", encoding="utf-8") as f:
        text = f.read()
    html = markdown.markdown(text)
    html_content = html_template.format(content=html)
    html_path = os.path.abspath(file.replace(".md", ".html"))
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html_content)
print("HTML Generated")
