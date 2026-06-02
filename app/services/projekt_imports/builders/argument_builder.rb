class ProjektImports::Builders::ArgumentBuilder < ProjektImports::Builders::Base
  def call
    Array(payload).each_with_index.filter_map do |arg, i|
      next nil if arg["name"].blank? || arg["note"].blank?

      phase.projekt_arguments.create!(
        name: arg["name"],
        position: arg["position"].presence || i + 1,
        note: arg["note"],
        pro: ActiveModel::Type::Boolean.new.cast(arg["pro"])
      )
    rescue ActiveRecord::RecordInvalid => e
      raise ProjektImports::Builders::BuilderError, "argument(#{arg['name']}): #{e.message}"
    end
  end
end
