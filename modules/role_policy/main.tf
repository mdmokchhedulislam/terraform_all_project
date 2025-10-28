
# role for junior devops engineer 

resource "aws_iam_role" "junior_devops_role" {
  name = "junior-devops-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::123456789012:user/junior-devops"
        }
      }
    ]
  })
}


# policy for junior devops engineer 

resource "aws_iam_role_policy" "junior_devops_policy" {
  name = "junior-devops-policy"
  role = aws_iam_role.junior_devops_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ecs:UpdateService",       
          "ecs:DescribeServices"
        ]
        Resource = "*"
      }
    ]
  })
}


resource "aws_iam_instance_profile" "junior_devops_profile" {
  name = "junior-devops-profile"
  role = aws_iam_role.junior_devops_role.name
}

resource "aws_instance" "jenkins" {
  ami                    = var.ami_id
  instance_type          = "t3.medium"
#   vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.junior_devops_profile.name
  key_name               = var.key_name

  tags = {
    Name = "Jenkins-Server"
    Environment = "production"
  }
}