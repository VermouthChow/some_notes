# class MySchema < GraphQL::Schema
#  ...
#  use GraphQL::Batch
# end
#
# AssociationLoader.for(klass, reflection_name, reflection).add_scope(-> { select(*selected_columns) }).load(object)

class AssociationLoader < GraphQL::Batch::Loader

  attr_accessor :model, :association_name, :association, :association_scope

  def self.validate(model, association_name, association)
    new(model, association_name, association)
    nil
  end

  def initialize(model, association_name, association)
    @model = model
    @association_name = association_name
    @association = association

    validate
  end

  def add_scope(association_scope = nil)
    @association_scope = association_scope

    validate_scope
    self
  end

  def cache_key(record)
    record.object_id
  end

  def load(record)
    raise TypeError, "#{model} loader can't load association for #{record.class}" unless record.is_a?(model)
    return Promise.resolve(read_association(record)) if association.has_scope? || association_loaded?(record)

    super
  end

  def perform(records)
    preload_association(records).each do |p|
      r = p.records_by_owner.to_h

      if association.collection?
        records.each { |record| fulfill record, r[record].to_a }
      else
        records.each { |record| fulfill record, r[record]&.first }
      end
    end
  end

  private

  def validate_scope
    unless association_scope.is_a?(Proc) || association_scope.instance_of?(NilClass)
      raise ArgumentError, "association scope #{association_scope.inspect} is invalid"
    end
  end

  def validate
    unless model.reflect_on_association(association_name)
      raise ArgumentError, "No association #{association_name} on #{model}"
    end
  end

  def preload_association(records)
    scope = association_scope ? association.klass.all.merge(association_scope) : nil
    preloaded = ::ActiveRecord::Associations::Preloader.new.preload(records, association_name, scope)

    raise "#{model} - #{association_name}: preload is nil" if preloaded.blank?

    preloaded
  end

  def read_association(record)
    if association_loaded?(record) || !record.public_send(association_name).respond_to?(:merge)
      record.public_send(association_name)
    else
      record.public_send(association_name).merge association_scope
    end

  end

  def association_loaded?(record)
    record.association(association_name).loaded?
  end
end

