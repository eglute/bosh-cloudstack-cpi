require 'bosh/dev/cloudstack'
require 'bosh/dev/writable_manifest'

module Bosh::Dev::Cloudstack
  class MicroBoshDeploymentManifest
    include Bosh::Dev::WritableManifest

    attr_reader :filename

    def initialize(env, net_type)
      @env = env
      @net_type = net_type
      @filename = 'micro_bosh.yml'
    end

    def to_h
      result = {
        'name' => director_name,
        'logging' => {
          'level' => 'DEBUG'
        },
        'network' => {
          'type' => net_type,
          'vip' => env['BOSH_CLOUDSTACK_VIP_DIRECTOR_IP'],
          'cloud_properties' => {
            'network_name' => env['BOSH_CLOUDSTACK_NETWORK_NAME']
          }
        },
        'resources' => {
          'persistent_disk' => 4096,
          'cloud_properties' => {
            'instance_type' => 'm1.small'
          }
        },
        'cloud' => {
          'plugin' => 'cloudstack',
          'properties' => cpi_options,
        },
        'apply_spec' => {
          'agent' => {
            'blobstore' => {
              'address' => env['BOSH_CLOUDSTACK_VIP_DIRECTOR_IP']
            },
            'nats' => {
              'address' => env['BOSH_CLOUDSTACK_VIP_DIRECTOR_IP']
            }
          },
          'properties' => {
            'director' => {
              'max_vm_create_tries' => 15
            },
          }
        }
      }

      result
    end

    def director_name
      "microbosh-cloudstack-#{net_type}"
    end

    def cpi_options
      {
        'cloudstack' => {
          'endpoint' => env['BOSH_CLOUDSTACK_ENDPOINT'],
          'api_key' => env['BOSH_CLOUDSTACK_API_KEY'],
          'secret_access_key' => env['BOSH_CLOUDSTACK_SECRET_ACCESS_KEY'],
          'default_key_name' => 'jenkins',
          'default_security_groups' => default_security_groups,
          'private_key' => env['BOSH_CLOUDSTACK_PRIVATE_KEY'],
          'default_zone' => env['BOSH_CLOUDSTACK_DEFAULT_ZONE'],
          'state_timeout' => state_timeout,
          'state_timeout_volume' => state_timeout_volume,
          'connection_options' => {
            'connect_timeout' => connection_timeout,
          }
        },
        'registry' => {
          'endpoint' => 'http://admin:admin@localhost:25889',
          'user' => 'admin',
          'password' => 'admin',
        },
      }
    end

    private

    attr_reader :env, :net_type

    def default_security_groups
      if env['BOSH_CLOUDSTACK_DEFAULT_SECURITY_GROUPS']
        [env['BOSH_CLOUDSTACK_DEFAULT_SECURITY_GROUPS']]
      else
        []
      end
    end

    def state_timeout
      normalize_timeout(env['BOSH_CLOUDSTACK_STATE_TIMEOUT'])
    end

    def state_timeout_volume
      normalize_timeout(env['BOSH_CLOUDSTACK_STATE_TIMEOUT_VOLUME'])
    end

    def normalize_timeout(value)
      value.to_s.empty? ? 300 : value.to_i
    end

    def connection_timeout
      timeout = env['BOSH_CLOUDSTACK_CONNECTION_TIMEOUT']
      timeout.to_s.empty? ? 60.0 : timeout.to_f
    end
  end
end
