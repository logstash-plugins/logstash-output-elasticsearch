module LogStash; module Outputs; class ElasticSearch
  class TemplateManager
    # To be mixed into the elasticsearch plugin base
    def self.install_template(plugin)
      return unless plugin.manage_template
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
      install(plugin.client, template_name(plugin), template, plugin.template_overwrite)
    end

    private
    def self.load_default_template(es_major_version, ecs_compatibility)
      template_path = default_template_path(es_major_version, ecs_compatibility)
      read_template_file(template_path)
    rescue => e
      fail "Failed to load default template for Elasticsearch v#{es_major_version} with ECS #{ecs_compatibility}; caused by: #{e.inspect}"
    end

    def self.install(client, template_name, template, template_overwrite)
      client.template_install(template_name, template, template_overwrite)
    end

    def self.add_ilm_settings_to_template(plugin, template)
      # Overwrite any index patterns, and use the rollover alias. Use 'index_patterns' rather than 'template' for pattern
      # definition - remove any existing definition of 'template'
      template.delete('template') if template.include?('template') if plugin.maximum_seen_major_version < 8
      template['index_patterns'] = "#{plugin.ilm_rollover_alias}-*"
      settings = template_settings(plugin, template)
      if settings && (settings['index.lifecycle.name'] || settings['index.lifecycle.rollover_alias'])
        plugin.logger.info("Overwriting index lifecycle name and rollover alias as ILM is enabled")
      end
      settings.update({ 'index.lifecycle.name' => plugin.ilm_policy, 'index.lifecycle.rollover_alias' => plugin.ilm_rollover_alias})
    end

    def self.template_settings(plugin, template)
      plugin.maximum_seen_major_version < 8 ? template['settings']: template['template']['settings']
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
  end
end end end
