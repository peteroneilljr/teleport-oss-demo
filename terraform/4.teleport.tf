resource "aws_instance" "cluster" {
  key_name                    = aws_key_pair.ssh.key_name
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.medium"
  subnet_id                   = module.vpc.public_subnets[0]

  vpc_security_group_ids      = [
    module.vpc.default_security_group_id,
  ]

  iam_instance_profile = aws_iam_instance_profile.console_access.name

  user_data_replace_on_change = true
  user_data = templatefile("./teleport_startup_script.sh",{
    teleport_cluster_name = var.teleport_cluster_name
    teleport_version = var.teleport_version
    teleport_email = var.teleport_email
    aws_route53_zone = var.aws_route53_zone
    gh_client_id = var.gh_client_id
    gh_client_secret = var.gh_client_secret
    gh_org_name = var.gh_org_name
    gh_team_name = var.gh_team_name
    aws_role_read_online = aws_iam_role.teleport_assume_ro.arn
  })

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    encrypted = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      ami,
    ]
  }
}

# ---------------------------------------------------------------------------- #
# AMI Lookup
# ---------------------------------------------------------------------------- #  
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}