module LogStash; module Outputs; class ElasticSearch
  class TemplateManager
    # To be mixed into the elasticsearch plugin base
    def self.install_template(plugin)
      return unless plugin.manage_template
      plugin.logger.info("Using mapping template from", :path => plugin.template)
      template = get_template(plugin.template, plugin.maximum_seen_major_version)
      add_ilm_settings_to_template(plugin, template) if plugin.ilm_enabled?
      plugin.logger.info("Attempting to install template", :manage_template => template)
      install(plugin.client, template_name(plugin), template, plugin.template_overwrite)
    rescue => e
      puts e.backtrace
      plugin.logger.error("Failed to install template.", :message => e.message, :class => e.class.name, :backtrace => e.backtrace)
    end

    private
    def self.get_template(path, es_major_version)
      template_path = path || default_template_path(es_major_version)
      read_template_file(template_path)
    end

    def self.install(client, template_name, template, template_overwrite)
      client.template_install(template_name, template, template_overwrite)
    end

    def self.add_ilm_settings_to_template(plugin, template)
      # Include ilm settings in template:
      template['template'] = "#{plugin.ilm_write_alias}-*"
      template['settings'].update({ 'index.lifecycle.name' => plugin.ilm_policy, 'index.lifecycle.rollover_alias' => plugin.ilm_write_alias})
    end

    # TODO: Verify this is ok
    def self.template_name(plugin)
      plugin.ilm_enabled? ? plugin.ilm_write_alias : plugin.template_name
    end

    def self.default_template_path(es_major_version)
      template_version = es_major_version == 1 ? 2 : es_major_version
      default_template_name = "elasticsearch-template-es#{template_version}x.json"
      ::File.expand_path(default_template_name, ::File.dirname(__FILE__))
    end

    def self.read_template_file(template_path)
      raise ArgumentError, "Template file '#{@template_path}' could not be found!" unless ::File.exists?(template_path)
      template_data = ::IO.read(template_path)
      LogStash::Json.load(template_data)
    end
  end
end end end
