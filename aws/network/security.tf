// Lock down the VPC's default security group so nothing accidentally uses it.
// CIS AWS Foundations 4.3 / Well-Architected: the default SG must restrict all
// traffic. Managing it here (with no ingress/egress rules) removes the AWS
// default allow-all rules without creating a new SG.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    { Name = "${local.name_prefix}-default-do-not-use" },
    local.common_tags
  )
}
