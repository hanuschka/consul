load Rails.root.join("app", "helpers", "cache_keys_helper.rb")

module CacheKeysHelper
  def change_of_current_state(start_date, end_date)
    starting = ( !start_date.nil? && start_date < Date.today ) ? "1" : "0"
    ending = ( !end_date.nil? && end_date >= Date.today ) ? "1" : "0"
    starting + ending
  end
end
