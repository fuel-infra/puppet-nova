require 'puppet'
require 'spec_helper'
require 'puppet/provider/nova'
require 'rspec/mocks'

klass = Puppet::Provider::Nova

class Puppet::Provider::Nova
  @credentials = Puppet::Provider::Openstack::CredentialsV2_0.new
end

describe Puppet::Provider::Nova do

  let :credential_hash do
    {
      'auth_uri'     => 'https://192.168.56.210:35357/v2.0/',
      'admin_tenant_name' => 'admin_tenant',
      'admin_user'        => 'admin',
      'admin_password'    => 'password',
    }
  end

  let :auth_endpoint do
    'https://192.168.56.210:35357/v2.0/'
  end

  let :credential_error do
    /Nova types will not work/
  end

  after :each do
    klass.reset
  end

  describe 'when determining credentials' do

    it 'should fail if config is empty' do
      conf = {}
      klass.expects(:nova_conf).returns(conf)
      expect do
        klass.nova_credentials
      end.to raise_error(Puppet::Error, credential_error)
    end

    it 'should fail if config does not have keystone_authtoken section.' do
      conf = {'foo' => 'bar'}
      klass.expects(:nova_conf).returns(conf)
      expect do
        klass.nova_credentials
      end.to raise_error(Puppet::Error, credential_error)
    end

    it 'should fail if config does not contain all auth params' do
      conf = {'keystone_authtoken' => {'invalid_value' => 'foo'}}
      klass.expects(:nova_conf).returns(conf)
      expect do
       klass.nova_credentials
      end.to raise_error(Puppet::Error, credential_error)
    end

    it 'should use specified uri in the auth endpoint' do
      conf = {'keystone_authtoken' => credential_hash}
      klass.expects(:nova_conf).returns(conf)
      expect(klass.get_auth_endpoint).to eq(auth_endpoint)
    end

  end

  describe 'when invoking the nova cli' do

    it 'should set auth credentials in the environment' do
      authenv = {
        :OS_AUTH_URL    => auth_endpoint,
        :OS_USERNAME    => credential_hash['admin_user'],
        :OS_TENANT_NAME => credential_hash['admin_tenant_name'],
        :OS_PASSWORD    => credential_hash['admin_password'],
      }
      klass.expects(:get_nova_credentials).with().returns(credential_hash)
      klass.expects(:withenv).with(authenv)
      klass.auth_nova('test_retries')
    end

    ['[Errno 111] Connection refused',
     '(HTTP 400)'].reverse.each do |valid_message|
      it "should retry when nova cli returns with error #{valid_message}" do
        klass.expects(:get_nova_credentials).with().returns({})
        klass.expects(:sleep).with(10).returns(nil)
        klass.expects(:nova).twice.with(['test_retries']).raises(
          Exception, valid_message).then.returns('')
        klass.auth_nova('test_retries')
      end
    end

  end

  describe '#str2list' do
    it 'should return empty list' do
      s = "[]"
      expect(klass.str2list(s)).to eq([])
    end

    it 'should return list with value' do
      s = "[u'node-28.domain.tld', u'node-8.domain.tld']"
      expect(klass.str2list(s)).to eq(["node-28.domain.tld", "node-8.domain.tld"])
    end
  end

end
