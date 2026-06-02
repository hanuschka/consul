class RecipientGroupResolver
  def initialize(recipient_group)
    @recipient_group = recipient_group
  end

  def user_emails
    resolve.fetch(:emails).to_a
  end

  def count
    resolve.fetch(:emails).size
  end

  def per_filter_counts
    resolve.fetch(:per_filter)
  end

  private

    def resolve
      @resolve ||= compute
    end

    def compute
      emails = Set.new
      per_filter = []

      @recipient_group.filters.each_with_index do |filter, index|
        resolver = RecipientGroups::FilterResolvers.for(filter.kind).new(filter.params)
        new_emails = Set.new(resolver.emails.compact)

        previous_size = emails.size

        emails =
          case filter.operator
          when "include"   then index.zero? ? new_emails : emails | new_emails
          when "exclude"   then emails - new_emails
          when "intersect" then emails & new_emails
          else emails
          end

        per_filter << { id: filter.id, count: emails.size, delta: emails.size - previous_size }
      end

      { emails: emails, per_filter: per_filter }
    end
end
