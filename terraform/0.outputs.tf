output teleport_cluster_ssh {
  value       = <<EOF
    ssh -i ${local_sensitive_file.ssh.filename} \
      -o UserKnownHostsFile=/dev/null \
      -o StrictHostKeyChecking=no \
      ec2-user@${aws_eip.cluster.public_ip}
  EOF
}
output teleport_cluster_fqdn {
  value       = aws_route53_record.cluster.fqdn
}
output teleport_tsh_login {
  value       = "tsh login --proxy=${var.teleport_cluster_name}.${var.aws_route53_zone}:443 --auth=github"
}
output teleport_check_certificate {
  value       = <<EOF
    openssl s_client -connect "${var.teleport_cluster_name}.${var.aws_route53_zone}:443" \
      -servername "${var.teleport_cluster_name}.${var.aws_route53_zone}" -showcerts -status
  EOF
}

data "aws_instance" "cluster" {
  instance_id = aws_instance.cluster.id
  get_user_data = true
}
output teleport_startup_script {
  value       = base64decode(data.aws_instance.cluster.user_data_base64)
  sensitive = true
}
