FROM python:3.11-slim

WORKDIR /workspace

# context = project root, so this path is inside it
COPY ./orchestrate.py .
COPY var/tmp/helpers/preprocess_bindings.py .
COPY var/tmp/helpers/make_lang_sets.py .

#ENTRYPOINT ["python3", "orchestrate.py"]
ENTRYPOINT ["bin/bash"]
