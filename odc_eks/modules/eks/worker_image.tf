# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# We utilize a Terraform local here to simplify Base64 encoding this
# information into the AutoScaling Launch Template.
# More information: https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html
locals {
  eks-node-userdata = <<USERDATA
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="BOUNDARY"

--BOUNDARY
Content-Type: application/node.eks.aws

---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: ${aws_eks_cluster.eks.name}
    apiServerEndpoint: ${aws_eks_cluster.eks.endpoint}
    certificateAuthority: ${aws_eks_cluster.eks.certificate_authority[0].data}
    cidr: ${aws_eks_cluster.eks.kubernetes_network_config[0].service_ipv4_cidr}
  kubelet:
    flags:
      - --node-labels=nodegroup=${var.node_group_name},nodetype=ondemand

${var.extra_userdata}

--BOUNDARY--
USERDATA

  eks-spot-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
# Get instance and ami id from the aws ec2 metadate endpoint
id=$(curl http://169.254.169.254/latest/meta-data/instance-id -s)
ami=$(curl http://169.254.169.254/latest/meta-data/ami-id -s)
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.eks.endpoint}' --b64-cluster-ca '${aws_eks_cluster.eks.certificate_authority[0].data}' '${aws_eks_cluster.eks.id}' ${var.extra_bootstrap_args} \
--kubelet-extra-args \
  "--node-labels=cluster=${aws_eks_cluster.eks.id},nodegroup=${var.node_group_name},nodetype=spot,instance-id=$id,ami-id=$ami \
   ${var.extra_kubelet_args}"
${var.extra_userdata}
USERDATA

}

resource "aws_launch_template" "node" {
  name_prefix   = aws_eks_cluster.eks.id
  image_id      = var.ami_image_id
  user_data     = base64encode(local.eks-node-userdata)
  instance_type = var.default_worker_instance_type

  metadata_options {
    http_endpoint               = lookup(var.metadata_options, "http_endpoint", null)
    http_tokens                 = lookup(var.metadata_options, "http_tokens", null)
    http_put_response_hop_limit = lookup(var.metadata_options, "http_put_response_hop_limit", null)
    http_protocol_ipv6          = lookup(var.metadata_options, "http_protocol_ipv6", null)
    instance_metadata_tags      = lookup(var.metadata_options, "instance_metadata_tags", null)
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.eks_node.id
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.eks_node.id]
    delete_on_termination       = true
  }

  lifecycle {
    create_before_destroy = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      encrypted   = var.volume_encrypted != null ? var.volume_encrypted : null
      volume_size = var.volume_size
      volume_type = var.volume_type != "" ? var.volume_type : null
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${aws_eks_cluster.eks.id}-default"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = "${aws_eks_cluster.eks.id}-default"
    }
  }
}

resource "aws_launch_template" "spot" {
  count         = var.spot_nodes_enabled ? 1 : 0
  name_prefix   = aws_eks_cluster.eks.id
  image_id      = var.ami_image_id
  user_data     = base64encode(local.eks-spot-userdata)
  instance_type = var.default_worker_instance_type

  metadata_options {
    http_endpoint               = lookup(var.metadata_options, "http_endpoint", null)
    http_tokens                 = lookup(var.metadata_options, "http_tokens", null)
    http_put_response_hop_limit = lookup(var.metadata_options, "http_put_response_hop_limit", null)
    http_protocol_ipv6          = lookup(var.metadata_options, "http_protocol_ipv6", null)
    instance_metadata_tags      = lookup(var.metadata_options, "instance_metadata_tags", null)
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.eks_node.id
  }

  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price = var.max_spot_price
    }
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.eks_node.id]
    delete_on_termination       = true
  }

  lifecycle {
    create_before_destroy = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      encrypted   = var.volume_encrypted != null ? var.volume_encrypted : null
      volume_size = var.spot_volume_size
      volume_type = var.volume_type != "" ? var.volume_type : null
    }
  }
}
