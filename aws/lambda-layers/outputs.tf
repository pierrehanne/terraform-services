output "codebuild" {
  description = "Shared CodeBuild infrastructure configuration"
  value = {
    role = {
      arn = aws_iam_role.codebuild.arn
    }

    log_group = {
      name = aws_cloudwatch_log_group.code_build.name
      arn  = aws_cloudwatch_log_group.code_build.arn
    }

    kms = {
      key_arn = module.kms_cb_log_group.kms_key_arn
    }
  }
}

output "lambda_layers" {
  description = "Published Lambda layer versions created from CodeBuild artifacts"
  value = {
    for key, layer in aws_lambda_layer_version.from_codebuild : key => {
      arn                 = layer.arn
      layer_arn           = layer.layer_arn
      name                = layer.layer_name
      version             = layer.version
      compatible_runtimes = layer.compatible_runtimes
    }
  }
}


output "lambda_layer_arns" {
  description = "Map of Lambda layer key to published layer version ARN"
  value = {
    for key, layer in aws_lambda_layer_version.from_codebuild : key => layer.arn
  }
}
