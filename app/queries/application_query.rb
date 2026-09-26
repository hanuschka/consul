class ApplicationQuery
  def self.call(*args, **kwargs, &block)
    new(*args, **kwargs).call(&block)
  end

  # Opt-in: only queries that define #exists? answer it. A caller asking whether
  # a list would have any rows should not pay for building the rows.
  def self.exists?(*args, **kwargs)
    new(*args, **kwargs).exists?
  end

  private

    def apply_sorting(base_scope)
      field = params[:sort_by]&.to_sym
      return base_scope unless sortable_fields.include?(field)

      direction = params[:sort_direction]&.downcase
      direction = %w[asc desc].include?(direction) ? direction : "asc"

      base_scope.reorder(field => direction)
    end

    def apply_search(base_scope)
      searchable_params.each do |field, value|
        next if value.blank?

        arel_field = base_scope.klass.arel_table[field]
        base_scope = base_scope.where(arel_field.matches("%#{escape_like(value)}%"))
      end
      base_scope
    end

    def searchable_params
      params
        .permit(*searchable_param_keys)
        .to_h
        .transform_keys { |k| k.delete_suffix(search_suffix).to_sym }
    end

    def searchable_param_keys
      searchable_fields.map { |f| "#{f}#{search_suffix}" }
    end

    def search_suffix
      "__search"
    end

    def escape_like(value)
      ActiveRecord::Base.sanitize_sql_like(value)
    end

    def apply_filters(base_scope)
      filterable_params.each do |field, values|
        next if values.blank?

        base_scope = base_scope.where(field => values)
      end
      base_scope
    end

    def filterable_params
      params.permit(filterable_fields.index_with { [] }).to_h.symbolize_keys
    end

    def sortable_fields
      []
    end

    def searchable_fields
      []
    end

    def filterable_fields
      []
    end

    def params
      raise NotImplementedError
    end
end
