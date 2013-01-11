class  ActiveModel::Serializer

  def add_since(rel)
    if scope.is_a?(Hash) && scope[:since].to_i > 0
      rel.where("#{rel.table.name}.updated_at > ?", Time.at(scope[:since].to_i))
    else
      rel
    end
  end

end
