# module Types
#   class BaseObject < GraphQL::Schema::Object
#     field_class.prepend Extensions::FieldExtraOptions
#   end
# end
#
# field ..., extras: [:lookahead]
# Extensions::FieldExtraOptions.selected_columns klass, lookahead
# Extensions::FieldExtraOptions.partial_select result, klass, options[:lookahead]


module Extensions
  module FieldExtraOptions

    attr_accessor :depends_on, :owner_name, :field_name

    @@depends_on_mapping = {}

    def initialize(*args, **kwargs, &block)
      @depends_on = kwargs.delete(:depends_on).to_a
      @owner_name = kwargs[:owner].name.to_sym
      @field_name = kwargs[:name]

      push_depends_on_mapping

      super
    end

    def push_depends_on_mapping
      if depends_on.present?
        field_scope = @@depends_on_mapping.dig(owner_name, field_name).to_a | depends_on
        @@depends_on_mapping[owner_name] = @@depends_on_mapping[owner_name].to_h.merge(field_name => field_scope)
      end

      @@depends_on_mapping
    end

    def self.partial_select records, klass, lookahead
      return records if lookahead.blank?
      return records unless klass.ancestors.include? ApplicationRecord

      select_columns = selected_columns klass, lookahead
      records.select(*select_columns)
    end

    def self.selected_columns(klass, lookahead)
      column_names = klass.column_names.map(&:to_sym)
      return column_names if lookahead.blank?

      text_column_names = klass.columns.inject([]) { |r, cs| cs.type.to_sym == :text ? (r << cs.name.to_sym) : r }
      return column_names if text_column_names.blank?

      selection_names = lookahead.selections.map { |s| s.name.to_sym }
      not_required_text = text_column_names - selection_names
      return column_names if not_required_text.blank?

      klass_type_name = 'Types::' + klass.name + 'Type'
      klass_mapping = @@depends_on_mapping[klass_type_name.to_sym].to_h

      depends_on_columns = klass_mapping.flat_map { |selection, depends|
        selection.in?(selection_names) ? depends : []
      }

      not_in_tables = depends_on_columns.select { |depend| column_names.exclude? depend }
      raise "depends on columns: #{not_in_tables.inspect} not in class: #{klass.name}" if not_in_tables.present?

      column_names - not_required_text + depends_on_columns
    end

  end
end


