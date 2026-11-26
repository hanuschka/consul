# Variant URLs signed before 2024 still carry the old combine_options styles,
# which Active Storage rejects; unwrap them so those images keep rendering.
# Every unwrapped operation still goes through Rails' transformation checks.
module ActiveStorageCombineOptions
  private

    def operations
      combine_options_key = transformations.keys.find { it.to_s == "combine_options" }

      return super if combine_options_key.nil?

      original_transformations = @transformations
      @transformations = unwrap_combine_options(combine_options_key)

      begin
        super
      ensure
        @transformations = original_transformations
      end
    end

    def unwrap_combine_options(combine_options_key)
      transformations.each_with_object({}) do |(name, argument), unwrapped_transformations|
        if name == combine_options_key
          unwrapped_transformations.merge!(argument)
        else
          unwrapped_transformations[name] = argument
        end
      end
    end
end

Rails.application.config.after_initialize do
  ActiveStorage::Transformers::ImageProcessingTransformer.prepend(ActiveStorageCombineOptions)
end
