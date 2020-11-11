require 'spec_helper'
require 'kitchen/driver/ovirt'
require 'kitchen/transport/dummy'

describe Kitchen::Driver::Ovirt do
  let(:logged_output) { StringIO.new }
  let(:logger)        { Logger.new(logged_output) }
  let(:platform)      { Kitchen::Platform.new(name: 'fake_platform') }
  let(:transport)     { Kitchen::Transport::Dummy.new }
  let(:driver)        { Kitchen::Driver::Ovirt.new(config) }

  let(:config) do
    {
      engine_url:     'https://ovirt.example.com/ovirt-engine/api',
      datacenter:     'Datacenter',
      cluster:        'Cluster',
      template:       'ubuntu-1804',
      vm_name:        'tk-default-ubuntu-1804-random',
      vm_net_address: '1.2.3.4',
      vm_username:    'root',
      vm_password:    'root123'
    }
  end

  let(:instance) do
    instance_double(
      Kitchen::Instance,
      logger:     logger,
      transport:  transport,
      platform:   platform,
      to_str:     'instance_str'
    )
  end

  it 'driver API version is 2' do
    expect(driver.diagnose_plugin[:api_version]).to eq(2)
  end

  describe '#create' do
    let(:datacenter)        { double('Datacenter') }
    let(:cluster)           { double('Cluster') }
    let(:connection)        { double('oVirt Connection') }
    let(:templates_service) { double('Template Service') }
    let(:vms_service)       { double('VMs Service') }
    let(:vm_service)        { double('VM Service') }
    let(:vm)                { double('VM') }
    let(:template)          { double('Template') }
    let(:state)             { {} }

    before do
      allow(driver).to receive(:connect_engine).and_return(connection)
      allow(driver).to receive(:default_template).and_return('ubuntu-1804')
      allow(driver).to receive(:default_vm_name).and_return('fake-platform-vm')

      allow(datacenter).to receive(:name).and_return('Datacenter')
      allow(datacenter).to receive(:clusters).and_return('Clusters')

      allow(cluster).to receive(:name).and_return('Cluster')
      allow(cluster).to receive(:id).and_return('CLUSTER-ID')

      allow(connection).to receive_message_chain(
        :system_service, :data_centers_service, :list
      ).with(no_args).with(no_args).with(no_args).and_return([datacenter])
      allow(connection).to receive(:follow_link).and_return([cluster])
      allow(connection).to receive_message_chain(
        :system_service, :templates_service
      ).with(no_args).with(no_args).and_return(templates_service)
      allow(connection).to receive_message_chain(
        :system_service, :vms_service
      ).with(no_args).with(no_args).and_return(vms_service)
      allow(connection).to receive(:close).and_return(true)

      allow(templates_service).to receive(:list).and_return([template])
      allow(vms_service).to receive(:add).and_return(vm)
      allow(vms_service).to receive(:list).and_return([vm])
      allow(vms_service).to receive(:vm_service).and_return(vm)
      allow(vm).to receive(:id).and_return('VM-ID-123')
      allow(vm).to receive(:status).and_return(
        OvirtSDK4::VmStatus::DOWN,
        OvirtSDK4::VmStatus::UP
      )
      allow(vm).to receive(:start).and_return('Cloud-Init')
      allow(template).to receive(:name).and_return('ubuntu-1804')
      allow(template).to receive_message_chain(
        :cluster, :id
      ).with(no_args).with(no_args).and_return('CLUSTER-ID')
    end

    it 'does not create the server if the hostname is in the state file' do
      expect(vms_service).not_to receive(:add)
      driver.create(server_name: 'server_exist')
    end
    it 'Create VM' do
      driver.create(state)
      expect(state[:hostname]).to eq('1.2.3.4')
      expect(state[:server_name]).to eq('tk-default-ubuntu-1804-random')
      expect(state[:username]).to eq('root')
      expect(state[:password]).to eq('root123')
    end
  end

  describe '#destroy' do
    let(:connection)        { double('oVirt Connection') }
    let(:vms_service)       { double('VMs Service') }
    let(:vm_service)        { double('VM Service') }
    let(:vm)                { double('VM') }
    let(:state)             { {} }

    before do
      allow(driver).to receive(:connect_engine).and_return(connection)

      allow(connection).to receive_message_chain(
        :system_service, :vms_service
      ).with(no_args).with(no_args).and_return(vms_service)
      allow(connection).to receive(:close).and_return(true)
      allow(vms_service).to receive(:list).and_return([vm])
      allow(vms_service).to receive(:vm_service).and_return(vm)
      allow(vm).to receive(:id).and_return('VM-ID-123')
      allow(vm).to receive(:status).and_return(
        OvirtSDK4::VmStatus::UP,
        OvirtSDK4::VmStatus::DOWN
      )
      allow(vm).to receive(:stop).and_return(true)
      allow(vm).to receive(:remove).and_return(true)
    end

    it 'Missing VM' do
      expect(vms_service).to receive(:list).and_return([])
      expect(vms_service).not_to receive(:remove)
      driver.destroy(server_name: 'missing_vm')
    end
    it 'Destroy VM' do
      driver.destroy(server_name: 'server_will_be_removed')
    end
  end
end
