ami_id        = "ami-0c398cb65a93047f2"
instance_type = "t2.micro"
key_name      = "one__click"
ssh_cidr      = ["0.0.0.0/0"]

common_tags = {
  Project     = "terraform-assignment"
  Environment = "dev"
  Owner       = "bhawna"
}

vpc_cidr      = "10.0.0.0/16"
public_cidrs  = ["10.0.1.0/24"]
private_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
alb_name      = "mysql-alb"
asg_name      = "mysql-asg"
ansible_user  = "ubuntu"
ssh_key_path  = "/tmp/one__click.pem"
alb_port      = 80
vpc_name      = "mysql-vpc"
igw_name      = "mysql-igw"
nat_name      = "mysql-nat"

user_data = <<-EOF
  #!/bin/bash
  set -e

  # Update & install prerequisites
  apt-get update -y
  apt-get install -y ca-certificates curl software-properties-common gnupg lsb-release

  # Add Docker GPG key
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  # Add Docker repository
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Install Docker CE
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io

  # Start & enable Docker
  systemctl enable docker
  systemctl start docker

  # Add ubuntu user to docker group
  usermod -aG docker ubuntu

  # Install Docker Compose v2
  curl -fsSL https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose

  echo "Docker installation complete!" >> /var/log/user-data.log
EOF
