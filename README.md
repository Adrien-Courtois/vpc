# Terraform AWS VPC

## :package: Install Terraform

Install Terraform by following the [documentation](https://www.terraform.io/downloads.html)

Make sure `terraform` is working properly

```hcl
$ terraform
Usage: terraform [--version] [--help] <command> [args]

The available commands for execution are listed below.
The most common, useful commands are shown first, followed by
less common or more advanced commands. If you're just getting
started with Terraform, stick with the common commands. For the
other commands, please read the help and docs before usage.

Common commands:
    apply              Builds or changes infrastructure
    console            Interactive console for Terraform interpolations
# ...
```

*Based on [standard module structure](https://www.terraform.io/docs/modules/create.html#standard-module-structure) guidelines*

## 1. Create a `VPC`

The really first stage for bootstrapping an AWS account is to create a `VPC`

* [aws_vpc](https://www.terraform.io/docs/providers/aws/r/vpc.html)

![VPC AZs](./docs/2-vpc-azs.png)

## 2. Create `public` and `private` Subnets

Then create `public` and `private` subnets in each `AZs` (`us-east-1a`, `us-east-1b`, `us-east-1c`)

* [aws_subnet](https://www.terraform.io/docs/providers/aws/r/subnet.html)

![VPC AZs Subnets](./docs/3-vpc-azs-subnets.png)

## 3. Create `internet` and `nat` Gateways

Create one `internet gateway` so that the `VPC` can communicate with the outisde world. For instances located in `private` subnets, we will need `NAT` instances to be setup in each `availability zones`

* [aws_internet_gateway](https://www.terraform.io/docs/providers/aws/r/internet_gateway.html)
* [aws_ami](https://www.terraform.io/docs/providers/aws/d/ami.html)
* [aws_key_pair](https://www.terraform.io/docs/providers/aws/r/key_pair.html)
* [aws_instance](https://www.terraform.io/docs/providers/aws/r/instance.html)
* [aws_eip](https://www.terraform.io/docs/providers/aws/r/eip.html)
* [aws_eip_association](https://www.terraform.io/docs/providers/aws/r/eip_association.html)

![VPC AZs Subnets GW](./docs/4-vpc-azs-subnets-gw.png)

## 4. Create `route tables` and `routes`

Finaly, link the infrastructure together by creating `route tables` and `routes` so that servers from `public` and `private` subnets can send their traffic to the respective gateway, either the `internet gateway` or the `NAT` ones.

* [aws_route_table](https://www.terraform.io/docs/providers/aws/r/route_table.html)
* [aws_route](https://www.terraform.io/docs/providers/aws/r/route.html)
* [aws_route_table_association](https://www.terraform.io/docs/providers/aws/r/route_table_association.html)

![VPC AZs Subnets GW Routes](./docs/5-vpc-azs-subnets-gw-routing.png)
