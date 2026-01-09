module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  cluster_name = module.eks.cluster_name

  node_iam_role_use_name_prefix   = false
  node_iam_role_name              = local.name
  create_pod_identity_association = true

  iam_role_source_assume_policy_documents = [join("", data.aws_iam_policy_document.assume_role_with_oidc.*.json)]

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "assume_role_with_oidc" {

  statement {
    effect = "Allow"

    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"

      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}"
      ]
    }

    dynamic "condition" {
      for_each = ["system:serviceaccount:karpenter:karpenter"]
      content {
        test     = "StringEquals"
        variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
        values   = [condition.value]
      }
    }
  }
}

# resource "aws_iam_role" "karpenter_role" {

#   name                 = "karpenter_role"
#   path                 = "/"
#   max_session_duration = 3600

#   permissions_boundary = ""

#   assume_role_policy = join("", data.aws_iam_policy_document.assume_role_with_oidc.*.json)

#   tags = local.tags
# }


resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true
  upgrade_install  = true

  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.8.1"

  set = [
    {
      name  = "settings.clusterName"
      value = local.name
    },
    {
      name  = "settings.clusterEndpoint"
      value = module.eks.cluster_endpoint
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.karpenter.iam_role_arn
    },
    {
      name = "serviceAccount.annotations.eks\\.amazonaws\\.com/sts-regional-endpoints"
      value = "true"
      type = "string"
    },
    {
      name  = "settings.defaultInstanceProfile"
      value = module.karpenter.instance_profile_name
    },
    {
      name  = "settings.interruptionQueueName"
      value = module.karpenter.queue_name
    }
  ]
}

resource "kubernetes_manifest" "ec2nodeclass" {
  manifest = {
    "apiVersion" = "karpenter.k8s.aws/v1"
    "kind" = "EC2NodeClass"
    "metadata" = {
      "name" = "ec2nodeclass"
    }
    "spec" = {
      "amiSelectorTerms" = [
        {
          "alias" = "bottlerocket@latest"
        },
      ]
      "role" = module.karpenter.node_iam_role_name
      "securityGroupSelectorTerms" = [
        {
          "tags" = {
            "karpenter.sh/discovery" = local.name
          }
        },
      ]
      "subnetSelectorTerms" = [
        {
          "tags" = {
            "karpenter.sh/discovery" = local.name
          }
        },
      ]
      "tags" = {
        "karpenter.sh/discovery" = local.name
      }
    }
  }
}

resource "kubernetes_manifest" "nodepool_x86_spot" {
  manifest = {
    "apiVersion" = "karpenter.sh/v1"
    "kind" = "NodePool"
    "metadata" = {
      "name" = "x86-spot"
    }
    "spec" = {
      "disruption" = {
        "consolidateAfter" = "30s"
        "consolidationPolicy" = "WhenEmpty"
      }
      "limits" = {
        "cpu" = 1000
      }
      "template" = {
        "metadata" = {
          "labels" = {
            "capacity-type" = "spot"
          }
        }
        "spec" = {
          "nodeClassRef" = {
            "group" = "karpenter.k8s.aws"
            "kind" = "EC2NodeClass"
            "name" = "ec2nodeclass"
          }
          "requirements" = [
            {
              "key" = "karpenter.k8s.aws/instance-family"
              "operator" = "In"
              "values" = [
                "t3",
              ]
            },
            {
              "key" = "karpenter.k8s.aws/instance-cpu"
              "operator" = "In"
              "values" = [
                "1",
                "2",
              ]
            },
            {
              "key" = "karpenter.k8s.aws/instance-hypervisor"
              "operator" = "In"
              "values" = [
                "nitro",
              ]
            },
            {
              "key" = "karpenter.sh/capacity-type"
              "operator" = "In"
              "values" = [
                "spot",
              ]
            },
          ]
        }
      }
    }
  }
}

resource "kubernetes_manifest" "nodepool_x86_on_demand" {
  manifest = {
    "apiVersion" = "karpenter.sh/v1"
    "kind" = "NodePool"
    "metadata" = {
      "name" = "x86-on-demand"
    }
    "spec" = {
      "disruption" = {
        "consolidateAfter" = "30s"
        "consolidationPolicy" = "WhenEmpty"
      }
      "limits" = {
        "cpu" = 1000
      }
      "template" = {
        "metadata" = {
          "labels" = {
            "capacity-type" = "on-demand"
          }
        }
        "spec" = {
          "nodeClassRef" = {
            "group" = "karpenter.k8s.aws"
            "kind" = "EC2NodeClass"
            "name" = "ec2nodeclass"
          }
          "requirements" = [
            {
              "key" = "karpenter.k8s.aws/instance-family"
              "operator" = "In"
              "values" = [
                "t3",
              ]
            },
            {
              "key" = "karpenter.k8s.aws/instance-cpu"
              "operator" = "In"
              "values" = [
                "1",
                "2",
              ]
            },
            {
              "key" = "karpenter.k8s.aws/instance-hypervisor"
              "operator" = "In"
              "values" = [
                "nitro",
              ]
            },
            {
              "key" = "karpenter.sh/capacity-type"
              "operator" = "In"
              "values" = [
                "on-demand",
              ]
            },
          ]
        }
      }
    }
  }
}

resource "kubernetes_manifest" "nodepool_arm64" {
  manifest = {
    "apiVersion" = "karpenter.sh/v1"
    "kind" = "NodePool"
    "metadata" = {
      "name" = "arm64"
    }
    "spec" = {
      "disruption" = {
        "consolidateAfter" = "30s"
        "consolidationPolicy" = "WhenEmpty"
      }
      "limits" = {
        "cpu" = 1000
      }
      "template" = {
        "spec" = {
          "nodeClassRef" = {
            "group" = "karpenter.k8s.aws"
            "kind" = "EC2NodeClass"
            "name" = "ec2nodeclass"
          }
          "requirements" = [
            {
              "key" = "karpenter.k8s.aws/instance-family"
              "operator" = "In"
              "values" = [
                "t4g",
              ]
            },
            {
              "key" = "karpenter.k8s.aws/instance-cpu"
              "operator" = "In"
              "values" = [
                "1",
                "2",
              ]
            },
            {
              "key" = "karpenter.k8s.aws/instance-hypervisor"
              "operator" = "In"
              "values" = [
                "nitro",
              ]
            },
            {
              "key" = "karpenter.sh/capacity-type"
              "operator" = "In"
              "values" = [
                "on-demand",
                "spot",
              ]
            },
          ]
        }
      }
    }
  }
}

