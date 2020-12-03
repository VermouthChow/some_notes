# Just an emergency measure, not recommended!

# call origin to_json:
#   - obj.to_json(origin: true)

# call origin JSON.parse:
#   - JSON.parse(origin: true)

# example:
# - u = User.last.to_json(root: true)
# - JSON.parse(u, origin: true, symbolize_names: true)
# - JSON.parse(u, symbol_keys: true)

# more parse options:
#   - oj: https://github.com/ohler55/oj/blob/develop/pages/Options.md
#   - origin: https://msp-greg.github.io/ruby_2_7/json/JSON/Ext/Parser.html

# reference:
#   - https://github.com/GoodLife/rails-patch-json-encode

module JsonWithOj

  module Dump

    def to_json options = {}
      if options.is_a?(::JSON::State) || options.delete(:origin)
        super(options)
      else
        # Oj.dump(self.as_json(options), options)
        Oj.dump(self, options.merge(mode: :rails))
      end
    end
  end


  module Parse

    attr_accessor :options

    def initialize source, opts = {}
      @options = opts.deep_symbolize_keys

      # super
      # rails version 6.0: pass args **opts to avoid warning
      super(source, **opts)
    end

    def parse
      !!options.delete(:origin) ? super : ::Oj.load(source, options)
    rescue ::Oj::ParseError
      super
    end
  end

end

[Object, Array, FalseClass, Float, Hash, Integer, NilClass, String, TrueClass, Enumerable].reverse_each do |klass|
  klass.prepend(JsonWithOj::Dump)
end

# JSON::Ext::Parser
JSON::Parser.prepend(JsonWithOj::Parse)
