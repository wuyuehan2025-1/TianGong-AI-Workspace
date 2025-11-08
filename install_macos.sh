#!/bin/bash

# TianGong AI Workspace - One-Click Setup Script for macOS
# 
# This script automates the installation of the Tiangong AI Workspace
# environment on macOS. It guides you through optional components with prompts.
#
# Usage: bash install_macos.sh [--full] [--minimal] [--with-pdf] [--with-node]
#

set -e

# Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

ask_yes_no() {
    local prompt="$1"
    local response
    read -p "$(echo -e ${YELLOW}$prompt${NC}) (y/n): " response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Parse command line arguments
INSTALL_MODE="interactive"
INSTALL_PDF=false
INSTALL_NODE=false
PDF_INSTALL_PERFORMED=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --full)
            INSTALL_MODE="full"
            INSTALL_PDF=true
            INSTALL_NODE=true
            shift
            ;;
        --minimal)
            INSTALL_MODE="minimal"
            shift
            ;;
        --with-pdf)
            INSTALL_PDF=true
            shift
            ;;
        --with-node)
            INSTALL_NODE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Welcome message
print_header "Welcome to the Tiangong AI Workspace Setup"
echo "This script installs the core tooling required to operate AI coding CLIs on macOS."
echo ""
echo "Installation mode: $INSTALL_MODE"
echo ""

# Check if Homebrew is installed
print_header "Step 1: Checking Homebrew Installation"
if ! command -v brew &> /dev/null; then
    print_warning "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    print_success "Homebrew installed"
else
    print_success "Homebrew is already installed"
fi

# Install core dependencies
print_header "Step 2: Installing Core Dependencies"

# Python 3.12+
if ! command -v python3 &> /dev/null || [[ $(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1) < "3.12" ]]; then
    print_warning "Python 3.12+ not found. Installing..."
    brew install python@3.12
    print_success "Python 3.12 installed"
else
    print_success "Python 3.12+ already installed: $(python3 --version)"
fi

# uv
if ! command -v uv &> /dev/null; then
    print_warning "uv not found. Installing..."
    brew install uv
    print_success "uv installed"
else
    print_success "uv already installed: $(uv --version)"
fi

# Optional: Node.js 22+ (for Node-based AI CLIs)
NODE_VERSION=""
NODE_MAJOR=0
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    NODE_MAJOR=$(echo "$NODE_VERSION" | sed 's/^v//' | cut -d. -f1)
fi

print_header "Step 3a: Node.js for AI CLI Bridges"
if [ "$NODE_MAJOR" -ge 22 ]; then
    print_success "Node.js already installed: $NODE_VERSION"
else
    if [ -n "$NODE_VERSION" ]; then
        print_warning "Detected Node.js $NODE_VERSION (<22). Several AI CLIs require Node.js 22+."
    else
        print_warning "Node.js not found. Some companion CLIs (e.g., Claude Code) require Node.js 22+."
    fi

    if [ "$INSTALL_MODE" = "full" ] && [ "$INSTALL_NODE" != true ]; then
        INSTALL_NODE=true
    fi

    if [ "$INSTALL_MODE" = "interactive" ] && [ "$INSTALL_NODE" != true ]; then
        if ask_yes_no "Install or upgrade Node.js to version 22+ now?"; then
            INSTALL_NODE=true
        else
            print_warning "Skipping Node.js installation. Node-based CLIs will remain unavailable until Node.js 22+ is installed."
        fi
    fi
fi

if [ "$INSTALL_NODE" = true ]; then
    if [ "$NODE_MAJOR" -ge 22 ]; then
        print_success "Node.js already meets the requirement. No installation needed."
    else
        print_warning "Installing Node.js 22+ via Homebrew..."
        brew install node@22
        NODE_VERSION=$(node --version)
        NODE_MAJOR=$(echo "$NODE_VERSION" | sed 's/^v//' | cut -d. -f1)
        if [ "$NODE_MAJOR" -ge 22 ]; then
            print_success "Node.js installed: $NODE_VERSION"
        else
            print_error "Node.js installation did not reach version 22+. Please check Homebrew logs."
        fi
    fi
fi

