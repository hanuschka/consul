class Adm::MunicipalPlans::MemosController < Adm::MunicipalPlans::BaseController
  include Adm::MemoActions

  private

    def find_memoable
      memoable = super
      memoable.is_a?(MunicipalPlan) ? (memoable.released_plan || memoable) : memoable
    end
end
