require 'responders' unless defined? ::ActionController::Responder

module Dossier
  class XXCustomResponder < Dossier::Responder

    def to_text
      controller.headers["Content-Type"] = "text/plain"
      set_content_disposition!
      controller.response_body = report.render_txt
    end

  end
end
