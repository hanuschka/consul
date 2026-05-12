class PdfServices::HtmlToPdf < ApplicationService
  def initialize(html)
    @html = html
  end

  def call
    # TODO: Implement when PDF renderer is chosen.
    # Options: Ferrum (pure Ruby CDP), Grover (Puppeteer), wicked_pdf (wkhtmltopdf)
    # See C_PLANS/CON-2783-pdf-rendering-options.md for comparison.
    raise NotImplementedError, "PDF renderer not yet configured"
  end
end
