#!/system/bin/sh
# Wrapper KABE — executa acao e sai (sem autenticacao)
# Uso: kabe_wrap.sh <choice> <script>

_CHOICE="$1"
_SCRIPT="$2"

if [ -z "$_CHOICE" ] || [ -z "$_SCRIPT" ]; then
  echo "Uso: wrapper <choice> <script>"
  exit 1
fi

chmod 777 "$_SCRIPT"

(
  sleep 2
  echo "$_CHOICE"
  sleep 3
  echo ""
  sleep 2
  echo ""
  sleep 2
  echo "7"
) | sh "$_SCRIPT" > /dev/null 2>&1 &

_PID=$!

sleep 30

kill -9 $_PID 2>/dev/null
pkill -9 -f "$(basename $_SCRIPT)" 2>/dev/null

exit 0
