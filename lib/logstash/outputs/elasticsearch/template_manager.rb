module LogStash; module Outputs; class ElasticSearch
  class TemplateManager
    LEGACY_TEMPLATE_ENDPOINT = '_template'.freeze
    INDEX_TEMPLATE_ENDPOINT = '_index_template'.freeze

    # To be mixed into the elasticsearch plugin base
    def self.install_template(plugin)
      return unless plugin.manage_template

      if plugin.template
        if plugin.maximum_seen_major_version < 8 && plugin.template_api == 'auto'
          plugin.logger.warn("`template_api => auto` resolved to `legacy` since we are connected to " + "Elasticsearch #{plugin.maximum_seen_major_version}, " +
                               "but will resolve to `composable` the first time it connects to Elasticsearch 8+. " +
                               "We recommend either setting `template_api => legacy` to continue providing legacy-style templates, " +
                               "or migrating your template to the composable style and setting `template_api => composable`. " +
                               "The legacy template API is slated for removal in Elasticsearch 9.")
        end

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
      fail "Failed to load default template for Elasticsearch v#{es_major_version} with ECS #{ecs_compatibility}; caused by: #{e.inspect}"
    end

    def self.install(client, template_endpoint, template_name, template, template_overwrite)
      client.template_install(template_endpoint, template_name, template, template_overwrite)
    end

    def self.add_ilm_settings_to_template(plugin, template)
      # Overwrite any index patterns, and use the rollover alias. Use 'index_patterns' rather than 'template' for pattern
      # definition - remove any existing definition of 'template'
      template.delete('template') if template_endpoint(plugin) == LEGACY_TEMPLATE_ENDPOINT
      template['index_patterns'] = "#{plugin.ilm_rollover_alias}-*"
      settings = template_settings(plugin, template)
      if settings && (settings['index.lifecycle.name'] || settings['index.lifecycle.rollover_alias'])
        plugin.logger.info("Overwriting index lifecycle name and rollover alias as ILM is enabled")
      end
      settings.update({ 'index.lifecycle.name' => plugin.ilm_policy, 'index.lifecycle.rollover_alias' => plugin.ilm_rollover_alias})
    end

    def self.template_settings(plugin, template)
      if template_endpoint(plugin) == LEGACY_TEMPLATE_ENDPOINT
        return template['settings'] ||= {}
      end

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
      raise ArgumentError, "Template file '#{template_path}' could not be found" unless ::File.exists?(template_path)
      template_data = ::IO.read(template_path)
      LogStash::Json.load(template_data)
    end

    def self.template_endpoint(plugin)
      case plugin.template_api.to_s
      when 'composable' then INDEX_TEMPLATE_ENDPOINT
      when 'legacy'     then LEGACY_TEMPLATE_ENDPOINT
      else
        plugin.maximum_seen_major_version < 8 ? LEGACY_TEMPLATE_ENDPOINT : INDEX_TEMPLATE_ENDPOINT
      end
    end

  end
end end end
