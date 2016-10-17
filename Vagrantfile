# -*- mode: ruby -*-
# # vi: set ft=ruby :
require 'erb'

Vagrant.require_version ">= 1.6.0"

hostname = 'zpool-snapshotter'
instance_name = hostname + "-" + ENV.fetch('TRAVIS_JOB_NUMBER')

def get_latest_ami(channel)
	ec2 = Aws::EC2::Client.new()
	name_glob = "bootstick-" + channel + "-*"
	filters = [
		{ name: "is-public", values: ["false"] },
		{ name: "virtualization-type", values: ["hvm"] },
		{ name: "name",	values: [name_glob] }
	]

	ec2.describe_images({filters: filters}).images.sort_by{ |x| x[:creation_date] }.last[:image_id]
end

Vagrant.configure("2") do |config|
  config.vm.hostname = hostname
  config.ssh.insert_key = false
  config.ssh.username = false
  config.vm.synced_folder '.', '/vagrant', :disabled => true
  config.vm.box = 'dummy'
  config.vm.define hostname do |foobar|
  end
  config.vm.provider :aws do |aws, override|
    aws.user_data = ERB.new(IO.read('snapshot_cloud_config.yml')).result
    aws.access_key_id = ENV.fetch('AWS_ACCESS_KEY_ID')
    aws.secret_access_key = ENV.fetch('AWS_SECRET_ACCESS_KEY')
    aws.security_groups = ['sg-a520b2c1'] # SSH ingress
    aws.block_device_mapping = [
      { 'DeviceName' => '/dev/xvda', 'Ebs.VolumeSize' => 8, 'Ebs.VolumeType' => 'gp2' },
      { 'DeviceName' => '/dev/xvdb', 'Ebs.VolumeSize' => 40, 'Ebs.VolumeType' => 'gp2' }
    ]
    aws.instance_type = 't2.nano'
    aws.associate_public_ip = true
    aws.ami = get_latest_ami(ENV.fetch('AMI_CHANNEL'))
    aws.tags = {:Name => instance_name, :Test => "true"}
    aws.region = 'us-west-2'
    aws.subnet_id = 'subnet-849f0add'
    override.ssh.username = "root"
    override.ssh.private_key_path = "/home/vagrant/id_rsa"
  end

end
