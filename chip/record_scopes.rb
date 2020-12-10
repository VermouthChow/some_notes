# scopes record
# eg:
#
# class Any < ApplicationRecord
#   scope :a, -> { where(...) }
#   scope :b, ->(x) { where(...) }
#   scope :c, ->(x, y=nil) { where(...) }
# end
#
# Any.scopes_mark
#   --> [:a, :b, :c]
# Any.with_params_scopes_mark
#   --> [:b, :c]


module CustomizedScopes
  extend ActiveSupport::Concern

  included do

    class << self
      def scope(name, body, &block)
        (@scopes_mark ||= []) << name.to_sym
        (@with_params_scopes_mark ||= []) << name.to_sym if body.parameters.present?

        super
      end

      def scopes_mark
        @scopes_mark.to_a
      end

      def with_params_scopes_mark
        @with_params_scopes_mark.to_a
      end
    end

  end
end


# in application_record.rb(add to all), or any special model
include CustomizedScopes
