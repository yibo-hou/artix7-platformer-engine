#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d /tmp/super_mario_fpga_tests.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT

cd "$repo_dir"

iverilog -g2012 -s tb_sprite_frame_stream \
    -o "$test_dir/tb_sprite_frame_stream" \
    rtl/sprite/sprite_frame_stream.sv \
    simulation/sprite/tb_sprite_frame_stream.sv
vvp "$test_dir/tb_sprite_frame_stream"

iverilog -g2012 -s tb_sprite_asset_unpacker \
    -o "$test_dir/tb_sprite_asset_unpacker" \
    rtl/sprite/sprite_asset_unpacker.sv \
    simulation/sprite/tb_sprite_asset_unpacker.sv
vvp "$test_dir/tb_sprite_asset_unpacker"

iverilog -g2012 -s tb_game_hud_overlay \
    -o "$test_dir/tb_game_hud_overlay" \
    rtl/top/framebuffer_black_top.sv \
    simulation/video/tb_game_hud_overlay.sv
vvp "$test_dir/tb_game_hud_overlay"

gcc -std=c11 -Wall -Wextra -Werror \
    -Isoftware/mario_game/test/stubs \
    -Isoftware/mario_game/test \
    -Isoftware/mario_game \
    -Isoftware/include \
    -include software/mario_game/test/mock_support.h \
    '-DMARIO_SPRITE_CTRL_BASEADDR=((uintptr_t)mock_regs)' \
    software/mario_game/mario_game.c \
    software/mario_game/test/test_mario_game.c \
    -o "$test_dir/test_mario_game"
"$test_dir/test_mario_game"

python3 -m py_compile \
    scripts/host/capture_uart.py \
    scripts/host/keyboard_uart.py \
    software/super_mario_game/build.py

echo "PASS: all portable RTL, C, and Python checks"
