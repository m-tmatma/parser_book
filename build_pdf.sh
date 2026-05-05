#!/bin/bash

# LuaLaTeX PDF Build Script for Parser Book

set -e  # エラー時に停止

# ディレクトリ設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
TEX_MAIN="$SCRIPT_DIR/tex/main.tex"
DOCKER_IMAGE="${PARSER_BOOK_DOCKER_IMAGE:-parser-book-luatex}"

# 出力ディレクトリの準備
mkdir -p "$BUILD_DIR"

# LuaLaTeX依存関係チェック
check_lualatex() {
    if ! command -v lualatex &> /dev/null; then
        echo "❌ lualatexがインストールされていません"
        echo "インストール方法: sudo apt-get install texlive-luatex (Ubuntu/Debian)"
        exit 1
    fi
}

# BibTeX依存関係チェック
check_bibtex() {
    if ! command -v bibtex &> /dev/null; then
        echo "❌ bibtexがインストールされていません"
        exit 1
    fi
}

# Docker依存関係チェック
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "❌ dockerがインストールされていません"
        exit 1
    fi
}

# 依存関係チェック
check_dependencies() {
    echo "🔍 依存関係をチェックしています..."
    check_lualatex
    check_bibtex
    echo "✅ 依存関係OK"
}

run_lualatex() {
    lualatex \
        -interaction=nonstopmode \
        -halt-on-error \
        -shell-escape \
        -jobname=parser_book \
        -output-directory="$BUILD_DIR" \
        "$TEX_MAIN"
}

# TeXソースからLuaLaTeXでPDFを生成
build_pdf() {
    echo "🔧 TeXソースからLuaLaTeXでPDFを生成しています..."

    cd "$SCRIPT_DIR"

    if [ ! -f "$TEX_MAIN" ]; then
        echo "❌ TeXメインファイルが見つかりません: $TEX_MAIN"
        exit 1
    fi

    run_lualatex
    (cd "$BUILD_DIR" && bibtex parser_book)
    run_lualatex
    run_lualatex

    echo "✅ PDF生成完了: $BUILD_DIR/parser_book.pdf"
}

# Docker内でLuaLaTeX PDFを生成
build_pdf_with_docker() {
    echo "🐳 DockerでLuaLaTeX環境を準備しています..."

    cd "$SCRIPT_DIR"

    docker build \
        -f "$SCRIPT_DIR/docker/luatex/Dockerfile" \
        -t "$DOCKER_IMAGE" \
        "$SCRIPT_DIR"

    docker run --rm \
        --user "$(id -u):$(id -g)" \
        -e HOME=/tmp \
        -v "$SCRIPT_DIR:/work" \
        -w /work \
        "$DOCKER_IMAGE" \
        ./build_pdf.sh build
}

# クリーンアップ
clean() {
    echo "🧹 ビルドディレクトリをクリーンアップ..."
    rm -rf "$BUILD_DIR"/*
    echo "✅ クリーンアップ完了"
}

# ヘルプ表示
show_help() {
    cat << EOF
使用方法: $0 [オプション]

オプション:
  build       TeXソースからLuaLaTeXでPDFを生成 (デフォルト)
  docker      Docker内でLuaLaTeX PDFを生成
  clean       ビルドディレクトリをクリーンアップ
  check       依存関係をチェック
  help        このヘルプを表示

例:
  $0              # TeXソースからLuaLaTeXでPDFを生成
  $0 docker       # Docker内でLuaLaTeX PDFを生成
  $0 clean        # クリーンアップ
EOF
}

# メイン処理
main() {
    case "${1:-build}" in
        "build")
            check_dependencies
            build_pdf
            ;;
        "docker")
            check_docker
            build_pdf_with_docker
            ;;
        "clean")
            clean
            ;;
        "check")
            check_dependencies
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
         "")
            check_dependencies
            build_pdf
            ;;
        *)
            echo "❌ 不明なオプション: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
