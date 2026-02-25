
resource "aws_security_group" "bastion_sg" {
  name   = "bastion-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "bastion-sg" })
}

resource "aws_instance" "bastion" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.public_subnet_id
  key_name      = var.key_name

  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true

  # Wait for the instance to pass EC2 status checks before Terraform marks it ready
  timeouts {
    create = "10m"
  }

  tags = merge(var.common_tags, {
    Name = "bastion-host"
  })
}

resource "null_resource" "copy_key" {
  triggers = {
    bastion_id = aws_instance.bastion.id
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = var.ssh_private_key
    host        = aws_instance.bastion.public_ip

    # Increase timeout so Terraform keeps retrying SSH until the instance is ready
    timeout     = "5m"
    agent       = false
  }

  # Wait for SSH to become available before copying the key
  provisioner "remote-exec" {
    inline = [
      "echo 'SSH is ready - bastion host is up!'"
    ]
  }

  provisioner "file" {
    source      = var.ssh_key_path
    destination = "/home/ubuntu/one__click.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 400 /home/ubuntu/one__click.pem",
      "echo 'Key copied and permissions set successfully'"
    ]
  }
}
