# Create a PinPoint app for every app client
resource "aws_pinpoint_app" "pinpoint_app" {
  for_each = var.enable_pinpoint ? var.app_clients : {}
  name     = each.key
}

# Conditionally create role if pin point is enabled in module
resource "aws_iam_role" "pinpoint_role" {
  count = var.enable_pinpoint ? 1 : 0
  name  = "pinpoint-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "cognito-idp.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "pinpoint_app_role" {
  name = "role_policy"
  role = aws_iam_role.pinpoint_role.id

  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "mobiletargeting:UpdateEndpoint",
        "mobiletargeting:PutItems"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:mobiletargeting:*:${data.aws_caller_identity.current.account_id}:apps/*"
    }
  ]
}
EOF
}