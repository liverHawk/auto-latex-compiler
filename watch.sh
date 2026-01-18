#!/bin/bash
SOURCE="/workspace/source"
OUTPUT="/workspace/output"
convert_file() {
    local file="$1"
    local name=$(basename "$file" .tex)
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚙️  $name.tex（依存ファイル含む）"
    echo "🕐 $(date '+%Y-%m-%d %H:%M:%S')"
    
    cd "$SOURCE"
    local error_output=$(mktemp)

    # 既存の中間ファイルを削除（ソース側でビルドし、tex/bib/pdf は残す）
    for ext in aux log bcf bbl blg fdb_latexmk fls run.xml out toc lof lot; do
        rm -f "$SOURCE/${name}.${ext}"
    done

    if latexmk \
        -lualatex \
        -interaction=nonstopmode \
        "${name}.tex" >"$error_output" 2>&1; then
        
        # ビルドに成功した PDF を output ディレクトリへコピー（ファイル名にタイムスタンプを付与）
        mkdir -p "$OUTPUT"
        if [ -f "$SOURCE/$name.pdf" ]; then
            timestamp=$(date '+%Y%m%d-%H%M%S')
            cp "$SOURCE/$name.pdf" "$OUTPUT/${name}_${timestamp}.pdf"
        fi

        size=$(ls -lh "$OUTPUT"/${name}_*.pdf 2>/dev/null | awk 'END {print $5}')
        echo "✅ ${name}_*.pdf ($size)"
        rm -f "$error_output"
    else
        echo "❌ エラーが発生しました"
        echo ""
        if [ -f "$SOURCE/$name.log" ]; then
            echo "📋 エラーログ（最後の20行）:"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            tail -20 "$SOURCE/$name.log" | grep -A 5 -B 5 -i "error\|!" || tail -20 "$SOURCE/$name.log"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        fi
        if [ -s "$error_output" ]; then
            echo "📋 エラー出力:"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            cat "$error_output"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        fi
        rm -f "$error_output"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}
find_main_files() {
    grep -l '\\documentclass' "$SOURCE"/*.tex 2>/dev/null
}
echo "📋 LaTeX 監視開始（依存関係自動追跡）"
echo ""
# 初期ビルド
for main_file in $(find_main_files); do
    convert_file "$main_file"
done
echo ""
echo "👀 ファイル監視中... (Ctrl+C で終了)"
echo ""

# デバウンス用の変数
BUILD_PID=""
DEBOUNCE_DELAY=1.5  # 秒

# ビルドを実行する関数（デバウンス付き）
debounced_build() {
    # 既存のビルド待機プロセスがあればキャンセル
    if [ -n "$BUILD_PID" ] && kill -0 "$BUILD_PID" 2>/dev/null; then
        kill "$BUILD_PID" 2>/dev/null
    fi
    
    # 新しいビルド待機プロセスを開始
    (
        sleep "$DEBOUNCE_DELAY"
        echo ""
        echo "📝 変更検知: 複数ファイル（最後の保存から ${DEBOUNCE_DELAY}秒経過）"
        
        # すべてのメインファイルを再ビルド
        for main_file in $(find_main_files); do
            convert_file "$main_file"
        done
    ) &
    BUILD_PID=$!
}

# すべての .tex ファイルを監視
inotifywait -m -r -e close_write "$SOURCE" --format '%w%f' | while read file; do
    if [ "${file##*.}" = "tex" ]; then
        echo "📝 変更検知: $(basename "$file") (待機中...)"
        debounced_build
    fi
done
