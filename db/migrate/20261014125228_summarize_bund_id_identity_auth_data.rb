class SummarizeBundIdIdentityAuthData < ActiveRecord::Migration[6.1]
  class Identity < ActiveRecord::Base
    self.table_name = "identities"
  end

  def up
    summarized = 0

    Identity.where(provider: "bund_id").where.not(auth_data: [nil, ""]).find_each do |identity|
      raw_info = parsed_raw_info(identity.auth_data)
      next if raw_info.nil?

      identity.update_columns(auth_data: summary(raw_info, identity.updated_at).to_json)
      summarized += 1
    end

    say "identities: replaced the BundID data of #{summarized} identities with a summary"
  end

  def down
  end

  private

    def parsed_raw_info(auth_data)
      raw_info = JSON.parse(auth_data).dig("extra", "raw_info")
      raw_info.is_a?(Hash) ? raw_info : nil
    rescue JSON::ParserError
      {}
    end

    def summary(raw_info, received_at)
      {
        verification_level: raw_info["verification_level"],
        auth_method: raw_info["auth_method"],
        attributes: raw_info.reject { |_, value| value.blank? }.keys.sort,
        received_at: received_at&.iso8601
      }
    end
end
