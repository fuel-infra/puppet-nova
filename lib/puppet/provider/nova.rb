# Run test ie with: rspec spec/unit/provider/nova_spec.rb

require 'puppet/util/inifile'
require 'puppet/provider/openstack'
require 'puppet/provider/openstack/auth'
require 'puppet/provider/openstack/credentials'

class Puppet::Provider::Nova < Puppet::Provider::Openstack

  extend Puppet::Provider::Openstack::Auth

  def self.request(service, action, properties=nil)
    begin
      super
    rescue Puppet::Error::OpenstackAuthInputError => error
      nova_request(service, action, error, properties)
    end
  end

  def self.nova_request(service, action, error, properties=nil)
    @credentials.username = nova_credentials['admin_user']
    @credentials.password = nova_credentials['admin_password']
    @credentials.project_name = nova_credentials['admin_tenant_name']
    @credentials.auth_url = auth_endpoint
    raise error unless @credentials.set?
    Puppet::Provider::Openstack.request(service, action, properties, @credentials)
  end

  def self.conf_filename
    '/etc/nova/nova.conf'
  end

  def self.withenv(hash, &block)
    saved = ENV.to_hash
    hash.each do |name, val|
      ENV[name.to_s] = val
    end

    yield
  ensure
    ENV.clear
    saved.each do |name, val|
      ENV[name] = val
    end
  end

  def self.nova_conf
    return @nova_conf if @nova_conf
    @nova_conf = Puppet::Util::IniConfig::File.new
    @nova_conf.read(conf_filename)
    @nova_conf
  end

  def self.nova_credentials
    @nova_credentials ||= get_nova_credentials
  end

  def nova_credentials
    self.class.nova_credentials
  end

  def self.get_nova_credentials
    #needed keys for authentication
    auth_keys = ['auth_host', 'auth_port', 'auth_protocol',
                 'admin_tenant_name', 'admin_user', 'admin_password']
    conf = nova_conf
    if conf and conf['keystone_authtoken'] and
        auth_keys.all?{|k| !conf['keystone_authtoken'][k].nil?}
      return Hash[ auth_keys.map \
                   { |k| [k, conf['keystone_authtoken'][k].strip] } ]
    else
      raise(Puppet::Error, "File: #{conf_filename} does not contain all " +
            "required sections.  Nova types will not work if nova is not " +
            "correctly configured.")
    end
  end

  def self.get_auth_endpoint
    q = nova_credentials
    "#{q['auth_protocol']}://#{q['auth_host']}:#{q['auth_port']}/v2.0/"
  end

  def self.auth_endpoint
    @auth_endpoint ||= get_auth_endpoint
  end

  def self.auth_nova(*args)
    q = nova_credentials
    authenv = {
      :OS_AUTH_URL    => self.auth_endpoint,
      :OS_USERNAME    => q['admin_user'],
      :OS_TENANT_NAME => q['admin_tenant_name'],
      :OS_PASSWORD    => q['admin_password']
    }
    begin
      withenv authenv do
        nova(args)
      end
    rescue Exception => e
      if (e.message =~ /\[Errno 111\] Connection refused/) or
          (e.message =~ /\(HTTP 400\)/)
        sleep 10
        withenv authenv do
          nova(args)
        end
      else
       raise(e)
      end
    end
  end

  def auth_nova(*args)
    self.class.auth_nova(args)
  end

  def self.reset
    @nova_conf = nil
    @nova_credentials = nil
  end

  def self.str2list(s)
    list = []
    s.split(",").each do |el|
      # take all in single quotes and then remove quotes
      matching = el.match(/'.*?'/)
      list.push(matching.to_s.gsub(/'/, "")) unless matching.nil?
    end
    return list
  end

end
