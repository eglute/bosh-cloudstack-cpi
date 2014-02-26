require 'spec_helper'
require 'bosh/dev/cloudstack/micro_bosh_deployment_manifest'
require 'yaml'

module Bosh::Dev::Cloudstack
  describe MicroBoshDeploymentManifest do
    subject { MicroBoshDeploymentManifest.new(env, net_type) }
    let(:env) { {} }
    let(:net_type) { 'dynamic' }

    its(:filename) { should eq('micro_bosh.yml') }

    it 'is writable' do
      expect(subject).to be_a(Bosh::Dev::WritableManifest)
    end

    describe '#to_h' do
      before do
        env.merge!(
          'BOSH_CLOUDSTACK_VIP_DIRECTOR_IP' => 'vip',
          'BOSH_CLOUDSTACK_NETWORK_NAME' => 'network_name',
          'BOSH_CLOUDSTACK_ENDPOINT' => 'endpoint_url',
          'BOSH_CLOUDSTACK_API_KEY' => 'api_key',
          'BOSH_CLOUDSTACK_SECRET_ACCESS_KEY' => 'secret_access_key',
          'BOSH_CLOUDSTACK_DEFAULT_ZONE' => 'default_zone',
          'BOSH_CLOUDSTACK_PRIVATE_KEY' => 'private_key_path',
        )
      end

      context 'when net_type is "dynamic"' do
        let(:net_type) { 'dynamic' }
        let(:expected_yml) { <<YAML }
---
name: microbosh-cloudstack-dynamic
logging:
  level: DEBUG
network:
  type: dynamic
  vip: vip
  cloud_properties:
    network_name: network_name
resources:
  persistent_disk: 4096
  cloud_properties:
    instance_type: m1.small
cloud:
  plugin: cloudstack
  properties:
    cloudstack:
      endpoint: endpoint_url
      api_key: api_key
      secret_access_key: secret_access_key
      default_key_name: jenkins
      private_key: private_key_path
      default_zone: default_zone
      default_security_groups: []
      state_timeout: 300
      state_timeout_volume: 300
      connection_options:
        connect_timeout: 60
    registry:
      endpoint: http://admin:admin@localhost:25889
      user: admin
      password: admin
apply_spec:
  agent:
    blobstore:
      address: vip
    nats:
      address: vip
  properties:
    director:
      max_vm_create_tries: 15
YAML

        it 'generates the correct YAML' do
          expect(subject.to_h).to eq(Psych.load(expected_yml))
        end
      end

      context 'when BOSH_CLOUDSTACK_CONNECTION_TIMEOUT is specified' do
        it 'uses given env variable value (converted to a float) as a connect_timeout' do
          value = double('connection_timeout', to_f: 'connection_timeout_as_float')
          env.merge!('BOSH_CLOUDSTACK_CONNECTION_TIMEOUT' => value)
          expect(subject.to_h['cloud']['properties']['cloudstack']['connection_options']['connect_timeout']).to eq('connection_timeout_as_float')
        end
      end

      context 'when BOSH_CLOUDSTACK_CONNECTION_TIMEOUT is an empty string' do
        it 'uses 60 (number) as a connect_timeout' do
          env.merge!('BOSH_CLOUDSTACK_CONNECTION_TIMEOUT' => '')
          expect(subject.to_h['cloud']['properties']['cloudstack']['connection_options']['connect_timeout']).to eq(60)
        end
      end

      context 'when BOSH_CLOUDSTACK_CONNECTION_TIMEOUT is not specified' do
        it 'uses 60 (number) as a connect_timeout' do

          env.merge!('BOSH_CLOUDSTACK_CONNECTION_TIMEOUT' => nil)
          expect(subject.to_h['cloud']['properties']['cloudstack']['connection_options']['connect_timeout']).to eq(60)
        end
      end
    end

    its(:director_name) { should match(/microbosh-cloudstack-/) }

    describe '#cpi_options' do
      before do
        env.merge!(
          'BOSH_CLOUDSTACK_ENDPOINT' => 'fake-endpoint',
          'BOSH_CLOUDSTACK_API_KEY' => 'fake-api-key',
          'BOSH_CLOUDSTACK_SECRET_ACCESS_KEY' => 'fake-secret-access-key',
          'BOSH_CLOUDSTACK_DEFAULT_SECURITY_GROUPS' => 'fake-default-security-groups',
          'BOSH_CLOUDSTACK_DEFAULT_ZONE' => 'fake-default-zone',
          'BOSH_CLOUDSTACK_PRIVATE_KEY' => 'fake-private-key-path',
        )
      end

      it 'returns cpi options' do
        expect(subject.cpi_options).to eq(
          'cloudstack' => {
            'endpoint' => 'fake-endpoint',
            'api_key' => 'fake-api-key',
            'secret_access_key' => 'fake-secret-access-key',
            'default_key_name' => 'jenkins',
            'default_security_groups' => ['fake-default-security-groups'],
            'private_key' => 'fake-private-key-path',
            'default_zone' => 'fake-default-zone',
            'state_timeout' => 300,
            'state_timeout_volume' => 300,
            'connection_options' => {
              'connect_timeout' => 60,
            }
          },
          'registry' => {
            'endpoint' => 'http://admin:admin@localhost:25889',
            'user' => 'admin',
            'password' => 'admin',
          },
        )
      end
    end
  end
end
