module Net
  class SMTP
    def disable_tls
      @tls = false
      @ssl_context_tls = nil
      @tls_verify = false
    end
  end
end
