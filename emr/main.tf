module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "emr-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
    for-use-with-amazon-emr-managed-policies = "true"
  }
}

module "emr" {
  source = "terraform-aws-modules/emr/aws"

  name = "example-instance-fleet"
  

  release_label = "emr-5.30.0"
  applications  = ["spark"]
  auto_termination_policy = {
    idle_timeout = 3600
  }

  bootstrap_action = {
    example = {
      path = "file:/bin/echo",
      name = "Just an example",
      args = ["Hello World!"]
    }
  }

  configurations_json = jsonencode([
    {
      "Classification" : "spark-env",
      "Configurations" : [
        {
          "Classification" : "export",
          "Properties" : {
            "JAVA_HOME" : "/etc/alternatives/jre"
          }
        }
      ],
      "Properties" : {}
    }
  ])

  master_instance_fleet = {
    name                      = "master-fleet"
    target_on_demand_capacity = 1
    instance_type_configs = [
      {
        instance_type = "m5.xlarge"
      }
    ]
  }

  core_instance_fleet = {
    name                      = "core-fleet"
    target_on_demand_capacity = 2
    target_spot_capacity      = 2
    instance_type_configs = [
      {
        instance_type     = "c4.large"
        weighted_capacity = 1
      },
      {
        bid_price_as_percentage_of_on_demand_price = 100
        ebs_config = {
          size                 = 64
          type                 = "gp3"
          volumes_per_instance = 1
        }
        instance_type     = "c5.xlarge"
        weighted_capacity = 2
      }
      # {
      #   bid_price_as_percentage_of_on_demand_price = 100
      #   instance_type                              = "c6i.xlarge"
      #   weighted_capacity                          = 2
      # }
    ]
    launch_specifications = {
      spot_specification = {
        allocation_strategy      = "capacity-optimized"
        block_duration_minutes   = 0
        timeout_action           = "SWITCH_TO_ON_DEMAND"
        timeout_duration_minutes = 5
      }
    }
  }

  task_instance_fleet = {
    name                      = "task-fleet"
    target_on_demand_capacity = 1
    target_spot_capacity      = 2
    instance_type_configs = [
      {
        instance_type     = "c4.large"
        weighted_capacity = 1
      },
      {
        bid_price_as_percentage_of_on_demand_price = 100
        ebs_config = {
          size                 = 64
          type                 = "gp3"
          volumes_per_instance = 1
        }
        instance_type     = "c5.xlarge"
        weighted_capacity = 2
      }
    ]
    launch_specifications = {
      spot_specification = {
        allocation_strategy      = "capacity-optimized"
        block_duration_minutes   = 0
        timeout_action           = "SWITCH_TO_ON_DEMAND"
        timeout_duration_minutes = 5
      }
    }
  }

  ebs_root_volume_size = 64
  ec2_attributes = {
    # Subnets should be private subnets and tagged with
    # { "for-use-with-amazon-emr-managed-policies" = true }
    # subnet_ids = ["subnet-abcde012", "subnet-bcde012a", "subnet-fghi345a"]
    subnet_ids = module.vpc.private_subnets
  }
  # vpc_id = "vpc-1234556abcdef"
  vpc_id = module.vpc.vpc_id

  list_steps_states  = ["PENDING", "RUNNING", "FAILED", "INTERRUPTED"]
  log_uri            = "s3://my-elasticmapreduce-bucket/"

  scale_down_behavior    = "TERMINATE_AT_TASK_COMPLETION"
  step_concurrency_level = 3
  termination_protection = false
  visible_to_all_users   = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}