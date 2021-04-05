# frozen_string_literal: true

module Searches
  class Import
    def self.process
      all_types.each do |c|
        c.__elasticsearch__.delete_index! if c.__elasticsearch__.index_exists?
        c.__elasticsearch__.create_index!
        c.import
      end
    end

    def self.all_types
      [Debate, Proposal, Budget::Investment, Legislation::Proposal, Poll, SiteCustomization::Page, Comment]
    end
  end
end