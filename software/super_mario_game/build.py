#!/usr/bin/env python3
"""Build the integrated MicroBlaze game application with Vitis."""

import os
import shutil
from pathlib import Path

import vitis


REPO_DIR = Path(__file__).resolve().parents[2]
OUTPUT_DIR = REPO_DIR / "build" / "framebuffer_black"
WORKSPACE = OUTPUT_DIR / "vitis_workspace"
XSA = OUTPUT_DIR / "framebuffer_black.xsa"
SOURCE_DIR = REPO_DIR / "software" / "super_mario_game"
SD_SPI_DIR = REPO_DIR / "software" / "sd_spi"
PLATFORM_NAME = "framebuffer_black_platform"
APP_NAME = "super_mario_game"
DOMAIN_NAME = "microblaze"


def find_xilffs_source() -> Path:
    """Locate the xilffs source shipped with the active Vitis installation."""
    vitis_root = os.environ.get("XILINX_VITIS")
    if not vitis_root:
        raise RuntimeError(
            "XILINX_VITIS is not set; source the Vitis settings script first"
        )

    service_root = (
        Path(vitis_root)
        / "data"
        / "embeddedsw"
        / "lib"
        / "sw_services"
    )
    candidates = sorted(service_root.glob("xilffs_v*/src"))
    if not candidates:
        raise FileNotFoundError(f"xilffs source not found under {service_root}")
    return candidates[-1]


def main() -> None:
    xilffs_src = find_xilffs_source()
    if not XSA.is_file():
        raise FileNotFoundError(f"Build the hardware XSA first: {XSA}")

    # This directory contains generated Vitis state only. Recreate it so the
    # script remains deterministic when the XSA changes.
    if WORKSPACE.is_dir():
        shutil.rmtree(WORKSPACE)
    WORKSPACE.mkdir(parents=True)

    client = vitis.create_client()
    try:
        client.set_workspace(str(WORKSPACE))

        platform = client.create_platform_component(
            name=PLATFORM_NAME, hw_design=str(XSA)
        )
        domain = platform.add_domain(
            name=DOMAIN_NAME, cpu="microblaze_0", os="standalone"
        )
        domain.set_config("os", "standalone_stdin", "axi_uartlite_0")
        domain.set_config("os", "standalone_stdout", "axi_uartlite_0")
        platform.build()

        platform_xpfm = client.find_platform_in_repos(PLATFORM_NAME)
        app = client.create_app_component(
            name=APP_NAME, platform=platform_xpfm, domain=DOMAIN_NAME
        )
        app.import_files(from_loc=str(SOURCE_DIR), files=["main.c"])
        app.import_files(
            from_loc=str(SD_SPI_DIR),
            files=[
                "sd_spi.c",
                "sd_spi.h",
                "sd_spi_diskio.c",
                "sd_spi_diskio.h",
                "xilffs_config.h",
            ],
        )
        app.import_files(from_loc=str(xilffs_src), files=["ff.c"])
        app.import_files(
            from_loc=str(xilffs_src / "include"),
            files=["ff.h", "ffconf.h", "diskio.h", "xilffs.h"],
        )
        app.build()

        elf_candidates = list(
            (WORKSPACE / APP_NAME).glob("build/**/*.elf")
        )
        if len(elf_candidates) != 1:
            raise RuntimeError(
                f"Expected one application ELF, found: {elf_candidates}"
            )

        output_elf = OUTPUT_DIR / "super_mario_game.elf"
        shutil.copy2(elf_candidates[0], output_elf)
        print(f"SUPER_MARIO_GAME_ELF={output_elf}")
    finally:
        vitis.dispose()


if __name__ == "__main__":
    main()
