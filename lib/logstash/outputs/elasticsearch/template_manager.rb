module LogStash; module Outputs; class ElasticSearch
  class TemplateManager
    LEGACY_TEMPLATE_ENDPOINT = '_template'.freeze
    INDEX_TEMPLATE_ENDPOINT = '_index_template'.freeze

    # To be mixed into the elasticsearch plugin base
    def self.install_template(plugin)
      return unless plugin.manage_template

      if plugin.maximum_seen_major_version < 8 && plugin.template_api == 'auto'
        plugin.logger.warn("`template_api => auto` resolved to `legacy` since we are connected to " + "Elasticsearch #{plugin.maximum_seen_major_version}, " +
                           "but will resolve to `composable` the first time it connects to Elasticsearch 8+. " +
                           "We recommend either setting `template_api => legacy` to continue providing legacy-style templates, " +
                           "or migrating your template to the composable style and setting `template_api => composable`. " +
                           "The legacy template API is slated for removal in Elasticsearch 9.")
      elsif plugin.template_api == 'legacy' && plugin.serverless?
        raise LogStash::ConfigurationError, "Invalid template configuration `template_api => legacy`. Serverless Elasticsearch does not support legacy template API."
      end


      if plugin.template
        plugin.logger.info("Using mapping template from", :path => plugin.template)
        template = read_template_file(plugin.template)
      else
        plugin.logger.info("Using a default mapping template", :es_version => plugin.maximum_seen_major_version,
                                                               :ecs_compatibility => plugin.ecs_compatibility)
        template = load_default_template(plugin.maximum_seen_major_version, plugin.ecs_compatibility)
      end

      add_ilm_settings_to_template(plugin, template) if plugin.ilm_in_use?
      plugin.logger.debug("Attempting to install template", template: template)
      install(plugin.client, template_endpoint(plugin), template_name(plugin), template, plugin.template_overwrite)
    end

    private
    def self.load_default_template(es_major_version, ecs_compatibility)
      template_path = default_template_path(es_major_version, ecs_compatibility)
      read_template_file(template_path)
    rescue => e
      raise LogStash::ConfigurationError, "Failed to load default template for Elasticsearch v#{es_major_version} with ECS #{ecs_compatibility}; caused by: #{e.inspect}"
    end

    def self.install(client, template_endpoint, template_name, template, template_overwrite)
      client.template_install(template_endpoint, template_name, template, template_overwrite)
    end

    def self.add_ilm_settings_to_template(plugin, template)
      # Overwrite any index patterns, and use the rollover alias. Use 'index_patterns' rather than 'template' for pattern
      # definition - remove any existing definition of 'template'
      template.delete('template') if template.include?('template') if plugin.maximum_seen_major_version < 8
      template['index_patterns'] = "#{plugin.ilm_rollover_alias}-*"
      settings = resolve_template_settings(plugin, template)
      if settings && (settings['index.lifecycle.name'] || settings['index.lifecycle.rollover_alias'])
        plugin.logger.info("Overwriting index lifecycle name and rollover alias as ILM is enabled")
      end
      settings.update({ 'index.lifecycle.name' => plugin.ilm_policy, 'index.lifecycle.rollover_alias' => plugin.ilm_rollover_alias})
    end

    def self.resolve_template_settings(plugin, template)
      if template.key?('template')
        plugin.logger.trace("Resolving ILM template settings: under 'template' key", :template => template, :template_api => plugin.template_api, :es_version => plugin.maximum_seen_major_version)
        composable_index_template_settings(template)
      elsif template.key?('settings')
        plugin.logger.trace("Resolving ILM template settings: under 'settings' key", :template => template, :template_api => plugin.template_api, :es_version => plugin.maximum_seen_major_version)
        legacy_index_template_settings(template)
      else
        use_index_template_api = index_template_api?(plugin)
        plugin.logger.trace("Resolving ILM template settings: template doesn't have 'settings' or 'template' fields, falling back to auto detection", :template => template, :template_api => plugin.template_api, :es_version => plugin.maximum_seen_major_version, :index_template_api => use_index_template_api)
        if use_index_template_api
          composable_index_template_settings(template)
        else
          legacy_index_template_settings(template)
        end
      end
    end

    # Sets ['settings'] field to be compatible with _template API structure
    def self.legacy_index_template_settings(template)
      template['settings'] ||= {}
    end

    # Sets the ['template']['settings'] fields if not exist to be compatible with _index_template API structure
    def self.composable_index_template_settings(template)
      template['template'] ||= {}
      template['template']['settings'] ||= {}
    end

    # Template name - if template_name set, use it
    #                 if not and ILM is enabled, use the rollover alias
    #                 else use the default value of template_name
    def self.template_name(plugin)
      plugin.ilm_in_use? && !plugin.original_params.key?('template_name') ? plugin.ilm_rollover_alias : plugin.template_name
    end

    def self.default_template_path(es_major_version, ecs_compatibility=:disabled)
      template_version = es_major_version
      default_template_name = "templates/ecs-#{ecs_compatibility}/elasticsearch-#{template_version}x.json"
      ::File.expand_path(default_template_name, ::File.dirname(__FILE__))
    end

    def self.read_template_file(template_path)
      raise LogStash::ConfigurationError, "Template file '#{template_path}' could not be found" unless ::File.exists?(template_path)
      template_data = ::IO.read(template_path)
      LogStash::Json.load(template_data)
    rescue => e
      raise LogStash::ConfigurationError, "Failed to load template file '#{template_path}': #{e.message}"
    end

    def self.template_endpoint(plugin)
      index_template_api?(plugin) ? INDEX_TEMPLATE_ENDPOINT : LEGACY_TEMPLATE_ENDPOINT
    end

    def self.index_template_api?(plugin)
      case plugin.serverless?
      when true
        true
      else
        case plugin.template_api
        when 'auto'
          plugin.maximum_seen_major_version >= 8
        when 'composable'
          true
        when 'legacy'
          false
        else
          plugin.logger.warn("Invalid template_api value #{plugin.template_api}")
          true
        end
      end
    end

  end
end end end
