#!/usr/bin/env python3
"""Sync KingPanel (sources + compiled ex5) into a Parallels VM's MT5 data dir.

Usage:
  python3 sync_to_vm.py                     # -> 汇刃丨工作 (mt5.king.10k.json)
  python3 sync_to_vm.py mt5.matrix.10k.json # -> 矩阵管理

File copy only - never touches VM processes.
"""
import sys
from pathlib import Path

RESEARCH = Path.home() / "Desktop/workspace/project/fx-ea-research"
sys.path.insert(0, str(RESEARCH))

from research_framework.backend import create_backend
from research_framework.config import load_app_config
from research_framework.mt5 import win_join

LOCAL_DIR = Path(__file__).parent / "KingPanel"


def main() -> int:
    config_name = sys.argv[1] if len(sys.argv) > 1 else "mt5.king.10k.json"
    cfg = load_app_config(RESEARCH / "configs" / config_name)
    print(f"target VM: {cfg.backend.vm_name}")

    backend = create_backend(cfg.backend)
    remote_dir = win_join(cfg.backend.data_dir, "MQL5", "Experts", "KingPanel")
    backend.mkdir(remote_dir)

    files = (sorted(LOCAL_DIR.glob("*.mq5")) + sorted(LOCAL_DIR.glob("*.mqh"))
             + sorted(LOCAL_DIR.glob("*.ex5")))
    if not files:
        print("nothing to sync in", LOCAL_DIR)
        return 2
    for src in files:
        backend.write_bytes(win_join(remote_dir, src.name), src.read_bytes())
        print(f"synced {src.name} ({src.stat().st_size} bytes)")

    r = backend.run_powershell(
        f"Get-ChildItem -LiteralPath '{remote_dir}' | "
        "Select-Object Name,Length,LastWriteTime | Format-Table -AutoSize | Out-String")
    print("--- remote listing ---")
    print((r.stdout or "").strip())
    return 0


if __name__ == "__main__":
    sys.exit(main())
