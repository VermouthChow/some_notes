class LemonTree < ApplicationRecord
  include AnyThree

  belongs_to :parent, class_name: :LemonTree, optional: false
  has_many :children, class_name: :LemonTree
  has_many :active_children, -> { active }, class_name: :LemonTree
end



##################################### RECURSION ONE BY ONE  #####################################
module AnyThree
  extend ActiveSupport::Concern

  def groups_ids(children_name = :children)
    [self.id] + public_send(children_name).flat_map { |child| child.groups_ids(children_name) }
  end
end

# eg: node.groups_ids
# eg: [node_one, node_two].flat_map { |node| node.groups_ids(:active_children) }
# ==> N+1



##################################### LEFT JOINS PLUCK #####################################
module AnyThree
  extend ActiveSupport::Concern

  class_methods do

    def groups_ids(query_ids, children_name = :children)
      query_ids = Array.wrap query_ids
      return [] if query_ids.blank?

      next_ids = where(id: query_ids).left_joins(children_name).pluck("#{children_name}_#{table_name}.id").compact
      query_ids + groups_ids(next_ids, children_name)
    end

  end
end

# eg: LemonTree.groups_ids(node.id)
# eg: query_ids = [node_one, node_two].map &:id
# LemonTree.groups_ids(query_ids, :active_children)
# ==> Node height



##################################### PLUCK ALL IDS AND PARENT IDS TO HASH #####################################
module AnyThree
  extend ActiveSupport::Concern

  class_methods do

    def self.mapping
      @mapping ||= pluck(:id, :parent_id).group_by { |id_pid|
        id_pid.last
      }.transform_values { |id_pid|
        id_pid.map &:first
      }
    end

    def self.groups_ids(query_ids)
      query_ids = Array.wrap query_ids
      return [] if query_ids.blank?

      next_ids = mapping.values_at(*query_ids).compact.flatten
      query_ids + groups_ids(next_ids)
    end

  end
end

# eg: LemonTree.groups_ids(node.id)
# eg: query_ids = [node_one, node_two].map &:id
# LemonTree.groups_ids(query_ids)
# ==> no children_name
