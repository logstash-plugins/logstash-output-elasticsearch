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
      plugin.logger.info("Attempting to install template", :manage_template => template)
      install(plugin.client, template_name(plugin), template, plugin.template_overwrite)
    rescue => e
      plugin.logger.error("Failed to install template.", :message => e.message, :class => e.class.name, :backtrace => e.backtrace)
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
      if plugin.original_params.key?('ilm_rollover_alias')
        # If no index patterns in the 'index_pattern' array would include the 'ilm_rollover_alias' add the 'ilm_rollover_alias' to the 'index_pattern' array
	if template.key?('index_patterns') && template['index_patterns'].kind_of?(Array) && !template['index_patterns'].any? { |idx_pattern| "#{plugin.ilm_rollover_alias}-".include?(idx_pattern.tr('*','')) }
          plugin.logger.info("Adding index pattern name for rollover alias as ILM is enabled.")
  	  template['index_patterns'].append("#{plugin.ilm_rollover_alias}-*")
        # If 'index_pattern' is not an array and doesn't include the 'ilm_rollover_alias' set the 'index_pattern' to the 'ilm_rollover_alias'
  	elsif template.key?('index_patterns') && !template['index_patterns'].kind_of?(Array) && !"#{plugin.ilm_rollover_alias}-".include?(template['index_patterns'].tr('*',''))
          plugin.logger.info("Overwriting index pattern name for rollover alias as ILM is enabled.")
 	  template['index_patterns'] = "#{plugin.ilm_rollover_alias}-*"
        # If 'index_pattern' doesn't exist, set it to the 'ilm_rollover_alias'
	elsif !template.key('index_patterns')
          plugin.logger.info("Setting index pattern name for rollover alias as ILM is enabled.")
	  template['index_patterns'] = "#{plugin.ilm_rollover_alias}-*"
	end
      end
      if plugin.legacy_template
        # definition - remove any existing definition of 'template'
        template.delete('template') if template.include?('template')
        # Create settings hash if not in the template, but ilm is enabled
        if !template.key?('settings')
          template['settings'] = { }
        end
        if plugin.original_params.key?('ilm_rollover_alias')
          if template['settings']
	    # Overwrite the rollover_alias, sense it was defined in the output plugin
            plugin.logger.info("Overwriting index rollover alias with plugin defined alias.")
            template['settings'].update({ 'index.lifecycle.rollover_alias' => plugin.ilm_rollover_alias})
          end
        end
        if plugin.original_params.key?('ilm_policy')
          if template['settings'] 
	    # Overwrite the ilm_policy, sense it was defined in the output plugin
            plugin.logger.info("Overwriting index lifecycle name with plugin defined ilm policy.")
            template['settings'].update({ 'index.lifecycle.name' => plugin.ilm_policy})
	  end
        end
      else
        #plugin.logger.warn(plugin.original_params.key?('ilm_rollover_alias'))
        # Create settings hash if not in the template, but ilm is enabled
        if !template['template'].key?('settings')
          template['template']['settings'] = { }
        end
        if plugin.original_params.key?('ilm_rollover_alias')
          if template['template']['settings']
	    # Overwrite the rollover_alias, sense it was defined in the output plugin
            plugin.logger.info("Overwriting index rollover alias with plugin defined alias.")
            template['template']['settings'].update({ 'index.lifecycle.rollover_alias' => plugin.ilm_rollover_alias})
          end
        end
        if plugin.original_params.key?('ilm_policy')
          if template['template']['settings'] 
	    # Overwrite the ilm_policy, sense it was defined in the output plugin
            plugin.logger.info("Overwriting index lifecycle name with plugin defined ilm policy.")
            template['template']['settings'].update({ 'index.lifecycle.name' => plugin.ilm_policy})
	  end
        end
      end
    end

    # Template name - if template_name set, use it
    #                 if not and ILM is enabled, use the rollover alias
    #                 else use the default value of template_name
    def self.template_name(plugin)
      plugin.ilm_in_use? && !plugin.original_params.key?('template_name') ? plugin.ilm_rollover_alias : plugin.template_name
    end

    def self.default_template_path(es_major_version, ecs_compatibility=:disabled)
      template_version = es_major_version == 1 ? 2 : es_major_version
      default_template_name = "templates/ecs-#{ecs_compatibility}/elasticsearch-#{template_version}x.json"
      ::File.expand_path(default_template_name, ::File.dirname(__FILE__))
    end

    def self.read_template_file(template_path)
      raise ArgumentError, "Template file '#{template_path}' could not be found!" unless ::File.exists?(template_path)
      template_data = ::IO.read(template_path)
      LogStash::Json.load(template_data)
    end
  end
end end end
