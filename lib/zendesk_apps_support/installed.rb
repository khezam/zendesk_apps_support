require 'erubis'

module ZendeskAppsSupport
  class Installed
    INSTALLED_TEMPLATE = Erubis::Eruby.new( File.read(File.expand_path('../assets/installed.js.erb', __FILE__)) )

    def initialize(appsjs , installations = [])
      @appsjs = appsjs
      @installations = installations
    end

    def readified_js(installation_order = [])
      INSTALLED_TEMPLATE.result(
        appsjs: @appsjs,
        installations: @installations,
        installation_orders: installation_order
      )
    end
  end
end
