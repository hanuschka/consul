module RecipientGroups
  module FilterResolvers
    class Base
      attr_reader :params

      def initialize(params)
        @params = (params || {}).with_indifferent_access
      end

      def emails
        raise NotImplementedError, "#{self.class} must implement #emails"
      end
    end
  end
end
