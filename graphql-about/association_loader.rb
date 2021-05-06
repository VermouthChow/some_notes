# class MySchema < GraphQL::Schema
#  ...
#  use GraphQL::Batch
# end
#
# AssociationLoader.for(klass, reflection_name, reflection).add_scope(-> { select(*selected_columns) }).load(object)

class AssociationLoader < GraphQL::Batch::Loader

  attr_accessor :model, :association_name, :association, :association_scope

  def self.validate(association, select_scope: [], where_scope: {})
    new(association, select_scope: select_scope, where_scope: where_scope)
    nil
  end

  def initialize(association, select_scope: [], where_scope: {})
    @association = association
    @model = association.active_record
    @association_name = association.name
    @association_scope = (proc { select(select_scope).where(where_scope) }) if select_scope.present? || where_scope.present?

    validate
  end

  def cache_key(record)
    record.object_id
  end

  def load(record)
    raise TypeError, "#{model} loader can't load association for #{record.class}" unless record.is_a?(model)
    return Promise.resolve(read_association(record)) if association.has_scope?.try(:parameters).present? || association_loaded?(record)

    super
  end

  def perform(records)
    key_values = {}

    preload_association(records).each do |p|
      p.records_by_owner.to_h.each do |k, v|
        key_values[k] ||= []
        key_values[k] += v.to_a
      end
    end

    if association.collection?
      records.each { |record| fulfill record, key_values[record].to_a }
    else
      records.each { |record| fulfill record, key_values[record]&.first }
    end
  end

  private

  def validate
    unless model.is_a? Class
      raise "#{model.inspect} is not a class"
    end

    unless model.reflect_on_association(association_name)
      raise ArgumentError, "No association #{association_name} on #{model}"
    end

    validate_scope
  end

  def validate_scope
    if association.polymorphic? && association_scope.present?
      raise ArgumentError, "association: #{association_name} is polymorphic, cannot add scope"
    end

    unless association_scope.is_a?(Proc) || association_scope.instance_of?(NilClass)
      raise ArgumentError, "association scope #{association_scope.inspect} is invalid"
    end
  end

  def preload_association(records)
    scope = association_scope ? association.klass.all.merge(association_scope) : nil

    # clear loaded cache of through reflection
    # TODO remove
    if association.through_reflection?
      filter_chain_names = association.chain[1..-1].filter_map { _1.name if model.reflect_on_association(_1.name) }

      filter_chain_names.each do |n|
        records.select { _1.association(n).loaded? }.each { _1.association(n).reset }
      end
    end

    preloaded = ::ActiveRecord::Associations::Preloader.new.preload(records, association_name, scope)

    raise "#{model} - #{association_name}: preload is nil" if preloaded.blank?

    preloaded
  end

  def read_association(record)
    if association_loaded?(record) || association_scope.nil? || !record.public_send(association_name).respond_to?(:merge)
      record.public_send(association_name)
    else
      record.public_send(association_name).merge association_scope
    end
  end

  def association_loaded?(record)
    record.association(association_name).loaded?
  end
end

