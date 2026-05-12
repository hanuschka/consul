class Files::FilterBarComponent < ApplicationComponent
  SORT_OPTIONS = %w[
    created_desc created_asc updated_desc updated_asc
    name_asc name_desc size_asc size_desc
  ].freeze
end
