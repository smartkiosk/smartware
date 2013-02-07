module Smartware
  module Client
    @@instances = {}

    def self.instance(url)
      if @@instances.include? url
        @@instances[url]
      else
        instance = ::DRbObject.new_with_uri(url)
        @@instances[url] = instance
      end
    end
  end
end
