require 'logger'
require 'sequel'
require 'sequel/adapters/sqlite'
require 'cloud/cloudstack'
require 'common/retryable'
require 'bosh/dev/cloudstack'

module Bosh::Dev::Cloudstack
  class MicroBoshDeploymentCleaner
    def initialize(manifest)
      @manifest = manifest
      @logger = Logger.new($stderr)
    end

    def clean
      configure_cpi

      cloud = Bosh::CloudStackCloud::Cloud.new(@manifest.cpi_options)

      servers_collection = cloud.compute.servers

      Bosh::Retryable.new(tries: 20, sleep: 20).retryer do
        # CloudStack does not return deleted servers on subsequent calls
        servers = find_any_matching_servers(servers_collection)

        matching_server_names = servers.map(&:name).join(', ')
        @logger.info("Destroying servers #{matching_server_names}")

        # calling destroy on a server multiple times is ok
        servers.each { |s| clean_server(s) }

        servers.empty?
      end

      # destroy all images
      cloud.compute.images.all.each do |image|
        if image.name =~ /^BOSH/
          @logger.info("Destroying image #{image.name}")
          # image.destroy
        else
          @logger.info("Ignoring image #{image.name}")
        end
      end

      # destroy unattached volumes
      cloud.compute.volumes.all.each do |volume|
        if volume.server_id.nil?
          @logger.info("Destroying volume #{volume.name}")
          # volume.destroy
        end
      end

    end

    def clean_server(server)
      server.service.volumes.all.select { |volume|
        volume.server_id == server.id &&
        volume.type != 'ROOT'
      }.each do |volume|
        volume.detach

        options = { tries: 10, sleep: 5, on: [Excon::Errors::BadRequest] }
        Bosh::Retryable.new(options).retryer { volume.destroy }
      end

      server.destroy
    end

    private

    def configure_cpi
      Bosh::Clouds::Config.configure(OpenStruct.new(
        logger: @logger,
        uuid: nil,
        task_checkpoint: nil,
        db: Sequel.sqlite,
      ))
    end

    def find_any_matching_servers(servers_collection)
      # Assumption here is that when director deploys instances
      # it properly tags them with director's name.
      servers_collection.all.select do |server|
        response = server.service.list_tags(resourceid: server.id)['listtagsresponse']
        response.has_key?('tag') &&
        response['tag'].find { |tag|
          (tag['key'] == 'director' || tag['key'] == 'Name') &&
          tag['value'] == @manifest.director_name
        }

      end
    end
  end
end
