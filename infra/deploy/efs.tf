##########################
# EFS for media storage. #
##########################
# Resource: aws_efs_file_system
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system

resource "aws_efs_file_system" "media" {
  encrypted = true
  tags = {
    Name = "${local.prefix}-media"
  }
}

resource "aws_security_group" "efs" {
  name   = "${local.prefix}-efs"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 2049
    to_port   = 2049
    protocol  = "tcp"

    security_groups = [
      aws_security_group.ecs_service.id
    ]
  }
}

# Data Source: aws_efs_mount_target
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/efs_mount_target
resource "aws_efs_mount_target" "media_a" {
  file_system_id  = aws_efs_file_system.media.id
  subnet_id       = aws_subnet.private_a.id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "media_b" {
  file_system_id  = aws_efs_file_system.media.id
  subnet_id       = aws_subnet.private_b.id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_access_point" "media" {
  file_system_id = aws_efs_file_system.media.id
  root_directory {
    path = "/api/media"
    creation_info {
      owner_gid   = 101
      owner_uid   = 101
      permissions = "755"
    }
  }
}