# Optional: Pandoc & LaTeX (for PDF/DOCX)
if [ "$INSTALL_MODE" != "minimal" ] || [ "$INSTALL_PDF" = true ]; then
    PANDOC_PRESENT=false
    PANDOC_OK=false
    PANDOC_VERSION_STR=""
    PANDOC_VERSION_NUM=""
    if command -v pandoc &> /dev/null; then
        PANDOC_PRESENT=true
        PANDOC_VERSION_STR=$(pandoc --version | head -1)
        PANDOC_VERSION_NUM=$(echo "$PANDOC_VERSION_STR" | grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
        PANDOC_MAJOR=$(echo "$PANDOC_VERSION_NUM" | cut -d. -f1)
        if [ "${PANDOC_MAJOR:-0}" -ge 3 ]; then
            PANDOC_OK=true
        fi
    fi

    PDFLATEX_PRESENT=false
    PDFLATEX_VERSION_STR=""
    if command -v pdflatex &> /dev/null; then
        PDFLATEX_PRESENT=true
        PDFLATEX_VERSION_STR=$(pdflatex --version 2>&1 | head -1)
    fi

    PDF_READY=false
    if [ "$PANDOC_OK" = true ] && [ "$PDFLATEX_PRESENT" = true ]; then
        PDF_READY=true
    fi

    print_header "Step 3b: Pandoc & LaTeX"

    if [ "$PANDOC_PRESENT" = true ]; then
        if [ "$PANDOC_OK" = true ]; then
            print_success "Pandoc already installed: $PANDOC_VERSION_STR"
        else
            print_warning "Pandoc detected but version < 3.0: $PANDOC_VERSION_STR"
        fi
    else
        print_warning "Pandoc not found."
    fi

    if [ "$PDFLATEX_PRESENT" = true ]; then
        print_success "LaTeX already installed: $PDFLATEX_VERSION_STR"
    else
        print_warning "LaTeX not found."
    fi

    if [ "$PDF_READY" = true ] && [ "$INSTALL_PDF" != true ]; then
        print_success "PDF/DOCX export requirements already satisfied."
    else
        if [ "$INSTALL_MODE" = "interactive" ] && [ "$INSTALL_PDF" != true ]; then
            if ask_yes_no "Install Pandoc + LaTeX for PDF/DOCX report export?"; then
                INSTALL_PDF=true
            else
                print_warning "Skipping Pandoc/LaTeX installation. PDF export will remain disabled."
            fi
        fi
    fi

    if [ "$INSTALL_PDF" = true ]; then
        PDF_INSTALL_PERFORMED=true

        if [ "$PANDOC_OK" != true ]; then
            print_warning "Installing or upgrading Pandoc..."
            brew install pandoc
            PANDOC_PRESENT=true
            PANDOC_VERSION_STR=$(pandoc --version | head -1)
            PANDOC_OK=true
            print_success "Pandoc ready: $PANDOC_VERSION_STR"
        fi

        if [ "$PDFLATEX_PRESENT" != true ]; then
            print_warning "Installing BasicTeX (lightweight LaTeX)..."
            echo ""
            echo "⚠  Note: Installation may take a few minutes..."
            echo ""
            brew install basictex
            export PATH="/Library/TeX/texbin:$PATH"
            if ! grep -q '/Library/TeX/texbin' ~/.zshrc 2>/dev/null; then
                echo 'export PATH="/Library/TeX/texbin:$PATH"' >> ~/.zshrc
            fi
            print_success "BasicTeX installed"
            print_warning "Run 'source ~/.zshrc' or restart your terminal to refresh PATH."
            PDFLATEX_PRESENT=true
            PDFLATEX_VERSION_STR=$(pdflatex --version 2>&1 | head -1)
        fi
    fi
fi

# Project setup
print_header "Step 4: Setting up Tiangong AI Workspace"

# Check if we're in the project directory
if [ ! -f "pyproject.toml" ]; then
    print_warning "pyproject.toml not found. Cloning repository..."
    git clone https://github.com/linancn/TianGong-AI-Workspace.git
    cd TianGong-AI-Workspace
fi

# Run uv sync
print_warning "Running 'uv sync' to install project dependencies..."
uv sync
print_success "Project dependencies installed"

# Verification
print_header "Step 5: Verification"

echo "Checking installations..."
echo ""

# Check Python
if python3 --version &> /dev/null; then
    print_success "Python: $(python3 --version)"
else
    print_error "Python not found"
fi

# Check uv
if uv --version &> /dev/null; then
    print_success "uv: $(uv --version)"
else
    print_error "uv not found"
fi

# Check CLI
if uv run tiangong-workspace --help &> /dev/null; then
    print_success "Workspace CLI: accessible (run 'uv run tiangong-workspace --help')"
else
    print_warning "Workspace CLI not yet available (add commands under src/tiangong_ai_workspace)."
fi

# Check optional components
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    NODE_MAJOR=$(echo "$NODE_VERSION" | sed 's/^v//' | cut -d. -f1)
    if [ "$NODE_MAJOR" -ge 22 ]; then
        print_success "Node.js: $NODE_VERSION"
    else
        print_warning "Node.js: $NODE_VERSION (upgrade to >=22 for Node-based CLIs)"
    fi
else
    print_warning "Node.js: not found (Node-based CLIs disabled)"
fi

if pandoc --version &> /dev/null; then
    print_success "Pandoc: $(pandoc --version | head -1)"
else
    if [ "$PDF_INSTALL_PERFORMED" = true ]; then
        print_error "Pandoc not found (installation may have failed)"
    else
        print_warning "Pandoc: not found (PDF/DOCX export disabled)"
    fi
fi

if pdflatex --version &> /dev/null; then
    print_success "LaTeX: $(pdflatex --version 2>&1 | head -1)"
else
    if [ "$PDF_INSTALL_PERFORMED" = true ]; then
        print_warning "LaTeX not in PATH. Run: source ~/.zshrc"
    else
        print_warning "LaTeX: not found (PDF/DOCX export disabled)"
    fi
fi

echo ""

# Final summary
print_header "Setup Complete! 🎉"

echo "Next steps:"
echo ""
echo "1. 查看 CLI 帮助："
printf "   %buv run tiangong-workspace --help%b\n" "$BLUE" "$NC"
echo ""
echo "2. 检查本地 CLI 依赖："
printf "   %buv run tiangong-workspace check%b\n" "$BLUE" "$NC"
echo ""
echo "3. 阅读项目文档："
printf "   %bREADME.md%b\n" "$BLUE" "$NC"
echo ""

if [ "$INSTALL_MODE" = "interactive" ]; then
    if ask_yes_no "Would you like to run the CLI help now?"; then
        uv run tiangong-workspace --help
    fi
fi
