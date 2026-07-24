# frozen_string_literal: true

require 'rails/generators'

module BlacklightMaps
  class Install < Rails::Generators::Base
    source_root File.expand_path('templates', __dir__)

    desc 'Install Blacklight-Maps'

    LEAFLET_VERSION = '1.9.4'
    MARKERCLUSTER_VERSION = '1.5.3'

    def verify_blacklight_installed
      return if IO.read('app/controllers/application_controller.rb').include?('include Blacklight::Controller')

      say_status('info', 'BLACKLIGHT NOT INSTALLED; GENERATING BLACKLIGHT', :blue)
      generate 'blacklight:install'
    end

    def add_javascript
      if using_importmaps?
        append_to_file 'app/javascript/application.js' do
          <<~JS

            import BlacklightMaps from "blacklight-maps"
            new BlacklightMaps().connect()
          JS
        end
        say_status('info', 'Added BlacklightMaps import to app/javascript/application.js', :green)
      elsif using_jsbundling?
        yarn_add_blacklight_maps
        append_to_file 'app/javascript/application.js' do
          <<~JS

            import BlacklightMaps from "blacklight-maps"
            new BlacklightMaps().connect()
          JS
        end
        say_status('info', 'Added blacklight-maps npm package and import to app/javascript/application.js', :green)
      else
        say_status('warning', 'Could not detect importmap-rails or a package.json. Add BlacklightMaps JS manually.', :yellow)
      end
    end

    def add_stylesheet
      main_scss = %w[
        app/assets/stylesheets/application.bootstrap.scss
        app/assets/stylesheets/application.scss
      ].find { |f| File.exist?(f) }

      return say_status('warning', 'Could not find main SCSS file. Add Leaflet CSS and blacklight-maps styles manually.', :yellow) unless main_scss

      yarn_add_blacklight_maps
      prepend_to_file(main_scss) { leaflet_cdn_imports }
      append_to_file main_scss, "\n@import \"blacklight-maps/app/assets/stylesheets/blacklight_maps/default\";\n"
    end

    def inject_search_builder
      inject_into_file 'app/models/search_builder.rb',
                       after: /include Blacklight::Solr::SearchBuilderBehavior.*$/ do
        "\n  include BlacklightMaps::MapsSearchBuilderBehavior\n"
      end
    end

    def install_catalog_controller_mixin
      inject_into_file 'app/controllers/catalog_controller.rb',
                       after: /include Blacklight::Catalog.*$/ do
        "\n  include BlacklightMaps::Controller\n"
      end
    end

    def install_search_history_controller
      target_file = 'app/controllers/search_history_controller.rb'
      if File.exist?(target_file)
        inject_into_file target_file,
                         after: /include Blacklight::SearchHistory/ do
          "\n  helper BlacklightMaps::RenderConstraintsOverride\n"
        end
      else
        copy_file 'search_history_controller.rb', target_file
      end
    end

    # TODO: inject Solr configuration (if needed)
    def inject_solr_configuration
      target_file = 'solr/conf/schema.xml'
      return unless File.exist?(target_file)

      inject_into_file target_file,
                       after: %r{<copyField source="title_tsim" dest="title_spell"/>} do
        "\n  <copyField source=\"coordinates_srpt\" dest=\"coordinates_ssim\" />\n"
      end
    end

    private

    def using_importmaps?
      defined?(Importmap) && File.exist?('config/importmap.rb')
    end

    def using_jsbundling?
      File.exist?('package.json')
    end

    def yarn_add_blacklight_maps
      if ENV['CI'] || test_app?
        run "yarn add file:#{Blacklight::Maps::Engine.root}"
      else
        run "yarn add blacklight-maps@#{BlacklightMaps::VERSION}"
      end
    end

    def test_app?
      Rails.application.class.name == 'Internal::Application' # rubocop:disable Style/ClassEqualityComparison
    end

    def leaflet_cdn_imports
      <<~SCSS
        @import url("https://cdn.jsdelivr.net/npm/leaflet@#{LEAFLET_VERSION}/dist/leaflet.css");
        @import url("https://cdn.jsdelivr.net/npm/leaflet.markercluster@#{MARKERCLUSTER_VERSION}/dist/MarkerCluster.css");
        @import url("https://cdn.jsdelivr.net/npm/leaflet.markercluster@#{MARKERCLUSTER_VERSION}/dist/MarkerCluster.Default.css");
      SCSS
    end
  end
end
