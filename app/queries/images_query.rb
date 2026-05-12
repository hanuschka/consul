class ImagesQuery
  ALLOWED_SORTS = {
    "created_desc" => "images.created_at DESC",
    "created_asc"  => "images.created_at ASC",
    "updated_desc" => "images.updated_at DESC",
    "updated_asc"  => "images.updated_at ASC",
    "name_asc"     => "active_storage_blobs.filename ASC",
    "name_desc"    => "active_storage_blobs.filename DESC",
    "size_asc"     => "active_storage_blobs.byte_size ASC",
    "size_desc"    => "active_storage_blobs.byte_size DESC"
  }.freeze

  DEFAULT_SORT = "created_desc".freeze

  def self.available_imageable_types
    Image.distinct.pluck(:imageable_type).compact.sort
  end

  def initialize(params)
    @params = params || {}
  end

  def call
    scope = Image.joins(attachment_attachment: :blob)
    scope = filter_search(scope)
    scope = filter_extension(scope)
    scope = filter_size(scope)
    scope = filter_created(scope)
    scope = filter_updated(scope)
    scope = filter_imageable_type(scope)
    apply_sort(scope)
  end

  private

    attr_reader :params

    def filter_search(scope)
      term = read_param(:search)
      return scope if term.blank?

      like = "%#{term.to_s.downcase}%"

      scope.where(
        "LOWER(images.title) LIKE :q OR LOWER(active_storage_blobs.filename) LIKE :q",
        q: like
      )
    end

    def filter_extension(scope)
      ext = read_param(:extension)
      return scope if ext.blank?

      scope.where("LOWER(active_storage_blobs.filename) LIKE ?", "%.#{ext.to_s.downcase}")
    end

    def filter_size(scope)
      scope = apply_size_min(scope)
      apply_size_max(scope)
    end

    def apply_size_min(scope)
      bytes = parse_megabytes(read_param(:size_min_mb))
      return scope if bytes.nil?

      scope.where("active_storage_blobs.byte_size >= ?", bytes)
    end

    def apply_size_max(scope)
      bytes = parse_megabytes(read_param(:size_max_mb))
      return scope if bytes.nil?

      scope.where("active_storage_blobs.byte_size <= ?", bytes)
    end

    def filter_created(scope)
      scope = apply_date_lower_bound(scope, :created_from, "images.created_at")
      apply_date_upper_bound(scope, :created_to, "images.created_at")
    end

    def filter_updated(scope)
      scope = apply_date_lower_bound(scope, :updated_from, "images.updated_at")
      apply_date_upper_bound(scope, :updated_to, "images.updated_at")
    end

    def filter_imageable_type(scope)
      value = read_param(:imageable_type)
      return scope if value.blank?

      scope.where(imageable_type: value)
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
      order_clause = ALLOWED_SORTS[sort_param] || ALLOWED_SORTS[DEFAULT_SORT]

      scope.reorder(Arel.sql(order_clause))
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
