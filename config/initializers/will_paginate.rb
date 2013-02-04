# REMOVE THIS IN RAILS 4
#
 module ActiveRecord
  module FinderMethods
    def construct_limited_ids_condition(relation)
      orders = relation.order_values.map { |val| val.presence }.compact
      values = @klass.connection.distinct("#{@klass.connection.quote_table_name table_name}.#{primary_key}", orders)

      relation = relation.dup
      relation.uniq_value = false # avoids SELECT DISTINCT DISTINCT

      ids_array = relation.select(values).collect {|row| row[primary_key]}
      ids_array.empty? ? raise(ThrowResult) : table[primary_key].in(ids_array)
    end
  end
end
