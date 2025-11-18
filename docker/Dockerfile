# Use the latest official Ubuntu image from Docker Hub
FROM mambaorg/micromamba:2.3.3
LABEL maintainer="Ziad Al Bkhetan <ziad.albkhetan@gmail.come>"
LABEL version="1.0.3"
LABEL description="A Docker image for running Free Bindcraft "
LABEL org.opencontainers.image.authors="Ziad Al Bkhetan"
LABEL org.opencontainers.image.licenses="MIT"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ARG MAMBA_DOCKERFILE_ACTIVATE=1

WORKDIR /
USER root
RUN mkdir -p /work && chown -R mambauser:mambauser /work
USER mambauser
WORKDIR /work
RUN micromamba install -y -n base -c conda-forge git wget gcc && micromamba clean -a -y
RUN git clone --branch v1.0.3 --depth 1 https://github.com/cytokineking/FreeBindCraft
WORKDIR FreeBindCraft

# making it work for micromamba by replacing conda by micromamba and installing to the base env

RUN sed -i '/\$pkg_manager create --name BindCraft/s/^/#/' install_bindcraft.sh
RUN sed -i '/conda env list | grep -w/s/^/#/' install_bindcraft.sh
RUN sed -i '/source ${CONDA_BASE}\/bin\/activate/s/^/#/' install_bindcraft.sh
RUN sed -i '/[[:space:]]*\[ "\$CONDA_DEFAULT_ENV" = "BindCraft" \]/s/^/#/' install_bindcraft.sh
RUN sed -i 's/\<conda\>/micromamba/g' install_bindcraft.sh
RUN sed -i 's/\<micromamba-forge\>/conda-forge/g' install_bindcraft.sh

RUN bash install_bindcraft.sh --cuda '12.4' --pkg_manager 'micromamba' --no-pyrosetta
ENV PATH="$PATH:/work/FreeBindCraft"
ENV PYTHONPATH="${PYTHONPATH:-}/work/FreeBindCraft"
# Set default command
CMD ["python", "-u", "bindcraft.py"]