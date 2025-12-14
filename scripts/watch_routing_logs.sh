#!/usr/bin/env bash
set -euo pipefail

# Tail semantic-router / Envoy logs and show only routing-related lines.
# Usage (in another terminal):
#   ./scripts/demo/watch_routing_logs.sh
#
# You can override paths:
#   ROUTER_LOG=~/logs/semantic-router.log ENVOY_LOG=~/logs/envoy.log ./scripts/demo/watch_routing_logs.sh

ROUTER_LOG=${ROUTER_LOG:-"$HOME/logs/semantic-router.log"}
ENVOY_LOG=${ENVOY_LOG:-"$HOME/logs/envoy.log"}

if [[ ! -f "$ROUTER_LOG" ]]; then
  echo "Router log not found at: $ROUTER_LOG"
fi
if [[ ! -f "$ENVOY_LOG" ]]; then
  echo "Envoy log not found at: $ENVOY_LOG"
fi

# Colors for highlighting
CLASS_COLOR='\033[1;36m'    # bright cyan
DECISION_COLOR='\033[1;35m' # bright magenta
ROUTING_COLOR='\033[1;32m'  # bright green
ENDPOINT_COLOR='\033[1;33m' # bright yellow
CACHE_COLOR='\033[1;34m'    # bright blue
ENVOY_COLOR='\033[1;90m'    # bright gray
INFO_COLOR='\033[1;37m'     # bright white
RESET_COLOR='\033[0m'

printf "${INFO_COLOR}Routing log watcher${RESET_COLOR}\n"
printf "  Router log: %s\n" "$ROUTER_LOG"
printf "  Envoy  log: %s\n" "$ENVOY_LOG"
printf "\n"
printf "Highlighting key events:\n"
printf "  ${CLASS_COLOR}[CLASS]${RESET_COLOR}     Keyword-based classification (which rule matched)\n"
printf "  ${DECISION_COLOR}[DECISION]${RESET_COLOR}  Decision engine result (which decision fired)\n"
printf "  ${ROUTING_COLOR}[ROUTING]${RESET_COLOR}   Auto model routing + selected backend model\n"
printf "  ${ENDPOINT_COLOR}[ENDPOINT]${RESET_COLOR}  Selected vLLM endpoint (host:port)\n"
printf "  ${CACHE_COLOR}[CACHE]${RESET_COLOR}     Semantic cache hits\n"
printf "  ${ENVOY_COLOR}[ENVOY]${RESET_COLOR}     Envoy headers with selected model/endpoint\n"
printf "\nPress Ctrl+C to stop.\n\n"

highlight_router() {
  tail -F "$ROUTER_LOG" 2>/dev/null | while read -r line; do
    case "$line" in
      *"Keyword-based classification matched rule"*)
        printf "%b\n" "${CLASS_COLOR}[CLASS]${RESET_COLOR}    $line"
        ;;
      *"Signal evaluation results"*)
        printf "%b\n" "${INFO_COLOR}[SIGNALS]${RESET_COLOR}  $line"
        ;;
      *"Decision evaluation result"*)
        printf "%b\n" "${DECISION_COLOR}[DECISION]${RESET_COLOR} $line"
        ;;
      *"Decision Evaluation Result"*)
        printf "%b\n" "${DECISION_COLOR}[DECISION]${RESET_COLOR} $line"
        ;;
      *"Using Auto Model Selection"*)
        printf "%b\n" "${ROUTING_COLOR}[ROUTING]${RESET_COLOR}  $line"
        ;;
      *"Selected endpoint address"*)
        printf "%b\n" "${ENDPOINT_COLOR}[ENDPOINT]${RESET_COLOR} $line"
        ;;
      *"cache_hit"*)
        printf "%b\n" "${CACHE_COLOR}[CACHE]${RESET_COLOR}    $line"
        ;;
      *)
        ;;
    esac
  done
}

highlight_envoy() {
  tail -F "$ENVOY_LOG" 2>/dev/null | while read -r line; do
    case "$line" in
      *"x-vsr-destination-endpoint"*|*"x-selected-model"*)
        printf "%b\n" "${ENVOY_COLOR}[ENVOY]${RESET_COLOR}    $line"
        ;;
      *)
        ;;
    esac
  done
}

if [[ -f "$ROUTER_LOG" ]]; then
  highlight_router &
fi

if [[ -f "$ENVOY_LOG" ]]; then
  highlight_envoy &
fi

wait

