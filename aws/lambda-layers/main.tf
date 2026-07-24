resource "null_resource" "build_layer" {
  for_each = var.layers

  triggers = {
    buildspec = filemd5(each.value.buildspec_path)
  }

  provisioner "local-exec" {

    command = <<EOF
chmod +x ${abspath(path.module)}/utils/check_codebuild.sh

${abspath(path.module)}/utils/check_codebuild.sh \
${aws_codebuild_project.layer[each.key].name} \
${var.aws.region} \
${var.codebuild.timeout} \
${each.value.layer_name} \
${var.artifact_bucket.layer_prefix} \
${var.artifact_bucket.name}
EOF

    interpreter = ["bash", "-c"]
    on_failure  = fail
  }

  depends_on = [aws_codebuild_project.layer]
}



###############################################################################
# Lambda layers
###############################################################################

data "aws_s3_object" "layer_zip" {
  for_each = var.layers

  bucket = var.artifact_bucket.name
  key    = "${var.artifact_bucket.layer_prefix}lambda_layers/${each.value.layer_name}-cb/${each.value.layer_name}.zip"

  depends_on = [null_resource.build_layer]
}

resource "aws_lambda_layer_version" "from_codebuild" {
  for_each = var.layers

  s3_bucket                = var.artifact_bucket.name
  s3_key                   = "${var.artifact_bucket.layer_prefix}lambda_layers/${each.value.layer_name}-cb/${each.value.layer_name}.zip"
  layer_name               = "${each.value.layer_name}-layer"
  compatible_runtimes      = each.value.runtimes
  compatible_architectures = each.value.architectures
  source_code_hash         = data.aws_s3_object.layer_zip[each.key].etag

  depends_on = [null_resource.build_layer]
}
