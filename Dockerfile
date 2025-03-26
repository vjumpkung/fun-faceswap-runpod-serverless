# Stage 1: Base image with common dependencies
FROM nvidia/cuda:12.4.1-base-ubuntu22.04 as base

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1 
# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

ARG PYTHON_VERSION="3.10"

# Install Python, git and other necessary tools
RUN ln -snf /usr/share/zoneinfo/$CONTAINER_TIMEZONE /etc/localtime && echo $CONTAINER_TIMEZONE > /etc/timezone
RUN apt-get update --yes && \
  apt-get install --yes --no-install-recommends build-essential git curl wget gcc g++ libgl1 software-properties-common unzip && \
  add-apt-repository ppa:deadsnakes/ppa && \
  apt-get update --yes && \
  apt-get install --yes --no-install-recommends "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" "python${PYTHON_VERSION}-tk" && \
  apt-get autoremove -y && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  echo "en_US.UTF-8 UTF-8" > /etc/locale.gen

# Set up Python and pip
RUN ln -s /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
  rm /usr/bin/python3 && \
  ln -s /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
  curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
  python get-pip.py


# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install comfy-cli
RUN pip install comfy-cli

# Install ComfyUI
RUN /usr/bin/yes | comfy --workspace /comfyui install --cuda-version 12.4 --nvidia --version 0.3.27

# Change working directory to ComfyUI
WORKDIR /comfyui

# Install runpod
RUN pip install runpod requests

# Support for the network volume
ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# Add scripts
ADD src/start.sh src/restore_snapshot.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh /restore_snapshot.sh

# Download Reactor Custom Node and Models 
RUN cd /comfyui/custom_nodes && git clone https://github.com/Gourieff/ComfyUI-ReActor.git && cd ComfyUI-ReActor && python install.py && cd /comfyui
RUN cd /comfyui/custom_nodes && git clone https://github.com/za-wa-n-go/ComfyUI_Zwng_Nodes.git && cd /comfyui
RUN pip cache purge

# Optionally copy the snapshot file
ADD *snapshot*.json /

# Restore the snapshot to install custom nodes
RUN /restore_snapshot.sh

# Start container
CMD ["/start.sh"]

# Stage 2: Download models
FROM base as downloader

ARG HUGGINGFACE_ACCESS_TOKEN
ARG MODEL_TYPE

# Change working directory to ComfyUI
WORKDIR /comfyui

# Create necessary directories
RUN mkdir -p models/checkpoints models/vae models/facedetection models/facerestore_models models/facexlib models/insightface models/onnx models/reswapper models/nsfw_detector/vit-base-nsfw-detector

RUN wget -q -O models/facerestore_models/GFPGANv1.3.pth https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/facerestore_models/GFPGANv1.3.pth && \
  wget -q -O models/facerestore_models/GFPGANv1.4.pth https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/facerestore_models/GFPGANv1.4.pth && \
  wget -q -O models/facerestore_models/codeformer-v0.1.0.pth https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/facerestore_models/codeformer-v0.1.0.pth && \
  wget -q -O models/facerestore_models/GPEN-BFR-512.onnx https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/facerestore_models/GPEN-BFR-512.onnx && \
  wget -q -O models/insightface/inswapper_128.onnx https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/inswapper_128.onnx && \
  wget -q -O models/reswapper/reswapper_256.onnx https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/reswapper_256.onnx && \
  wget -q -O models/facedetection/detection_Resnet50_Final.pth https://huggingface.co/darkeril/collection/resolve/main/detection_Resnet50_Final.pth && \
  wget -q -O models/facexlib/detection_Resnet50_Final.pth https://huggingface.co/darkeril/collection/resolve/main/detection_Resnet50_Final.pth && \
  wget -q -O models/facexlib/parsing_bisenet.pth https://huggingface.co/caocaocoa/1111/resolve/4f49a96a8919398af6e6373ed7dd6e323fefcdb8/parsing_bisenet.pth && \
  wget -q -O models/facedetection/parsing_parsenet.pth https://huggingface.co/gmk123/GFPGAN/resolve/main/parsing_parsenet.pth && \
  wget -q -O models/facedetection/yolov5l-face.pth https://huggingface.co/martintomov/comfy/resolve/main/facedetection/yolov5l-face.pth && \
  wget -q -O models/nsfw_detector/vit-base-nsfw-detector/config.json https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/config.json && \
  wget -q -O models/nsfw_detector/vit-base-nsfw-detector/confusion_matrix.png https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/confusion_matrix.png && \
  wget -q -O models/nsfw_detector/vit-base-nsfw-detector/model.safetensors https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/model.safetensors && \
  wget -q -O models/nsfw_detector/vit-base-nsfw-detector/preprocessor_config.json https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/preprocessor_config.json && \
  wget -q -O models/insightface/buffalo_l.zip https://github.com/deepinsight/insightface/releases/download/v0.7/buffalo_l.zip && \
  unzip -q models/insightface/buffalo_l.zip -d models/insightface && \ 
  rm models/insightface/buffalo_l.zip

# Stage 3: Final image
FROM base as final

# Copy models from stage 2 to the final image
COPY --from=downloader /comfyui/models /comfyui/models

# Start container
CMD ["/start.sh"]