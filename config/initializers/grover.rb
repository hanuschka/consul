Grover.configure do |config|
  config.options = {
    format: "A4",
    print_background: true,
    prefer_css_page_size: true,
    launch_args: ["--no-sandbox", "--disable-setuid-sandbox"],
    wait_until: "domcontentloaded",
    timeout: 60_000,
    margin: {
      top: "10mm",
      bottom: "10mm",
      left: "10mm",
      right: "10mm"
    }
  }
end
