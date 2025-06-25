FROM python:3.12-slim AS runtime

WORKDIR /workspace
COPY ../../../var/tmp/pruning/orchestrate.py ./

# COPY requirements.txt .
# RUN pip install --no-cache-dir -r requirements.txt

# ---- 3. default command ----------------------------------------------------
ENTRYPOINT ["python3", "/workspace/orchestrate.py"]
