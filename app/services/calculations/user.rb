module Calculations
  class User
    def self.bam_unique_stamp(first_name, last_name, birth_year, birth_month, birth_day, plz)
      return nil if first_name.nil? || last_name.nil? || birth_year.nil? || birth_month.nil? || birth_day.nil? || plz.nil?

      first_name + "_" +
        last_name + "_" +
        birth_year.to_s + "_" +
        birth_month.to_s + "_" +
        birth_day.to_s + "_" +
        plz.to_s
    end
  end
end
