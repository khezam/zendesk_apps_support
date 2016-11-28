# frozen_string_literal: true
module ZendeskAppsSupport
  class Manifest
    LEGACY_URI_STUB = '_legacy'

    RUBY_TO_JSON = {
      requirements_only: 'requirementsOnly',
      marketing_only: 'marketingOnly',
      version: 'version',
      author: 'author',
      name: 'name', # currently only used in ZAT
      experiments: 'experiments',
      framework_version: 'frameworkVersion',
      single_install: 'singleInstall',
      signed_urls: 'signedUrls',
      no_template: 'noTemplate',
      default_locale: 'defaultLocale',
      original_locations: 'location',
      private: 'private',
      oauth: 'oauth',
      original_parameters: 'parameters',
      domain_whitelist: 'domainWhitelist',
      remote_installation_url: 'remoteInstallationURL',
      terms_conditions_url: 'termsConditionsURL',
      google_analytics_code: 'gaID'
    }.freeze

    attr_reader(*RUBY_TO_JSON.keys)
    attr_reader :locations

    alias_method :requirements_only?, :requirements_only
    alias_method :marketing_only?, :marketing_only
    alias_method :signed_urls?, :signed_urls
    alias_method :single_install?, :single_install
    alias_method :private?, :private

    def no_template?
      if no_template.is_a?(Array)
        false
      else
        no_template
      end
    end

    def no_template_locations
      no_template || []
    end

    def location?
      !locations.values.all?(&:empty?)
    end

    def location_options
      @location_options ||= locations.flat_map do |product_key, locations|
        product = Product.find_by!(name: product_key)
        locations.map do |location_key, location_options|
          location = Location.find_by!(product_code: product.code, name: location_key)
          Manifest::LocationOptions.new(location, location_options)
        end
      end
    end

    def unknown_hosts
      @unknown_hosts ||=
        @used_hosts - Product::PRODUCTS_AVAILABLE.flat_map { |p| [p.name, p.legacy_name] }
    end

    def iframe_only?
      Gem::Version.new(framework_version) >= Gem::Version.new('2')
    end

    def parameters
      @parameters ||= begin
        parameter_array = @original_parameters.is_a?(Array) ? @original_parameters : []
        parameter_array.map do |parameter_hash|
          Parameter.new(parameter_hash)
        end
      end
    end

    def enabled_experiments
      (experiments || {}).select { |_k, v| v }.keys
    end

    def initialize(manifest_text)
      m = parse_json(manifest_text)
      RUBY_TO_JSON.each do |ruby, json|
        instance_variable_set(:"@#{ruby}", m[json])
      end
      @requirements_only ||= false
      @marketing_only ||= false
      @single_install ||= false
      @private = m.fetch('private', true)
      @signed_urls ||= false
      @no_template ||= false
      @experiments ||= {}
      set_locations_and_hosts
    end

    private

    LEGACY_LOCATION_OBJECT = { 'url' => LEGACY_URI_STUB }.freeze

    def set_locations_and_hosts
      @locations =
        case original_locations
        when Hash
          @used_hosts = original_locations.keys
          replace_legacy_locations original_locations
        when Array
          @used_hosts = ['support']
          new_locations = NoOverrideHash[original_locations.map { |location| [ location, LEGACY_LOCATION_OBJECT ] }]
          { 'support' => new_locations }
        when String
          @used_hosts = ['support']
          { 'support' => { original_locations => LEGACY_LOCATION_OBJECT } }
        # TODO: error out for numbers and Booleans
        else # NilClass
          @used_hosts = ['support']
          { 'support' => {} }
        end
    end

    def replace_legacy_locations(original_locations)
      NoOverrideHash.new.tap do |new_locations_obj|
        Product::PRODUCTS_AVAILABLE.each do |product|
          product_key = product.name.to_s
          legacy_key = product.legacy_name.to_s
          value_for_product = original_locations.fetch(product_key, original_locations[legacy_key])
          value_for_product && new_locations_obj[product_key] = replace_string_uris(value_for_product)
        end
      end
    end

    def replace_string_uris(product_locations)
      product_locations.each_with_object({}) do |(k, v), new_locations|
        if v.is_a? Hash
          new_locations[k] = v
        else
          new_locations[k] = { 'url' => v }
        end
      end
    end

    def parse_json(manifest_text)
      parser_opts = { object_class: Manifest::NoOverrideHash }
      JSON.parse(manifest_text, parser_opts)
    end
  end
end
