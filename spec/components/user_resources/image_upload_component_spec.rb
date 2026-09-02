require "rails_helper"

describe UserResources::ImageUploadComponent, type: :component, controller: ApplicationController do
  # Override `sign_in` to use vc_test_controller (view_component 3.x changed the API,
  # but the project's rails_helper monkey-patch still references `controller`).
  def sign_in(user)
    allow(vc_test_controller).to receive(:current_user).and_return(user)
  end

  let(:user) { create(:user) }
  let(:deficiency_report) { create(:deficiency_report, author: user) }
  let(:image) { deficiency_report.build_image(user: user) }

  let(:builder) do
    ActionView::Helpers::FormBuilder.new(
      "deficiency_report[image_attributes]", image, vc_test_controller.view_context, {}
    )
  end

  def hint
    render_inline(described_class.new(builder, imageable: deficiency_report))
    page.text
  end

  before { sign_in(user) }

  it "announces the configured image size limit" do
    set_setting("uploads.images.max_size", 3)

    expect(hint).to include(
      I18n.t("custom.user_resources.image_upload.max_image_size", size: 3)
    )
  end

  it "announces the validation's fallback when no limit is configured" do
    set_setting("uploads.images.max_size", "")

    expect(hint).to include(
      I18n.t("custom.user_resources.image_upload.max_image_size", size: 10)
    )
  end
end
