###########################################
########## Common variables ###############
###########################################

variable "project" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Environment where resources will be deployed"
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Must be dev, qa, or prod."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region where resources will be deployed"
}

variable "name" {
  type        = string
  description = "Functional name for the VPC (funcionalidad segment), e.g. 'core'. Used in resource naming: agat-{env}-vpc-{name}."
  default     = "core"
}

###########################################
############ VPC variables ################
###########################################

variable "cidr_block" {
  type        = string
  description = "The IPv4 CIDR block for the VPC"
  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "Must be valid CIDR"
  }
}

variable "instance_tenancy" {
  type        = string
  description = "A tenancy option for instances launched into the VPC"
  default     = "default"
  validation {
    condition     = can(regex("^(default|dedicated)$", var.instance_tenancy))
    error_message = "Invalid tenancy, must be default or dedicated"
  }
}

variable "enable_dns_hostnames" {
  type        = bool
  description = "A boolean flag to enable/disable DNS hostnames in the VPC"
  default     = true
}

variable "enable_dns_support" {
  type        = bool
  description = "A boolean flag to enable/disable DNS support in the VPC"
  default     = true
}

###########################################
############### IGW variables #############
###########################################

variable "create_igw" {
  type        = bool
  description = "A boolean flag to enable internet gateway creation"
  default     = true
}

###########################################
############### NAT variables #############
###########################################

variable "create_nat" {
  type        = bool
  description = "A boolean flag to enable nat gateway creation"
  default     = true
}

variable "nat_mode" {
  type        = string
  description = "NAT Gateway mode: 'zonal' (one per AZ, requires public subnets) or 'regional' (single NAT for all AZs, no public subnet required)"
  default     = "zonal"
  validation {
    condition     = can(regex("^(zonal|regional)$", var.nat_mode))
    error_message = "nat_mode must be either 'zonal' or 'regional'"
  }
}

variable "nat_regional_mode" {
  type        = string
  description = "Regional NAT Gateway IP management mode: 'auto' (AWS manages IPs automatically) or 'manual' (you specify EIPs per AZ)"
  default     = "auto"
  validation {
    condition     = can(regex("^(auto|manual)$", var.nat_regional_mode))
    error_message = "nat_regional_mode must be either 'auto' or 'manual'"
  }
}

variable "nat_regional_az_config" {
  type = list(object({
    availability_zone = string
    allocation_ids    = list(string)
  }))
  description = "Configuration for regional NAT Gateway in manual mode. List of objects with availability_zone and allocation_ids (EIP allocation IDs)"
  default     = []
}

variable "nat_regional_custom_routes" {
  type = list(object({
    destination_cidr_block    = string
    carrier_gateway_id        = optional(string)
    core_network_arn          = optional(string)
    egress_only_gateway_id    = optional(string)
    nat_gateway_id            = optional(string)
    local_gateway_id          = optional(string)
    network_interface_id      = optional(string)
    transit_gateway_id        = optional(string)
    vpc_endpoint_id           = optional(string)
    vpc_peering_connection_id = optional(string)
  }))
  description = "Custom routes to add to the regional NAT Gateway route table (edge association). Only applies when create_nat = true and nat_mode = regional. Useful for adding return routes to spokes via Transit Gateway."
  default     = []
}

###########################################
############# subnet variables ############
###########################################

variable "subnet_config" {
  type = map(object({
    custom_routes = list(object({
      destination_cidr_block    = string
      carrier_gateway_id        = optional(string)
      core_network_arn          = optional(string)
      egress_only_gateway_id    = optional(string)
      nat_gateway_id            = optional(string)
      local_gateway_id          = optional(string)
      network_interface_id      = optional(string)
      transit_gateway_id        = optional(string)
      vpc_endpoint_id           = optional(string)
      vpc_peering_connection_id = optional(string)
    }))
    public      = bool
    include_nat = optional(bool, false)
    subnets = list(object({
      cidr_block        = string
      availability_zone = string
    }))
  }))
  description = <<EOF
    Custom subnet and route configuration. It is a map where each key represents a group of subnets (e.g. 'public', 'private') and the value is an object with the following structure:
    - custom_routes: (list) A list of objects, each representing a custom route with the following properties:
      - destination_cidr_block: (string) The destination CIDR block for the route.
      - carrier_gateway_id: (string, optional) Identifier of a carrier gateway. This attribute can only be used when the VPC contains a subnet which is associated with a Wavelength Zone.
      - core_network_arn: (string, optional) The Amazon Resource Name (ARN) of a core network.
      - egress_only_gateway_id: (string, optional) Identifier of a VPC Egress Only Internet Gateway.
      - nat_gateway_id: (string, optional) Identifier of a VPC NAT gateway.
      - local_gateway_id: (string, optional) Identifier of a Outpost local gateway.
      - network_interface_id: (string, optional) Identifier of an EC2 network interface.
      - transit_gateway_id: (string, optional) Identifier of an EC2 Transit Gateway.
      - vpc_endpoint_id: (string, optional) Identifier of a VPC Endpoint.
      - vpc_peering_connection_id: (string, optional) Identifier of a VPC peering connection.
    - public: (bool) If true, set 0.0.0.0/0 to igw.
    - include_nat: (bool, optional) If true, set 0.0.0.0/0 to nat.
    - subnets: (list) A list of objects, each representing a subnet with the following properties:
      - cidr_block: (string) The IPv4 CIDR block for the subnet.
      - availability_zone: (string) AZ suffix for the subnet (e.g. 'a', 'b', 'c'); concatenated to aws_region.
  EOF
}

###########################################
########## VPC Endpoint variables #########
###########################################

variable "vpc_endpoints" {
  type = map(object({
    service_name        = string                     # e.g. "s3", "datasync" (short name) or full "com.amazonaws.<region>.<svc>"
    type                = string                     # "Gateway" or "Interface"
    route_table_keys    = optional(list(string), []) # (Gateway) subnet_config keys whose route tables associate the endpoint
    subnet_keys         = optional(list(string), []) # (Interface) subnet_config keys whose first subnet hosts the ENI
    security_group_ids  = optional(list(string), []) # (Interface) SGs for the endpoint ENIs
    private_dns_enabled = optional(bool, true)       # (Interface) enable private DNS
  }))
  description = "Map of VPC endpoints to create. Key is a logical name used for naming (agat-{env}-vpc-{name}-vpce-{key}). Gateway endpoints (S3, DynamoDB) attach to route tables; Interface endpoints (e.g. DataSync) attach to subnets with security groups."
  default     = {}
}

###########################################
############ flow log variables ###########
###########################################

variable "create_flow_logs" {
  type        = bool
  description = "A boolean flag to enable/disable VPC Flow Logs creation"
  default     = false
}

variable "flow_log_retention_in_days" {
  type = number
  validation {
    condition     = can(regex("^[0-9]*$", var.flow_log_retention_in_days))
    error_message = "Must be a number"
  }
  default     = 30
  description = "Specifies the number of days you want to retain log events in the specified log group. Possible values are: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653, and 0. If you select 0, the events in the log group are always retained and never expire"
}

###########################################
########## Additional Tags ################
###########################################

variable "additional_tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources created by this module"
  default     = {}
}
