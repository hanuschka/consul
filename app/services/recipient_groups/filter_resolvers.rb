module RecipientGroups
  module FilterResolvers
    def self.for(kind)
      const_get(kind.to_s.camelize)
    end
  end
end
