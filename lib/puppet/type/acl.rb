require 'puppet/type'

Puppet::Type.newtype(:acl) do
  require 'puppet/type/acl/ace'

  @doc = <<-'EOT'
    Manages access control lists.  The `acl` type is typically
    used when you need more complex management of permissions
    e.g. Windows.

    Sample usage:

      ADD HERE LATER
  EOT

  ensurable

  feature :ace_order_required, "The provider determines if the order of access control entries (ACE) is required."
  feature :can_inherit_parent_permissions, "The provider can inherit permissions from the parent."

  def initialize(*args)
    super

    # if target is unset, use the title
    if self[:target].nil? then
      self[:target] = self[:name]
    end
  end

  newparam(:name) do
    desc "The name of the acl resource. Used for uniqueness. Will set
      to the target if target is unset."

    validate do |value|
      if value.nil? or value.empty?
        raise ArgumentError, "A non-empty name must be specified."
      end
    end

    isnamevar
  end

  newparam(:target) do
    desc "The location the acl resource is pointing to. In the first
      release of ACL, this will be a file system location.
      The default is the name."

    validate do |value|
      if value.nil? or value.empty?
        raise ArgumentError, "A non-empty target must be specified."
      end
    end
  end

  newparam(:target_type) do
    desc "The type of target for the Acl resource. In the first release
      of ACL, only :file is allowed. Defaults to :file."
    newvalues(:file)
    defaultto(:file)
  end

  newparam(:purge, :boolean => true) do
    desc "Purge specifies whether to remove other explicit permissions
      if not specified in the permissions set. This doesn't do anything
      with permissions inherited from parents. The default is false."
    newvalues(:true, :false)
    defaultto(false)
  end

  newproperty(:permissions, :array_matching => :all) do
    desc "Permissions is an array containing Access Control Entries
      (ACEs). Certain Operating Systems require these ACEs to be in
      explicit order (Windows)."

    validate do |value|
      if value.nil? or value.empty?
        raise ArgumentError, "A non-empty permissions must be specified."
      end
    end

    munge do |permission|
      Puppet::Type::Acl::Ace.new(permission)
    end

    def insync?(current)
      if provider.respond_to?(:permissions_insync?)
        return provider.permissions_insync?(current, @should)
      end

      super(current)
    end

    def is_to_s(currentvalue)
      if provider.respond_to?(:permissions_to_s)
        return provider.permissions_to_s(currentvalue)
      end

      super(currentvalue)
    end
    alias :should_to_s :is_to_s
  end

  newproperty(:owner) do
    desc "The owner identity is also known as a trustee or principal
      that is said to own the particular acl/security descriptor. This
      can be in the form of: 1. User - e.g. 'Bob' or 'TheNet\\Bob',
      2. Group e.g. 'Administrators' or 'BUILTIN\\Administrators', 3.
      SID (Security ID) e.g. 'S-1-5-18'. Defaults to 'S-1-5-32-544'
      (Administrators) on Windows."

    validate do |value|
      if value.nil? or value.empty?
        raise ArgumentError, "A non-empty owner must be specified."
      end
    end

    #todo check platform and return specific default - this may not always be windows
    defaultto 'S-1-5-32-544'

    def insync?(current)
      if provider.respond_to?(:owner_insync?)
        return provider.owner_insync?(current, should)
      end

      super(current)
    end

    def is_to_s(currentvalue)
      if provider.respond_to?(:owner_to_s)
        return provider.owner_to_s(currentvalue)
      end

      super(currentvalue)
    end
    alias :should_to_s :is_to_s
  end

  newproperty(:inherit_parent_permissions, :boolean => true) do
    desc "Inherit Parent Permissions specifies whether to inherit
      permissions from parent ACLs or not. The default is true."
    #todo set this based on :can_inherit_parent_permissions
    newvalues(:true,:false)
    defaultto(true)

    def insync?(current)
      super(resource.munge_boolean(current))
    end
  end

  validate do
    if self[:permissions] == []
      raise ArgumentError, "Value for permissions should be an array with at least one element specified."
    end
  end

  autorequire(:file) do
    # review - autorequire is a soft dependency, is it a waste of cycles to attempt to find one versus just soft require?
    required_file = []
    if self[:target] && self[:target_type] == :file
      target_path = File.expand_path(self[:target]).to_s

      if file_resource = catalog.resource(:file, target_path)
        required_file << file_resource.to_s
      end

      if required_file == []
        # There is a bug with the casing on the volume (c:/ versus C:/) causing resources to not be found by the catalog
        #  checking against lowercase and uppercase corrects that.
        target_path_length = target_path.length
        if target_path_length && target_path_length > 2
          if file_resource = catalog.resource(:file, target_path[0].downcase << target_path[1, target_path_length - 1])
            required_file << file_resource.to_s
          end

          if required_file == [] && file_resource = catalog.resource(:file, target_path[0].upcase << target_path[1, target_path_length - 1])
            required_file << file_resource.to_s
          end
        end
      end
    end

    required_file
  end

  def munge_boolean(value)
    case value
      when true, "true", :true
        :true
      when false, "false", :false
        :false
      else
        fail("munge_boolean only takes booleans")
    end
  end

end
