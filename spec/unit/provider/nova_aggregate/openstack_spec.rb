require 'puppet'
require 'spec_helper'
require 'puppet/provider/nova_aggregate/openstack'

provider_class = Puppet::Type.type(:nova_aggregate).provider(:openstack)

describe provider_class do

  shared_examples 'authenticated with environment variables' do
    ENV['OS_USERNAME']     = 'test'
    ENV['OS_PASSWORD']     = 'abc123'
    ENV['OS_PROJECT_NAME'] = 'test'
    ENV['OS_AUTH_URL']     = 'http://127.0.0.1:35357/v3'
  end

  describe 'managing aggregates' do

    let(:aggregate_attrs) do
      {
         :name              => 'just',
         :availability_zone => 'simple',
         :hosts             => 'example',
         :ensure            => 'present',
         :metadata          => 'nice=cookie',
      }
    end

    let(:resource) do
      Puppet::Type::Nova_aggregate.new(aggregate_attrs)
    end

    let(:provider) do
      provider_class.new(resource)
    end

    it_behaves_like 'authenticated with environment variables' do
      describe '#exists?' do
        it 'check when exists' do
          provider.class.stubs(:network_exists?).returns(true)
          provider.class.stubs(:openstack)
                        .with('aggregate', 'list', '--quiet', '--format', 'csv', '--long')
                        .returns('"ID","Name","Availability Zone","Properties"
just,"simple","just","{u\'nice\': u\'cookie\'}"
')
          provider.class.stubs(:openstack)
                  .with('aggregate', 'show', '--format', 'shell', 'just')
                  .returns('availability_zone="simple"
id="just"
name="just"
properties="{u\'nice\': u\'cookie\'}"
hosts="[u\'example\']"
')

          provider.exists?
          expect(provider.exists?).to be_truthy
        end

        it 'check when non exists' do
          provider.class.stubs(:network_exists?).returns(true)
          provider.class.stubs(:openstack)
                        .with('aggregate', 'list', '--quiet', '--format', 'csv', '--long')
                        .returns('"ID","Name","Availability Zone","Properties"
')
          provider.exists?
          expect(provider.exists?).to be_falsey
        end
      end

      describe '#create' do
        it 'creates aggregate' do
          provider.class.stubs(:openstack)
                        .with('aggregate', 'list', '--quiet', '--format', 'csv', '--long')
                        .returns('"ID","Name","Availability Zone","Properties"
')
          provider.class.stubs(:openstack)
                  .with('aggregate', 'create', '--format', 'shell', ['just', '--zone', 'simple', '--property', 'nice=cookie' ])
                  .returns('name="just"
id="just"
availability_zone="simple"
properties="{u\'nice\': u\'cookie\'}"
hosts="[]"
')
          provider.class.stubs(:openstack)
                  .with('aggregate', 'add host', ['just', 'example'])
                  .returns('name="just"
id="just"
availability_zone="simple"
properties="{u\'nice\': u\'cookie\'}"
hosts="[u\'example\']"
')
          provider.exists?
          provider.create
          expect(provider.exists?).to be_falsey
        end
      end

      describe '#destroy' do
        it 'removes aggregate with hosts' do
          resource[:ensure] = :absent
          provider.class.stubs(:openstack)
                        .with('aggregate', 'list', '--quiet', '--format', 'csv', '--long')
                        .returns('"ID","Name","Availability Zone","Properties"
just,"simple","just","{u\'nice\': u\'cookie\'}"
')
           provider.class.stubs(:openstack)
                   .with('aggregate', 'show', '--format', 'shell', 'just')
                   .returns('availability_zone="simple"
id="just"
name="just"
properties="{u\'nice\': u\'cookie\'}"
hosts="[u\'example\']"
')
          provider.class.stubs(:openstack)
                  .with('aggregate', 'remove host', ['just', 'example'])
                  .returns('name="just"
id="just"
availability_zone="simple"
properties="{u\'nice\': u\'cookie\'}"
hosts="[]"
')
          provider.class.stubs(:openstack)
                  .with('aggregate', 'delete', 'just')
                  .returns('"ID","Name","Availability Zone","Properties"')

          provider.exists?
          expect(provider.exists?).to be_truthy
          provider.destroy
        end
      end

      describe '#flush' do
        it 'updates existing' do
          resource[:availability_zone] = 'new-zone'
          resource[:hosts] = 'new-host'
          provider.class.stubs(:openstack)
                        .with('aggregate', 'list', '--quiet', '--format', 'csv', '--long')
                        .returns('"ID","Name","Availability Zone","Properties"
just,"simple","just","{u\'nice\': u\'cookie\'}"
')
           provider.class.stubs(:openstack)
                   .with('aggregate', 'show', '--format', 'shell', 'just')
                   .returns('availability_zone="simple"
id="just"
name="just"
properties="{u\'nice\': u\'cookie\'}"
hosts="[u\'example\']"
')
          provider.class.stubs(:openstack)
                  .with('aggregate', 'set', ['just', '--zone', 'new-zone', '--property', 'nice=cookie' ])
                  .returns('name="just"
id="just"
availability_zone="new-zone"
properties="{u\'nice\': u\'cookie\'}"
hosts="[]"
')
          provider.class.stubs(:openstack)
                  .with('aggregate', 'remove host', ['just', 'example'])
                  .returns('name="just"
id="just"
availability_zone="new-zone"
properties="{u\'nice\': u\'cookie\'}"
hosts="[]"
')
          provider.class.stubs(:openstack)
                  .with('aggregate', 'add host', ['just', 'new-host'])
                  .returns('name="just"
id="just"
availability_zone="new-zone"
properties="{u\'nice\': u\'cookie\'}"
hosts="[u\'new-host\']"
')

          provider.exists?
          expect(provider.exists?).to be_truthy
          provider.flush
        end
      end

    end
  end
end
