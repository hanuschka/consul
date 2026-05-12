class CkeditorAssetsQuery
  ALLOWED_SORTS = {
    "created_desc" => { created_at: :desc },
    "created_asc"  => { created_at: :asc },
    "updated_desc" => { updated_at: :desc },
    "updated_asc"  => { updated_at: :asc },
    "name_asc"     => { data_file_name: :asc },
    "name_desc"    => { data_file_name: :desc },
    "size_asc"     => { data_file_size: :asc },
    "size_desc"    => { data_file_size: :desc }
  }.freeze

  DEFAULT_SORT = "created_desc".freeze

  TYPE_MAP = {
    "picture"  => "Ckeditor::Picture",
    "document" => "Ckeditor::Document"
  }.freeze

  def initialize(params)
    @params = params || {}
  end

  def call
    scope = Ckeditor::Asset.joins(:storage_data_attachment)
    scope = filter_type(scope)
    scope = filter_search(scope)
    scope = filter_extension(scope)
    scope = filter_size(scope)
    scope = filter_created(scope)
    scope = filter_updated(scope)
    apply_sort(scope)
  end

  private

    attr_reader :params

    def filter_type(scope)
      type_param = read_param(:type)
      return scope if type_param.blank?

      mapped = TYPE_MAP[type_param.to_s]
      return scope if mapped.blank?

      scope.where(type: mapped)
    end

    def filter_search(scope)
      term = read_param(:search)
      return scope if term.blank?

      scope.merge(Ckeditor::Asset.search(term))
    end

    def filter_extension(scope)
      ext = read_param(:extension)
      return scope if ext.blank?

      scope.where("LOWER(data_file_name) LIKE ?", "%.#{ext.to_s.downcase}")
    end

    def filter_size(scope)
      scope = apply_size_min(scope)
      apply_size_max(scope)
    end

    def apply_size_min(scope)
      bytes = parse_megabytes(read_param(:size_min_mb))
      return scope if bytes.nil?

      scope.where("data_file_size >= ?", bytes)
    end

    def apply_size_max(scope)
      bytes = parse_megabytes(read_param(:size_max_mb))
      return scope if bytes.nil?

      scope.where("data_file_size <= ?", bytes)
    end

    def filter_created(scope)
      scope = apply_date_lower_bound(scope, :created_from, :created_at)
      apply_date_upper_bound(scope, :created_to, :created_at)
    end

    def filter_updated(scope)
      scope = apply_date_lower_bound(scope, :updated_from, :updated_at)
      apply_date_upper_bound(scope, :updated_to, :updated_at)
    end

    def apply_date_lower_bound(scope, param_key, column)
      date = parse_date(read_param(param_key))
      return scope if date.nil?

      scope.where("#{column} >= ?", date.beginning_of_day)
    end

    def apply_date_upper_bound(scope, param_key, column)
      date = parse_date(read_param(param_key))
      return scope if date.nil?

      scope.where("#{column} <= ?", date.end_of_day)
    end

    def apply_sort(scope)
      sort_param = read_param(:sort).to_s
      order_hash = ALLOWED_SORTS[sort_param] || ALLOWED_SORTS[DEFAULT_SORT]

      scope.reorder(order_hash)
    end

    def read_param(key)
      return params[key] if params.key?(key)

      params[key.to_s]
    end

    def parse_megabytes(value)
      return nil if value.blank?

      string_value = value.to_s.strip
      return nil if string_value.empty?
      return nil if string_value !~ /\A\d+\z/

      string_value.to_i.megabytes
    end

    def parse_date(value)
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end
end
