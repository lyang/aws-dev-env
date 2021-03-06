# What is this

A project template that helps creating simple \*nix development environment in AWS. With persisted EBS volume and automated backup, the instance can be easily thrown away and recreated / reconfigured.

## What does it do

* Using [Terraform](https://www.terraform.io/) to create simple \*nix based EC2 development environment.
* With automated EBS backup using CloudWatch and Lambda, and a script on the instance to backup on demand, it's very easy to destroy and recreate the dev environment.
* Using [Ansible](https://www.ansible.com/) to bootstrap the EC2 instance and generated inventory data, it's fairly easy to customize the instance to your need.

For [example](https://github.com/lyang/my-aws-dev-env), I use the inventory data to

* [Setup local ssh config](https://github.com/lyang/my-aws-dev-env/blob/master/tasks/setup_ssh.yml) for easy access
* [Install packages](https://github.com/lyang/my-aws-dev-env/blob/master/tasks/package.yml) for development
* [Setup VNC Server]() when I need an IDE, for e.g. IntelliJ, for Java.


## How do I use this

This template by itself doesn't do much beyond simple setup of the infrastructure in AWS, but it gives you an EC2 instance as well as inventory data ready to be used in [Ansible](https://www.ansible.com/) to customize your instance.

You can add this as a submodule in your own project, with your own customizations. You can take [my own setup](https://github.com/lyang/my-aws-dev-env) for an example how you might want to structure your project.

## I want to get a feel of how this works first

Of course. You can try this out without customizations.

### Prerequisites

**WARNING** The default configuration only uses AWS free tier resources, but if your AWS account is not eligible, trying this out may cost you money.

* [AWS Account](https://aws.amazon.com/console/) with a pre-existing S3 bucket to store terraform state
* [Terraform](https://www.terraform.io/)
* [Ansible](https://www.ansible.com/)

### Clone this repo
```
git clone https://github.com/lyang/aws-dev-env-template.git
```

### Installing Dependencies
```
brew install awscli terraform ansible
```

### Configure default AWS account
```
aws configure
```

### Configure Terraform backend

**WARNING**: Terraform uses your default AWS credentials stored in `~/.aws/credentials`. If that's not what you want, you can refer to [Terraform's doc](https://www.terraform.io/docs/providers/aws/index.html) on alternatives. Again, this may cost you money.
```
cd aws-dev-env-template/terraform && terraform init --backend-config=path/to/your/config-file
```
With the config file look like this:

```
bucket  = "<your-s3-bucket>"
key     = "terraform.tfstate"
encrypt = true
region  = "<your-s3-region>"
```

### Review what'll be created by Terraform
```
terraform plan
```

You should see the terraform execution plan for creating AWS and local resouces.

What will be created?

* A `t2.micro` instance created from latest official Debian AMI.
* A `10GB` `gp2` EBS volume attached to that instance.
* `CloudWatch` + `Lambda` function to take a snapshot of the EBS every `Monday 9am UTC`, which also drops snapshots older than 30 days.
* Various other supporting AWS resources like SecurityGroup, IAM roles/policies etc.
* RSA key pairs stored in Terraform S3 backend and locally, used to ssh into the instance later.
* Local artifacts generated to feed into `Ansible` in later steps.

### Looks good so far?
**WARNING**: This step will actually create AWS resources. If your account is not free tier eligible, this may cost you money.
```
terraform apply
```

If the plan looks right, type `yes` and continue.

By now, the barebone instance should be up and running. You should be able to ssh into the instance (ip and dns in terraform output from last step). You may have to wait a short while for ssh to be up on the instance.

```
ssh ec2-user@<ec2-dns-from-terraform-output> -i ../generated/ssh-keys/ec2-user.pem
```

### Provision the new instance
There's Ansible playbook in `aws-dev-env-template/ansible` to bootstrap the newly created instance, using inventory data generated by Terraform.
The `bootstrap.yml` playbook will do the following:

* Format the attached EBS volume as `ext4`
* Mount the EBS volume at `/ebs/home`
* Create the primary user `admin`, leaving system default user `ec2-user` alone in case we need it to do recovery work.
* The `admin` user will have her home dir at `/ebs/home/admin`. So we don't lose valuable data when we throw away the instance (and its default root volume).
* The `admin` user will be added to all groups system default user was in, and will be a passwordless sudoer.
* An entry will be added to authorized_keys, so that we can use Terraform generated private keys to ssh into the instance as the `admin` user later.

```
cd ../ansible && ansible-playbook bootstrap.yml
```

### Try it out
After bootstrap, you should be able to ssh into the instance use the newly created `admin` user.
```
ssh admin@<ec2-dns-from-terraform-output> -i ../generated/ssh-keys/admin.pem
```
And verify your home dir is indeed on the EBS volume
```
pwd # => Should be /ebs/home/admin
```

### Tearing it down
**WARNING**: Make sure you don't have anything valuable on the instance or EBS volume before tearing it down.

After playing with it a bit, you can tearing it down easily.

```
cd aws-dev-env-template/terraform && terraform destroy
```

Only resources created by terraform will be destroyed, including local files.

### What's next?

* You can try recreate it and bootstrap it again.
* You can try to recreate your instance with customizations
  * By passing variable files to `terraform plan` and `terraform apply`, like `terraform apply -var-file=terraform.tfvars`
  * The `terraform.tfvars` file looks something like [this](https://github.com/lyang/my-aws-dev-env/blob/master/files/terraform.tfvars). Uncomment to make changes.
* If you do find this template useful, take a deeper look at [my own setup](https://github.com/lyang/my-aws-dev-env) to get an idea how to make this more useful and better tailored to your own needs.


### Gotcha

This terraform setup will take a snapshot of the EBS volume every Monday at 9AM GMT, if you left your instance running long enough or happen to create your instance shortly before the schedule, those EBS snapshots won't be cleaned up by `terraform destroy`, you would need to manually delete those if you don't want those sitting around.

This is by design. Those automated EBS snapshots make it possible to throw away the instance without losing data[*], and being able to recreate the instance and start where you left. They also serve as point in time backups incase you lost data unexpectedly.

At anytime when you recreate your instance, it will try to use the last snapshot that was tagged `Baseline: True`, or a fresh EBS volume if none were found.

*If you have fresh data that wasn't included in the latest auto backup, you can run `backup-ebs-volume True` on your current instance to create a new baseline snapshot. Otherwise, set `Baseline` tag to `True` on your existing EBS snapshot to use it as your new starting point.
