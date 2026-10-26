###########################################
# CI/CD Pipeline (single account)
# CodePipeline (Source -> Build) + CodeBuild that builds the
# container image, pushes it to ECR, and updates the EKS deployment.
# All resources run in the same account (provider = aws.project).
###########################################

# ==========================================================================
# IAM Role for CodePipeline
# ==========================================================================
resource "aws_iam_role" "pipeline" {
  provider = aws.project
  count    = var.create_pipeline ? 1 : 0

  name = local.pipeline_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CodePipelineAssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    { Name = local.pipeline_role_name },
    var.additional_tags
  )
}

resource "aws_iam_role_policy" "pipeline" {
  provider = aws.project
  count    = var.create_pipeline ? 1 : 0

  name = "${local.pipeline_role_name}-policy"
  role = aws_iam_role.pipeline[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Artifacts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = [
          "arn:aws:s3:::${var.pipeline_artifact_bucket_name}",
          "arn:aws:s3:::${var.pipeline_artifact_bucket_name}/*"
        ]
      },
      {
        Sid      = "CodeStarConnection"
        Effect   = "Allow"
        Action   = ["codestar-connections:UseConnection"]
        Resource = [var.codestar_connection_arn]
      },
      {
        Sid      = "CodeBuild"
        Effect   = "Allow"
        Action   = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"]
        Resource = [aws_codebuild_project.this[0].arn]
      }
    ]
  })
}

# ==========================================================================
# IAM Role for CodeBuild
# ==========================================================================
resource "aws_iam_role" "codebuild" {
  provider = aws.project
  count    = var.create_pipeline ? 1 : 0

  name = local.codebuild_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CodeBuildAssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    { Name = local.codebuild_role_name },
    var.additional_tags
  )
}

resource "aws_iam_role_policy" "codebuild" {
  provider = aws.project
  count    = var.create_pipeline ? 1 : 0

  name = "${local.codebuild_role_name}-policy"
  role = aws_iam_role.codebuild[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.codebuild_name}*",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.codebuild_name}*:*"
        ]
      },
      {
        Sid      = "S3Artifacts"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]
        Resource = ["arn:aws:s3:::${var.pipeline_artifact_bucket_name}/*"]
      },
      {
        Sid      = "CodeStarConnection"
        Effect   = "Allow"
        Action   = ["codestar-connections:UseConnection"]
        Resource = [var.codestar_connection_arn]
      },
      {
        # checkov:skip=CKV_AWS_288: ecr:GetAuthorizationToken solo admite "*" como recurso (requisito de la API de ECR).
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = ["*"]
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = [aws_ecr_repository.this.arn]
      },
      {
        Sid      = "EKSDescribe"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = ["arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"]
      }
    ]
  })
}

# ==========================================================================
# EKS Access Entry for the CodeBuild role
# Grants kube edit rights scoped to the microservice namespace so the
# build can update the deployment. Uses the EKS Access Entries API
# (no aws-auth editing).
# ==========================================================================
resource "aws_eks_access_entry" "codebuild" {
  provider = aws.project
  count    = var.create_pipeline && var.grant_eks_access ? 1 : 0

  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.codebuild[0].arn

  tags = merge(
    { Name = local.codebuild_role_name },
    var.additional_tags
  )
}

resource "aws_eks_access_policy_association" "codebuild" {
  provider = aws.project
  count    = var.create_pipeline && var.grant_eks_access ? 1 : 0

  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.codebuild[0].arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = [var.namespace]
  }

  depends_on = [aws_eks_access_entry.codebuild]
}

# ==========================================================================
# CodeBuild Project
# ==========================================================================
resource "aws_codebuild_project" "this" {
  provider = aws.project
  count    = var.create_pipeline ? 1 : 0

  name         = local.codebuild_name
  description  = "Build and deploy microservice ${var.service_name}"
  service_role = aws_iam_role.codebuild[0].arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = var.pipeline_compute_type
    image           = var.pipeline_build_image
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "ECR_REPO_NAME"
      value = local.ecr_repo_name
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "ECR_REPO_URL"
      value = aws_ecr_repository.this.repository_url
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "CLUSTER_NAME"
      value = var.cluster_name
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "K8S_NAMESPACE"
      value = var.namespace
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "SERVICE_NAME"
      value = var.service_name
      type  = "PLAINTEXT"
    }

    dynamic "environment_variable" {
      for_each = var.pipeline_environment_variables
      content {
        name  = environment_variable.value.name
        value = environment_variable.value.value
        type  = environment_variable.value.type
      }
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.pipeline_buildspec
  }

  tags = merge(
    { Name = local.codebuild_name },
    var.additional_tags
  )
}

# ==========================================================================
# CodePipeline
# ==========================================================================
resource "aws_codepipeline" "this" {
  provider = aws.project
  count    = var.create_pipeline ? 1 : 0

  name          = local.pipeline_name
  role_arn      = aws_iam_role.pipeline[0].arn
  pipeline_type = "V2"

  artifact_store {
    location = var.pipeline_artifact_bucket_name
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = var.codestar_connection_arn
        FullRepositoryId = var.pipeline_repository
        BranchName       = var.pipeline_branch
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source_output"]

      configuration = {
        ProjectName = aws_codebuild_project.this[0].name
      }
    }
  }

  tags = merge(
    { Name = local.pipeline_name },
    var.additional_tags
  )
}
