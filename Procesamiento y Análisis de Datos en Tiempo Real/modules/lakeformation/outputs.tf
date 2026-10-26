output "database_name" {
  description = "Name of the Glue Data Catalog database governed by Lake Formation."
  value       = aws_glue_catalog_database.this.name
}

output "database_arn" {
  description = "ARN of the Glue Data Catalog database."
  value       = aws_glue_catalog_database.this.arn
}

output "registered_location_arn" {
  description = "ARN of the S3 location registered in Lake Formation."
  value       = aws_lakeformation_resource.this.arn
}

output "registration_role_arn" {
  description = "ARN of the IAM role used to access the registered S3 location (null if service-linked or external role is used)."
  value       = var.create_registration_role ? aws_iam_role.register[0].arn : null
}

output "table_names" {
  description = "Map of created Glue table logical keys to their table names."
  value       = { for k, t in aws_glue_catalog_table.this : k => t.name }
}
