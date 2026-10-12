# Shared body of the three ai_generation_status endpoints (projekt, newsletter
# and site customization). They polled the same column and rebuilt the same
# payload three times, which is how the change-mode result and the progress
# step would have drifted apart.
#
# The step is stored as a bare key and translated here, because this runs in
# the editor's request locale while the job that wrote it does not.
class SiteCustomization::ContentBlocks::AiGenerationStatusPayload < ApplicationService
  def initialize(content_block:)
    @content_block = content_block
    @data = content_block.ai_generation_data || {}
  end

  def call
    payload = {
      status: status,
      content_block_id: @content_block.id,
      position: @content_block.position,
      mode: @data["mode"],
      step_label: step_label
    }

    payload[:body_html] = @content_block.body.to_s if status == "completed"
    payload[:error] = @data["error"] if status == "failed"
    payload[:content_block_html] = take_change_result if change_result?

    payload
  end

  private

    def status
      @status ||= @data["status"] || "completed"
    end

    def step_label
      return if @data["step"].blank?

      I18n.t("custom.projekt_content_blocks.ai_create.steps.#{@data["step"]}", default: nil)
    end

    def change_result?
      status == "completed" && @data["mode"] == "change"
    end

    # A change never reaches the body column — the editor applies the preview
    # and saves it itself — so the result is handed over once and cleared.
    def take_change_result
      html = @data["result_html"].to_s
      @content_block.update_column(:ai_generation_data, nil)

      html
    end
end
