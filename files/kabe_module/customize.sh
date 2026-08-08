#!/system/bin/sh
# ═══════════════════════════════════════════════════════
#   KABE PRIVATE — Installer
# ═══════════════════════════════════════════════════════

ui_print ""
ui_print "  ============================================"
ui_print "          KABE PRIVATE"
ui_print "  ============================================"
ui_print ""

# Permissoes dos scripts
chmod 755 $MODPATH/service.sh
chmod 755 $MODPATH/post-fs-data.sh
chmod 755 $MODPATH/system/bin/kabe-agent
chmod 755 $MODPATH/system/bin/kabe-keygen
chmod 755 $MODPATH/system/bin/kabe-server
chmod 755 $MODPATH/system/bin/kabe-setup
chmod 755 $MODPATH/system/bin/kabe-webconfig

ui_print "  Instalado com sucesso!"
ui_print "  Reinicie o celular e configure:"
ui_print "    - Web config: http://<ip>:9090"
ui_print "    - Ou no terminal: kabe-setup"
ui_print ""
