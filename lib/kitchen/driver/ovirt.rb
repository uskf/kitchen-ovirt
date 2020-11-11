require 'kitchen'
require 'ovirtsdk4'
require_relative 'ovirt_version'
require 'securerandom' unless defined?(SecureRandom)

module Kitchen
  module Driver
    # Kitchen driver for oVirt
    #
    # @author Yusuke Fujimaki
    class Ovirt < Kitchen::Driver::Base
      kitchen_driver_api_version 2

      required_config :engine_url
      required_config :ovirt_password
      required_config :vm_net_interface
      required_config :vm_net_address
      required_config :vm_net_netmask

      default_config :ovirt_username, 'admin@internal'
      default_config :datacenter, 'Default'
      default_config :cluster, 'Default'
      default_config :vm_name, nil
      default_config :vm_username, 'root'
      default_config :vm_password, 'root123'
      default_config :vm_description, 'Test Kitchen VM'
      default_config :vm_net_ipver, 'IPv4'
      default_config :vm_net_gateway, ''
      default_config :dns_servers, ''
      default_config :wait_after_up, 10

      default_config(:template, &:default_template)
      required_config :template

      def create(state)
        return if state[:server_name]

        validate!

        server_name = generate_server_name

        connection = connect_engine
        datacenter = get_datacenter(connection)
        cluster = get_cluster(connection, datacenter)
        template = get_template(connection, cluster)

        vms_service = connection.system_service.vms_service
        vm = OvirtSDK4::Vm.new(
          name: server_name,
          cluster: {
            name: cluster.name
          },
          template: {
            name: template.name
          },
          description: config[:vm_description],
          delete_protected: false
        )
        vms_service.add(vm)

        loop do
          info('Waiting for VM creation to complete.')
          vm = vms_service.list(search: "name=#{server_name}")[0]
          break if vm.status == OvirtSDK4::VmStatus::DOWN
          sleep(5)
        end

        vm_service = vms_service.vm_service(vm.id)

        info('Starting VM.')
        vm_service.start(create_cloud_init(server_name))
        loop do
          vm = vms_service.list(search: "name=#{server_name}")[0]
          info("Waiting for VM to be up...(current status:#{vm.status})")
          break if vm.status == OvirtSDK4::VmStatus::UP
          sleep(5)
        end
        sleep(config[:wait_after_up])

        connection.close

        state[:server_name] = server_name
        state[:hostname] = config[:vm_net_address]
        state[:username] = config[:vm_username]
        state[:password] = config[:vm_password]
      end

      def destroy(state)
        connection = connect_engine
        server_name = state[:server_name]

        vms_service = connection.system_service.vms_service
        vm = vms_service.list(search: "name=#{server_name}")[0]
        return unless vm

        vm_service = vms_service.vm_service(vm.id)
        vm_service.stop if vm.status != OvirtSDK4::VmStatus::DOWN

        loop do
          vm = vms_service.list(search: "name=#{server_name}")[0]
          break if vm.status == OvirtSDK4::VmStatus::DOWN
          sleep(1)
        end

        vm_service.remove
        info("VM \"#{server_name}\" destroyed.")

        state.delete(:server_name)
        state.delete(:hostname)
        state.delete(:username)
        state.delete(:password)
      end

      def validate!
        raise 'Invalid IP protocol' unless config[:vm_net_ipver] =~ /^IPv[46]$/i
        raise 'wait_after_up accepts only Integer' unless config[:wait_after_up].instance_of?(Integer)
      end

      def default_template
        instance.platform.name
      end

      def generate_server_name
        name = if config[:vm_name]
                 config[:vm_name]
               else
                 "tk-#{instance.name.downcase}-#{SecureRandom.hex(3)}"
               end
        name
      end

      def connect_engine
        connection = OvirtSDK4::Connection.new(
          url:      config[:engine_url],
          username: config[:ovirt_username],
          password: config[:ovirt_password],
          debug:    false,
          insecure: true
        )
        return(connection) unless connection.nil?
        raise 'Login to oVirt failed'
      end

      def get_datacenter(conn)
        conn.system_service.data_centers_service.list.each do |d|
          return(d) if d.name == config[:datacenter]
        end
        raise "Data Center \"#{name}\" does not exist"
      end

      def get_cluster(conn, datacenter)
        clusters = conn.follow_link(datacenter.clusters)
        clusters.each do |c|
          return(c) if c.name == config[:cluster]
        end
        raise "Cluster does not exist in \"#{datacenter.name}\""
      end

      def get_template(conn, cluster)
        templates_service = conn.system_service.templates_service
        templates_service.list.each do |t|
          return(t) if t.name == config[:template] && t.cluster.id == cluster.id
        end
        raise "Template \"#{config[:template]}\" does not exist or not belong to #{cluster.name}"
      end

      def create_cloud_init(hostname)
        ipvermap = {
          'ipv4' => OvirtSDK4::IpVersion::V4,
          'ipv6' => OvirtSDK4::IpVersion::V6
        }

        vm_config = {
          use_cloud_init: true,
          volatile: true,
          vm: {
            initialization: {
              user_name:          config[:vm_username],
              root_password:      config[:vm_password],
              host_name:          hostname,
              nic_configurations: [
                {
                  name: config[:vm_net_interface],
                  on_boot: true,
                  boot_protocol: OvirtSDK4::BootProtocol::STATIC,
                  ip: {
                    version: ipvermap[config[:vm_net_ipver].downcase],
                    address: config[:vm_net_address],
                    netmask: config[:vm_net_netmask]
                  }
                }
              ]
            }
          }
        }

        unless config[:vm_net_gateway].empty?
          vm_config[:vm][:initialization][:nic_configurations][0][:ip][:gateway] = config[:vm_net_gateway]
        end

        unless config[:dns_servers].empty?
          vm_config[:vm][:initialization][:dns_servers] = config[:dns_servers]
        end

        vm_config
      end
    end
  end
end
