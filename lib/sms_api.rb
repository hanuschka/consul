require "open-uri"
require 'net/http'
class SMSApi

  def sms_deliver(phone, code)
    return stubbed_response unless end_point_available?
    message = "Your verification code: #{code}"
    params = {'receiver' => phone, 'msg' => message, 'sender' => 'SMSInfo', 'msgtype' => 't'}
    params['id'] = Rails.application.secrets.sms_username
    params['pw'] = Rails.application.secrets.sms_password

    prm = URI.encode_www_form params

    url = URI.parse(Rails.application.secrets.sms_end_point + "?" + prm)
    resp = Net::HTTP.get(url)
    resp.to_s == "OK"
  end

  def end_point_available?
    return !Rails.application.secrets.sms_password.blank?
    Rails.env.staging? || Rails.env.preproduction? || Rails.env.production?
  end

  def stubbed_response
    {
      respuesta_sms: {
        identificador_mensaje: "1234567",
        fecha_respuesta: "Thu, 20 Aug 2015 16:28:05 +0200",
        respuesta_pasarela: {
          codigo_pasarela: "0000",
          descripcion_pasarela: "Operación ejecutada correctamente."
        },
        respuesta_servicio_externo: {
          codigo_respuesta: "1000",
          texto_respuesta: "Success"
        }
      }
    }
  end
end
