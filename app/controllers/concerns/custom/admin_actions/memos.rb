module AdminActions::Memos
  extend ActiveSupport::Concern

  included do
    respond_to :js

    before_action :set_memoable, only: [:create]
    before_action :set_memo, only: [:destroy]
  end

  def create
    @memo = @memoable.memos.create!(memo_params.merge(user: current_user))
    render "admin/memos/create"
  end

  def destroy
    @memo.destroy!
    render "admin/memos/destroy"
  end

  private

    def memo_params
      params.require(:memo).permit(:text, :memoable_id, :memoable_type)
    end

    def set_memoable
      @memoable ||= memo_params[:memoable_type].constantize.find(memo_params[:memoable_id])
    end

    def set_memo
      @memo = Memo.find(params[:id])
    end
end
