"""Subprocess execution for running install script"""

import asyncio
from typing import List, Callable, Optional


async def run_installation(
    script_dir: str,
    options: List[str],
    uninstall: bool = False,
    output_callback: Optional[Callable[[str], None]] = None,
) -> int:
    """
    Execute install script and stream output in real-time.

    Args:
        script_dir: Directory containing install
        options: List of option IDs to install/uninstall
        uninstall: If True, run in uninstall mode
        output_callback: Function to call with each output line

    Returns:
        Exit code from the process
    """
    # Build command
    cmd = [f"{script_dir}/install"]
    if uninstall:
        cmd.append("uninstall")
    cmd.extend(options)

    # Create subprocess
    process = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
        cwd=script_dir,
    )

    # Stream output line by line
    while True:
        line = await process.stdout.readline()
        if not line:
            break
        decoded = line.decode("utf-8", errors="replace")
        if output_callback:
            output_callback(decoded)

    # Wait for process to complete
    await process.wait()
    return process.returncode


def build_command(
    script_dir: str,
    options: List[str],
    uninstall: bool = False
) -> List[str]:
    """Build the install command for display purposes"""
    cmd = [f"{script_dir}/install"]
    if uninstall:
        cmd.append("uninstall")
    cmd.extend(options)
    return cmd
