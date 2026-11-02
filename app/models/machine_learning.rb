class MachineLearning
  class << self
    def enabled?
      Setting["feature.machine_learning"].present?
    end
  end
end
