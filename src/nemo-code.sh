#!/bin/bash
# Nemo Code — ClawdWorks sandboxed AI agent
# Wraps Claude Code CLI with NVIDIA free models via LiteLLM proxy

# Don't use set -e — proxy startup can fail transiently and we need graceful handling

# Available models on NVIDIA NIM free tier
MODELS=(
  "moonshotai/kimi-k2.5"
  "z-ai/glm5"
  "nvidia/nemotron-3-super-120b-a12b"
  "minimaxai/minimax-m2.5"
  "qwen/qwen3.5-397b-a17b"
  "openai/gpt-oss-120b"
)

# Start LiteLLM proxy silently (routes CC's Anthropic calls to NVIDIA)
start_proxy() {
  if [ -z "$NVIDIA_API_KEY" ]; then
    echo "ERROR: NVIDIA_API_KEY not set. Get one free at https://build.nvidia.com"
    exit 1
  fi
  source nemo-proxy
  if ! curl -s --max-time 2 http://127.0.0.1:4000/health/readiness > /dev/null 2>&1; then
    echo "ERROR: Proxy failed to start. Retrying..."
    sleep 5
    source nemo-proxy
  fi
  # CC CLI will talk to LiteLLM which translates to NVIDIA
  export ANTHROPIC_BASE_URL="http://127.0.0.1:4000"
  export ANTHROPIC_API_KEY="nemo-code-local"
}

# Parse args
ACTION="${1:-chat}"
shift 2>/dev/null || true

case "$ACTION" in
  chat)
    # Clear screen, show ONLY our splash
    echo -ne "\033[2J\033[H"
    nemo-splash
    start_proxy
    exec claude \
      --model sonnet \
      --dangerously-skip-permissions \
      --bare \
      --system-prompt-file /workspace/CLAUDE.md \
      --add-dir /workspace \
      --mcp-config /workspace/.mcp.json \
      "$@"
    ;;

  run)
    start_proxy
    exec claude -p "$*" \
      --model sonnet \
      --dangerously-skip-permissions \
      --bare \
      --system-prompt-file /workspace/CLAUDE.md \
      --add-dir /workspace \
      --mcp-config /workspace/.mcp.json \
      --output-format text
    ;;

  models)
    echo "Available NVIDIA NIM models (free tier):"
    echo ""
    for i in "${!MODELS[@]}"; do
      if [ "${MODELS[$i]}" = "${NEMO_MODEL}" ]; then
        echo "  * $((i+1))) ${MODELS[$i]}  (active)"
      else
        echo "    $((i+1))) ${MODELS[$i]}"
      fi
    done
    echo ""
    echo "Switch with: NEMO_MODEL=<model-id> clawdworks"
    ;;

  telegram)
    nemo-splash
    start_proxy
    exec node /usr/local/bin/nemo-telegram
    ;;

  help|--help|-h)
    echo "Nemo Code by ClawdWorks"
    echo ""
    echo "Usage: clawdworks [command] [options]  (or: nemo-code [command])"
    echo ""
    echo "Commands:"
    echo "  chat       Interactive chat (default)"
    echo "  run        Headless mode — run a prompt and exit"
    echo "  telegram   Start with Telegram bridge"
    echo "  models     List available NVIDIA models"
    echo "  help       Show this help"
    echo ""
    echo "Environment:"
    echo "  NVIDIA_API_KEY    Your NVIDIA NIM API key (required)"
    echo "  NEMO_MODEL        Model to use (default: moonshotai/kimi-k2.5)"
    echo "  NEMO_MAX_TOKENS   Max output tokens (default: 16384)"
    echo ""
    echo "Examples:"
    echo "  clawdworks                          # Start chatting"
    echo "  clawdworks run 'explain this code'  # One-shot prompt"
    echo "  clawdworks telegram                 # Telegram bridge"
    echo "  NEMO_MODEL=z-ai/glm5 clawdworks    # Use GLM-5"
    ;;

  *)
    echo "Unknown command: $ACTION"
    echo "Run 'clawdworks help' for usage"
    exit 1
    ;;
esac
