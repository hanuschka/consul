module RecipientGroups
  module FilterResolvers
    def self.for(kind)
      "RecipientGroups::FilterResolvers::#{kind.to_s.camelize}".constantize
    end
  end
end
