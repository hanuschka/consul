# frozen_string_literal: true

module Searches
  class Generic
    def self.perform(params, page = 1, per_page = 25) #Debate.default_per_page)
      @page = page || 1
      @per_page = per_page
      @query = params[:q]&.strip
      @params = params
      search
    end

    def self.search
      @params[:direction] ||= 'desc'
      @params[:order_by] ||= 'id'
      order_by = { 'id' => 'updated_at' }[@params[:order_by]] || 'id'

      selected_section = @params[:section] ? {selected_section: {
        filter: {
          term: { model_name: @params[:section] }
        },
        aggs: {
          tags: {
            terms: { field: "tags" }
          }
        }
      }} : {
        tags: {
          terms: { field: "tags" }
        }
       }


      terms = {
        sort: [
          { order_by.to_sym => { order: @params[:direction] } }
        ],

        query: {
          bool: {
            must: search_terms,
            filter:  {
              bool: {
                must: generate_term + generate_nested_term
              }
            }
          }
        },
        highlight: {
          tags_schema: "styled",
          fields: [
              { "locales.title" => {} },
              { "locales.description" => {} }
            ]
        },
        aggs: {
          genres: {
            terms: {
              field: "model_name"
            }
          },

        }.merge(selected_section),
        size: @per_page,
        from: (@page.to_i - 1) * @per_page
      }.merge(post_filter)
      p terms
      Elasticsearch::Model.search(terms, Searches::Import.all_types)
    end



    def self.post_filter
      if @params[:section] || @params[:tag]
        terms = { post_filter: {bool: {filter: []} }}
        if @params[:section]
          terms[:post_filter][:bool][:filter] << {term: {model_name: @params[:section] }}
        end
        if @params[:tag]
          #terms[:post_filter][:bool][:filter] << {term: {tags: @params[:tag]}}
        end
        terms
      else
        {}
      end
    end

    def self.generate_nested_term
      terms_all = []

      terms = []
      terms.push(match: { "locales.locale" => @params[:locale] })
      terms.push(multi_match: { query: @query, fields: ["locales.title", "locales.description"], operator: "and" })
      n = {nested: {
        path: "locales",
        query: {
          bool: {
            must: terms
          }
        },
        inner_hits: {
          highlight: {
            tags_schema: "styled",
            fields: [
              { "locales.title" => {} },
              { "locales.description" => {} }
            ]
          }

        }
      }}
      terms_all.push(n)

      terms_all
    end

    def self.generate_term
      terms = []
      if @params[:geozones] && @params[:geozones].any?
        terms.push(terms: { geozone_id: @params[:geozones] })
      end

      if @params[:tag] && !['site_customization_page', 'budget_investment', 'comment', 'poll'].include?(@params[:section])
        terms.push(term: { tags: @params[:tag] })
      end
      terms
    end

    def self.search_terms
      match = [{ match_all: {} }]
      match.push(term: { published: true })
      match
    end
  end

end