#
# Copyright 2018-2019 (c) Andrey Galkin
#

Puppet::Type.newtype(:cflogsink_endpoint) do
    desc "DO NOT USE DIRECTLY."
    
    autorequire(:cfsystem_flush_config) do
        ['begin']
    end
    autorequire(:cfsystem_memory_calc) do
        ['total']
    end
    autonotify(:cfsystem_flush_config) do
        ['commit']
    end
    
    ensurable do
        defaultvalues
        defaultto :absent
    end
    
    
    newparam(:name) do
        isnamevar
    end
    
    newproperty(:user) do
        validate do |value|
            unless value =~ /^[a-zA-Z_][a-zA-Z0-9_-]*$/
                raise ArgumentError, "%s is not valid user" % value
            end
        end
    end

    newproperty(:type) do
    end
    
    newproperty(:root_dir) do
        validate do |value|
            unless value =~ /^(\/[a-z0-9_]+)+$/i
                raise ArgumentError, "%s is not a valid path" % value
            end
        end
    end

    newproperty(:memory_weight) do
        validate do |value|
            unless value.is_a? Integer and value > 0
                raise ArgumentError, "%s is not a valid positive integer" % value
            end
        end
    end

    newproperty(:cpu_weight) do
        validate do |value|
            unless value.is_a? Integer and value > 0
                raise ArgumentError, "%s is not a valid positive integer" % value
            end
        end
    end
    
    newproperty(:io_weight) do
        validate do |value|
            unless value.is_a? Integer and value > 0
                raise ArgumentError, "%s is not a valid positive integer" % value
            end
        end
    end
    
    newproperty(:settings_tune) do
        validate do |value|
            value.is_a? Hash
        end
    end
    
    newproperty(:service_name) do
        validate do |value|
            unless value =~ /^[a-z0-9_@-]+$/i
                raise ArgumentError, "%s is not a valid service name" % value
            end
        end
    end

    newproperty(:location) do
        validate do |value|
            value.is_a? String
        end
    end
end
