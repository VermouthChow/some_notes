# a sample new json type render

module JsonxType
  extend ActiveSupport::Concern

  ActionController::Renderers.add :ojson do |obj, options|
    # self.content_type ||= Mime[:json]
    # media_type to avoid rails 6.0 warnning
    self.content_type = Mime[:json] unless media_type

    obj.is_a?(String) ? obj : Oj.dump(obj.as_json(options), options)
  end
end
