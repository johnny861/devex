
# aws-cli cheat sheet

## install

```sh
#optional jq for parsing json responses
brew install jq

brew install awscli

aws --version

# configure default profile
aws configure

# add additional profiles
aws configure --profile my_profile

```

Follow prompts to configure default account.


## switch profiles

```sh
aws configure list-profiles

export AWS_PROFILE=my_profile

aws configure list
```

## create key pair

[cli-services-ec2-keypairs](https://docs.aws.amazon.com/cli/v1/userguide/cli-services-ec2-keypairs.html
)

```sh
aws ec2 create-key-pair --key-type ed25519 --key-name mykey_ed --query 'KeyMaterial' --output text > mykey_ed.pem
chmod 400 mykey_ed.pem

aws ec2 describe-key-pairs --key-name mykey_ed|jq  
```

## security groups

[cli-services-ec2-sg](https://docs.aws.amazon.com/cli/v1/userguide/cli-services-ec2-sg.html)


```sh
aws ec2 describe-security-groups|jq 

aws ec2 describe-security-groups|jq '.SecurityGroups[]|{GroupName, Description, VpcId, Tags}'

```


## ec2 instances

[cli-services-ec2-instances](https://docs.aws.amazon.com/cli/v1/userguide/cli-services-ec2-instances.html)


```sh
# get all instances
aws ec2 describe-instances|jq '.Reservations[]|.Instances[]'

# get all instances | display { specific props }
aws ec2 describe-instances|jq '.Reservations[]|.Instances[] | {InstanceId, PublicIpAddress, Tags}'


# get all instances | filter where .Tags[] has any property Value = "value" | display { specific property names }
aws ec2 describe-instances|jq '.Reservations[]|.Instances[] | select(.Tags | any(.Value == "mysite.com")) | {InstanceId, PublicIpAddress, Tags} '

# get value of InstanceId without quotes
aws ec2 describe-instances|jq '.Reservations[]|.Instances[] | select(.Tags | any(.Value == "mysite.com")) | {InstanceId, PublicIpAddress, Tags}' |jq -r '.InstanceId'

```