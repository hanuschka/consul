Grover.configure do |config|
  config.options = {
    format: "A4",
    print_background: true,
    prefer_css_page_size: true,
    margin: {
      top: "15mm",
      bottom: "15mm",
      left: "15mm",
      right: "15mm"
    }
  }
end
