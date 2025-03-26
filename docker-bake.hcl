variable "DOCKERHUB_REPO" {
  default = "vjump21848"
}

variable "DOCKERHUB_IMG" {
  default = "faceswap-booth-comfy-runpod-serverless"
}

variable "RELEASE_VERSION" {
  default = "latest"
}

variable "HUGGINGFACE_ACCESS_TOKEN" {
  default = ""
}

group "default" {
  targets = ["base", "reactor"]
}

target "base" {
  context = "."
  dockerfile = "Dockerfile"
  target = "base"
  platforms = ["linux/amd64"]
  tags = ["${DOCKERHUB_REPO}/${DOCKERHUB_IMG}:${RELEASE_VERSION}-base"]
}

target "reactor" {
  context = "."
  dockerfile = "Dockerfile"
  target = "final"
  args = {
    MODEL_TYPE = "reactor"
  }
  tags = ["${DOCKERHUB_REPO}/${DOCKERHUB_IMG}:${RELEASE_VERSION}-reactor"]
  inherits = ["base"]
}

