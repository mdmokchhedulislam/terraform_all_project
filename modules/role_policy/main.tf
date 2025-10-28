
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
