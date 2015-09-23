require 'puppet/provider/nova'

Puppet::Type.type(:nova_aggregate).provide(
  :openstack,
  :parent => Puppet::Provider::Nova
) do
  desc <<-EOT
    Provider to manage nova aggregations
  EOT

  @credentials = Puppet::Provider::Openstack::CredentialsV2_0.new

  def initialize(value={})
    super(value)
    @property_flush = {}
  end

  def create
    properties = [@resource[:name]]
    if not @resource[:availability_zone].nil? and not @resource[:availability_zone].empty?
      properties << "--zone" << @resource[:availability_zone]
    end
    if not @resource[:metadata].nil? and not @resource[:metadata].empty?
      @resource[:metadata].each do |key, value|
        properties << "--property" << "#{key}=#{value}"
      end
    end
    @property_hash = self.class.request('aggregate', 'create', properties)

    if not @resource[:hosts].nil? and not @resource[:hosts].empty?
      @resource[:hosts].each do |host|
        properties = [@property_hash[:id], host]
        self.class.request('aggregate', 'add host', properties)
      end
    end
    @property_hash[:ensure] = :installed
  end

  def exists?
    aggregate_exists
    @property_hash[:ensure] == :present
  end

  def destroy
    if not @property_hash[:hosts].nil?
      @property_hash[:hosts].each do |h|
        properties = [@property_hash[:id], h]
        self.class.request('aggregate', 'remove host', properties)
      end
    end
    self.class.request('aggregate', 'delete', @property_hash[:id])
    @property_hash[:ensure] = :absent
  end

  def id
    @property_hash[:id]
  end

  def availability_zone
    @property_hash[:availability_zone]
  end

  def availability_zone=(value)
    @property_flush[:availability_zone] = value
  end

  def metadata
    @property_hash[:metadata]
  end

  def metadata=(value)
    @property_flush[:metadata] = value
  end

  def hosts
    @property_hash[:hosts]
  end

  def hosts=(value)
    @property_flush[:hosts] = value
  end

  def aggregate_exists
    list = self.class.request('aggregate', 'list', '--long')
    list.collect do |aggregate|
      attrs = self.class.request('aggregate', 'show', aggregate[:id])
      if attrs[:name].eql?(resource[:name])
        @property_hash= {
          :ensure            => :present,
          :id                => attrs[:id],
          :hosts             => self.class.str2list(attrs[:hosts]),
          :name              => attrs[:name],
          :availability_zone => attrs[:availability_zone],
          :metadata          => properties2hash(attrs[:properties]),
        }
      end
    end
  end

  def properties2hash(s)
    hash = {}
    s.split(",").each do |pairs|
      key = pairs.split(":")[0].match(/'.*?'/)
      x = key.to_s.gsub(/'/, "")
      value = pairs.split(":")[1].match(/'.*?'/)
      y = value.to_s.gsub(/'/, "")
      hash[x] = y unless key.nil? and value.nil?
    end
    return hash
  end

  def flush
    properties = [@property_hash[:name]]
    if @property_hash[:ensure] == :present
      properties << '--zone' << @resource[:availability_zone] if @resource[:availability_zone]
      if @resource[:metadata]
        @resource[:metadata].each do |key, value|
          properties << "--property" << "#{key}=#{value}"
        end
      end
      self.class.request('aggregate', 'set', properties)
      if @resource[:hosts]
        # remove hosts, which are not present in update
        @property_hash[:hosts].reject { |x| resource[:hosts].include? x }.each do |host|
          properties = [@property_hash[:id], host]
          self.class.request('aggregate', 'remove host', properties)
        end
        # add new hosts
        @resource[:hosts].reject { |x| @property_hash[:hosts].include? x }.each do |host|
          properties = [@property_hash[:id], host]
          self.class.request('aggregate', 'add host', properties)
        end
      end
    end
    @property_hash.clear
  end

end
