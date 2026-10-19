#!/bin/bash

. /usr/lib/tuned/functions

start() {
    [ "$(/usr/bin/systemctl is-enabled scx_loader.service)" = "enabled" ] && /usr/bin/scxctl switch -m gaming
    return 0
}

stop() {
    [ "$(/usr/bin/systemctl is-enabled scx_loader.service 2>/dev/null)" = "enabled" ] && /usr/bin/scxctl switch -m auto
    return 0
}

process $@
