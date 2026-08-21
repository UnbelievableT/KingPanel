#!/usr/bin/env python3
"""Compile KingPanel on the 矩阵管理 Parallels VM via the fx-ea-research framework.

Usage: python3 compile_on_matrix.py
Deploys KingPanel/*.mq5|.mqh -> VM MQL5\\Experts\\KingPanel\\, compiles with
MetaEditor64 /compile, prints the compile log, pulls KingPanel.ex5 back here.
Compile only - never touches terminal64/metatester64 processes.
"""
import subprocess
import sys
from pathlib import Path

RESEARCH = Path.home() / "Desktop/workspace/project/fx-ea-research"
sys.path.insert(0, str(RESEARCH))

from research_framework.backend import create_backend
from research_framework.config import load_app_config
from research_framework.mt5 import compile_log_ok, decode_text, win_join

LOCAL_DIR = Path(__file__).parent / "KingPanel"


def main() -> int:
    # static checks first: MetaEditor compiles these defects cleanly, they
    # only surface as wrong pixels or wrong numbers at runtime
    lint = Path(__file__).parent / "lint.py"
    if lint.exists():
        rc = subprocess.run([sys.executable, str(lint)]).returncode
        if rc != 0:
            print("lint failed - not deploying")
            return rc

    # optional argv: config json name (default matrix; mt5.king.10k.json = 汇刃丨工作)
    config_name = sys.argv[1] if len(sys.argv) > 1 else "mt5.matrix.10k.json"
    cfg = load_app_config(RESEARCH / "configs" / config_name)
    print(f"target VM: {cfg.backend.vm_name}")
    backend = create_backend(cfg.backend)

    remote_dir = win_join(cfg.backend.data_dir, "MQL5", "Experts", "KingPanel")
    backend.mkdir(remote_dir)

    sources = sorted(LOCAL_DIR.glob("*.mq5")) + sorted(LOCAL_DIR.glob("*.mqh"))
    if not sources:
        print("no sources found in", LOCAL_DIR)
        return 2
    for src in sources:
        dst = win_join(remote_dir, src.name)
        backend.write_bytes(dst, src.read_bytes())
        print(f"deployed {src.name} -> {dst}")

    main_win = win_join(remote_dir, "KingPanel.mq5")
    log_win = win_join(remote_dir, "KingPanel.compile.log")
    ex5_win = win_join(remote_dir, "KingPanel.ex5")
    for stale in (log_win, ex5_win):
        if backend.exists(stale):
            backend.run_powershell(f"Remove-Item -LiteralPath '{stale}' -Force")

    print("compiling...")
    result = backend.run_exe(
        cfg.backend.metaeditor_path,
        [f'/compile:"{main_win}"', f'/log:"{log_win}"'],
        timeout=180,
    )
    # MetaEditor may return while codegen is still running: poll until the
    # log carries a final "N errors" verdict or an error line, max 90s.
    import re as _re
    import time as _time

    log_text = (result.stdout or "") + "\n" + (result.stderr or "")
    for _ in range(180):
        if backend.exists(log_win):
            data = backend.read_bytes(log_win)
            if data:
                log_text = decode_text(data)
                low = log_text.lower()
                if _re.search(r"\b\d+\s+error", low) or " : error" in low:
                    break
        _time.sleep(0.5)

    # keep the log readable: drop include/progress noise
    keep = [ln for ln in log_text.splitlines()
            if ": information: including" not in ln
            and ": information: generating code" not in ln
            and ln.strip()]
    print("=" * 60)
    print("\n".join(keep))
    print("=" * 60)

    ok = compile_log_ok(log_text) and backend.exists(ex5_win)
    if ok:
        data = backend.read_bytes(ex5_win)
        out = LOCAL_DIR / "KingPanel.ex5"
        out.write_bytes(data)
        print(f"OK: pulled KingPanel.ex5 ({len(data)} bytes) -> {out}")
        return 0
    print("COMPILE FAILED")
    return 1


if __name__ == "__main__":
    sys.exit(main())
