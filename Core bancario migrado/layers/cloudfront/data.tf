###############################################
# Data Sources
###############################################

data "aws_caller_identity" "current" {
  provider = aws.project
}

data "aws_region" "current" {
  provider = aws.project
}

###############################################
# ALB interno creado por el Ingress del layer apps
# (grupo cb-prod-public, load-balancer-name = cb-prod-alb-public)
# Camino 2: resolución por nombre determinístico.
###############################################

data "aws_lb" "public" {
  provider = aws.project
  name     = var.alb_name
}
