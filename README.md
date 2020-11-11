# Kitchen::Ovirt - A Test Kitchen Driver for oVirt

This is Test Kitchen Driver for [oVirt](https://ovirt.org)

Currently, this driver supports only linux virtual machine.

## Build

    $ git clone https://github.com/uskf/kitchen-ovirt.git
    $ cd kitchen-ovirt
    $ bundle exec rake build

## Installation

Download or build gem package and

    $ gem install /path/to/kitchen-ovirt-x.y.z.gem

## oVirt Template Requirements
This driver use oVirt template and cloud-init.
You have to install cloud-init into your template image.

## Configuration

### `engine_url`
**Required**.

oVirt REST API URL

Example: https://ovirt.example.com/ovirt-engine/api

### `ovirt_username`

oVirt username.

Default: admin@internal

### `ovirt_password`
**Required**.

oVirt password.

Example: redhat123

### `vm_net_interface`
**Required**.

Virtual machine's network interface name, such as 'eth0'

### `vm_net_address`
**Required**.

Virtual machine's IP address.(IPv4 or IPv6)

Example: 192.168.1.2

### `vm_net_netmask`
**Required**.

Virtual machine's IP netmask. When using an IPv6 address,specify the prefix.

Example(IPv4): 255.255.255.0

Example(IPv6): 64

### `datacenter`
oVirt datacenter name.

Default: "Default"

### `cluster`
oVirt cluster name. 

Default: "Default"

### `template`
oVirt template to create virtual machine.

Default: platform name in .kitchen.yml, such as "centos-8"

### `vm_name`
**Optional**.

 Virtual Machine name and hostname.

Default: `tk-<suite>-<platform>-<random>`

### `vm_username`
**Optional**.

Administrator account name in virtual machine.

Default: "root"

### `vm_password`
**Optional**.

administrator account password in virtual machine.

Default: "root123"

### `vm_description`
**Optional**.

Virtual machine description.

Default: "Test Kitchen VM"

### `vm_net_ipver`
**Optional**.

Virtual machine's IP protocol version.

Default: "IPv4"

### `dns_servers`
**Optional**.

comma separated dns server's ip address referenced by virtual machine.

Example: "192.168.1.1,192.168.2.1"

### `wait_after_up`
**Optional**.

wait time (seconds) after virtual machine up state, before starting converge.

Default: 10

## Example .kitchen.yml

```
driver:
  name: ovirt
  engine_url: "https://ovirt.example.com/ovirt-engine/api"
  ovirt_username: 'kitchen@internal'
  ovirt_password: 'kitchen-pass'
  datacenter: "DataCenter"
  cluster: "Cluster"
  dns_servers: "192.168.1.53"
  vm_net_ipver: "IPv4"
  vm_net_netmask: "255.255.255.0"

provisioner:
  name: chef_zero
  install_strategy: once
  product_name: cinc
  always_update_cookbooks: true

verifier:
  name: inspec

platforms:
  - name: centos-7
    driver:
      vm_name: "testkitchen-centos-7"
      vm_net_interface: "eth0"
      vm_net_address: "192.168.10.7"
      vm_net_gateway: "192.168.10.254"
  - name: centos-8
    driver:
      template: "centos-8-test"
      vm_net_interface: "enp1s0"
      vm_net_address: "192.168.20.8"
      vm_net_gateway: "192.168.20.254"

suites:
  - name: default
    run_list:
      - recipe[apache_httpd::default]
    verifier:
      inspec_tests:
        - test/integration/default
    attributes:
```
