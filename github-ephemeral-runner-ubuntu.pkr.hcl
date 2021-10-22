variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_sm_secret_id" {
  type    = string
  default = "test/GitHubRunnerRegistration"
}

variable "aws_sm_secret_name" {
  type    = string
  default = "github_runner_pat_token"
}

variable "github_username" {
  type = string
}

variable "github_repo" {
  type = string
}

packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu-ephemeral" {
  ami_name      = "gh-ephemeral-runner-ubuntu-2004-${var.github_username}-${var.github_repo}"
  instance_type = "t2.micro"
  region        = var.aws_region
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-focal-20.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "ubuntu"
}

build {
  name = "bootstrap-github-ephemeral-runner"
  sources = [
    "source.amazon-ebs.ubuntu-ephemeral"
  ]
  provisioner "shell" {
    environment_vars = [
      "AWS_REGION=${var.aws_region}",
      "AWS_SM_SECRET_ID=${var.aws_sm_secret_id}",
      "AWS_SM_SECRET_NAME=${var.aws_sm_secret_name}",
      "GITHUB_USERNAME=${var.github_username}",
      "GITHUB_REPO=${var.github_repo}"
    ]
    script = "provision-github-runner.sh"
  }
  provisioner "file" {
    source      = "scripts/start-runner.sh"
    destination = "/tmp/start-runner.sh"
  }
  provisioner "file" {
    source      = "scripts/self-destruct.sh"
    destination = "/tmp/self-destruct.sh"
  }
  provisioner "shell" {
    inline = [
      "sudo mv /tmp/start-runner.sh /home/actions/runner/start-runner.sh",
      "sudo mv /tmp/self-destruct.sh /home/actions/runner/self-destruct.sh"
    ]
  }
}
