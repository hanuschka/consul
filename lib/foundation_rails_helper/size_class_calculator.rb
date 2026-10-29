# Copied from the foundation_rails_helper gem 4.0.1 (MIT, see LICENSE in this
# directory), whose last release caps Rails below 7.1
class FoundationRailsHelper::SizeClassCalculator
  def initialize(size_options)
    @small = size_options[:small]
    @medium = size_options[:medium]
    @large = size_options[:large]
  end

  def classes
    [size_class("small", @small), size_class("medium", @medium), size_class("large", @large)]
      .compact
      .join(" ")
  end

  private

    def size_class(size_name, value)
      return if value.blank? || value.to_i >= 12

      "#{size_name}-#{value}"
    end
end
