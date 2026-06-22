import os
import subprocess
import sys

port = os.environ.get("PORT", "8000")
print(f"Starting uvicorn on port {port}", flush=True)

subprocess.run([
    sys.executable, "-m", "uvicorn",
    "backend.app:app",
    "--host", "0.0.0.0",
    "--port", port,
    "--workers", "1",
], check=True)
