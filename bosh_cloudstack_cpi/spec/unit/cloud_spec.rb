# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::CloudStackCloud::Cloud do

  describe :new do
    end_point = "http://127.0.0.1:5000"
    let(:cloud_options) { mock_cloud_options }
    let(:fog_cloudstack_parms) {
      {
          :provider => 'CloudStack',
          :cloudstack_api_key => 'admin',
          :cloudstack_secret_access_key => 'foobar',
          :cloudstack_scheme => URI.parse(end_point).scheme,
          :cloudstack_host => URI.parse(end_point).host,
          :cloudstack_port => URI.parse(end_point).port,
          :cloudstack_path => URI.parse(end_point).path,
          :connection_options => connection_options
      }
    }
    let(:connection_options) { nil }
    let(:compute) { double('Fog::Compute') }

    it 'should create a Fog connection for advanced zone' do
      Fog::Compute.stub(:new).with(fog_cloudstack_parms).and_return(compute)
      zone = double('zone', :network_type => :advanced)
      compute.stub_chain(:zones, :find).and_return(zone)
      cloud = Bosh::Clouds::Provider.create(:cloudstack, cloud_options)

      expect(cloud.compute).to eql(compute)
    end

    context 'with connection options' do
      let(:connection_options) {
        JSON.generate({
                          'ssl_verify_peer' => false,
                      })
      }

      it 'should add optional options to the Fog connection' do
        cloud_options['cloudstack']['connection_options'] = connection_options
        Fog::Compute.stub(:new).with(fog_cloudstack_parms).and_return(compute)
        zone = double('zone', :network_type => :advanced)
        compute.stub_chain(:zones, :find).and_return(zone)
        cloud = Bosh::Clouds::Provider.create(:cloudstack, cloud_options)

        expect(cloud.compute).to eql(compute)
      end
    end

  end

  describe "creating via provider" do

    it "can be created using Bosh::Cloud::Provider" do
      compute = double('compute')
      Fog::Compute.stub(:new).and_return(compute)
      compute.stub_chain(:zones, :find).and_return(nil)
      expect {
        Bosh::Clouds::Provider.create(:cloudstack, mock_cloud_options)
      }.to raise_error(Bosh::Clouds::CloudError)
    end

    it "created using Bosh::Cloud::Provider & zone should not be nil" do
      compute = double('compute')
      Fog::Compute.stub(:new).and_return(compute)
      zone = double('zone', :network_type => :basic)
      compute.stub_chain(:zones, :find).and_return(zone)
      cloud = Bosh::Clouds::Provider.create(:cloudstack, mock_cloud_options)
      cloud.should be_an_instance_of(Bosh::CloudStackCloud::Cloud)
    end

    it "raises ArgumentError on initializing with blank options" do
      options = Hash.new("options")
      expect {
        Bosh::CloudStackCloud::Cloud.new(options)
      }.to raise_error(ArgumentError, /Invalid CloudStack configuration/)
    end

    it "raises ArgumentError on initializing with non Hash options" do
      options = "this is a string"
      expect {
        Bosh::CloudStackCloud::Cloud.new(options)
      }.to raise_error(ArgumentError, /Invalid CloudStack configuration/)
    end

    it "raises a CloudError exception if cannot connect to the CloudStack Compute API" do
      Fog::Compute.should_receive(:new).and_raise(Excon::Errors::Unauthorized, "Unauthorized")
      expect {
        Bosh::Clouds::Provider.create(:cloudstack, mock_cloud_options)
      }.to raise_error(Bosh::Clouds::CloudError,
                       "Unable to connect to the CloudStack Compute API. Check task debug log for details.")
    end

  end
end
