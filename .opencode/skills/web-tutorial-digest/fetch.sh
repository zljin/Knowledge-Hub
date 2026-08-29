#!/usr/bin/env bash
# 抓取网页教程 → 转 Markdown 的最小化脚本。
# 依赖: curl, python3 (系统自带)。不依赖 pandoc/html2text。
# 用法: bash fetch.sh <URL> [输出目录]
#   URL    必填。要抓取的网页地址。
#   输出目录 可选。默认为当前工作目录下的 tmp/（已 gitignore，临时文件不进 git）。
#   如需留档，第二个参数给工作区内的目录（如 doc/static 或 doc/raw）。
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "用法: bash fetch.sh <URL> [输出目录]" >&2
  exit 1
fi

URL="$1"
OUT_DIR="${2:-$(pwd)/tmp}"
mkdir -p "$OUT_DIR"

# 从 URL 末尾提取安全文件名（去协议、去参数、去扩展名）
NAME="$(printf '%s' "$URL" | sed -E 's|^[a-zA-Z]+://||' | tr '/?#&%.:' '_' | tr -s '_')"
NAME="${NAME:-page}"
RAW="$OUT_DIR/${NAME}.html"
MD="$OUT_DIR/${NAME}.md"

echo "==> 抓取: $URL"
if ! curl -L --max-time 60 -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36" -sS "$URL" -o "$RAW"; then
  echo "!! curl 抓取失败，请改用 opencode 的 webfetch 能力，或检查 URL。" >&2
  exit 1
fi

SIZE=$(wc -c < "$RAW")
echo "==> 原始 HTML 大小: ${SIZE} 字节"

if [ "$SIZE" -lt 500 ]; then
  echo "!! 抓到的 HTML 过小，可能是 JS 动态渲染页面或反爬。建议改用 opencode 的 webfetch。" >&2
fi

# 用 python3 清洗：去 script/style，还原代码块与换行，转 UTF-8 文本
python3 - "$RAW" "$MD" <<'PY'
import re, sys, html

raw_path, md_path = sys.argv[1], sys.argv[2]
raw = open(raw_path, 'rb').read()
raw = raw.decode('utf-8', errors='replace')

# 去除脚本与样式
raw = re.sub(r'<script[\s\S]*?</script>', ' ', raw, flags=re.I)
raw = re.sub(r'<style[\s\S]*?</style>', ' ', raw, flags=re.I)
raw = re.sub(r'<!--[\s\S]*?-->', ' ', raw)

def repl_br(m):
    return '\n'
raw = re.sub(r'<br\s*/?>', repl_br, raw, flags=re.I)

def repl_block(m):
    tag = m.group(1).lower()
    return '\n\n' if tag in ('p','div','h1','h2','h3','h4','h5','h6','li','tr','section','article','pre') else ' '
raw = re.sub(r'</(p|div|h1|h2|h3|h4|h5|h6|li|tr|pre|section|article)>', repl_block, raw)

# 代码块标记
raw = re.sub(r'<pre>', '\n```\n', raw, flags=re.I)
raw = re.sub(r'</pre>', '\n```\n', raw, flags=re.I)

# 去掉剩余所有标签
raw = re.sub(r'<[^>]+>', ' ', raw)
raw = html.unescape(raw)

# 规整空白行
lines = [ln.rstrip() for ln in raw.splitlines()]
out, blank = [], 0
for ln in lines:
    s = re.sub(r'[ \t\u00a0]+', ' ', ln).strip()
    if not s:
        blank += 1
        if blank == 1:
            out.append('')
    else:
        blank = 0
        out.append(s)
md = '\n'.join(out).strip() + '\n'

with open(md_path, 'w', encoding='utf-8') as f:
    f.write(md)

print(f"==> 已写入 Markdown: {md_path}")
print(f"==> 内容行数: {len(md.splitlines())}")
PY
