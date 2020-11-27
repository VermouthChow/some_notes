# class MySchema < GraphQL::Schema
#   ...
#   use GraphQL::Batch
# end
#
# RecordLoader.for(User, [:name, :age]).load(name: object.name, age: object.age)
# RecordLoader.for(User, :name).load(name: object.name)

# Promise.all([
#   (object.relation && RecordLoader.for(User, [:name]).add_scope(-> { select(:id, :name).where(public: true) }).load(name: object.reloation.name)),
#   RecordLoader.for(Pet, [:name]).add_scope(-> { select(:id, :name).where(public: true) }).load(name: object.pet.name),
# ]).then do |results|
#   m = {
#     user_id: results.detect { |r| r.instance_of? User }.id,
#     pet_id: results.detect { |r| r.instance_of? Pet }.id
#   }
#
#   RecordLoader.for(Customer, [:user_id, pet_id]).load(m)
# end
#
# RecordLoader.for(Product).load(id).then do |product|
#   RecordLoader.for(Image).load(product.image_id)
# end


class RecordLoader < GraphQL::Batch::Loader
  attr_accessor :model, :columns, :columns_type_map, :record_scope, :collection_flag

  COLLECTION_FLAG = [true, false].freeze

  def initialize(model, columns = model.primary_key, collection_flag = false)
    @model = model
    @collection_flag = collection_flag
    @columns = Array.wrap(columns).uniq.map &:to_sym
    @columns_type_map = @columns.map { |column|
      [column, model.type_for_attribute(column)]
    }.to_h
  end

  def add_scope(record_scope = nil)
    @record_scope ||= record_scope

    validate_scope
    self
  end

  def load(keys_map)
    valid_map = keys_map.symbolize_keys.slice(*columns)

    cast_keys_map = valid_map.map { |c, v|
      [c, columns_type_map[c.to_sym].cast(v)]
    }.to_h

    super(cast_keys_map)
  end

  def perform(all_keys_map)
    if collection_flag
      nil_default = []

      query(all_keys_map).group_by { |record|
        record.slice(*columns).symbolize_keys

      }.each { |key, records|
        fulfill key, records
      }
    else

      nil_default = nil

      query(all_keys_map).each { |record|
        fulfill record.slice(*columns), record
      }
    end

    all_keys_map.each { |keys_map|
      fulfill(keys_map, nil_default) unless fulfilled?(keys_map)
    }
  end

  def cache_key(keys_map)
    keys_map.symbolize_keys.hash
  end

  private

  def query(all_keys_map)
    base_scope = model.all
    base_scope = base_scope.merge record_scope if record_scope

    if columns.count == 1
      query_in(all_keys_map, base_scope)
    else
      query_or(all_keys_map, base_scope)
    end
  end

  def query_in(all_keys_map, base_scope)
    key = columns.first
    values = all_keys_map.map(&:values).flatten

    base_scope.where(key => values)
  end

  def query_or(all_keys_map, base_scope)
    all_keys_map.inject(nil) { |scope, m|
      scope ? scope.or(base_scope.where(m)) : base_scope.where(m)
    }
  end

  def validate_scope
    unless record_scope.is_a?(Proc) || record_scope.instance_of?(NilClass)
      raise ArgumentError, "record scope #{record_scope.inspect} is invalid"
    end
  end

  def validate
    unless model.is_a? Class
      raise ArgumentError, "#{model.inspect} is not a class"
    end

    unless collection_flag.in? COLLECTION_FLAG
      raise ArgumentError, "collection_flag should in #{COLLECTION_FLAG.inspect}"
    end

    if !columns.is_a?(Array) || columns.blank?
      raise ArgumentError, "columns #{columns.inspect} is invalid"
    end
  end
end
