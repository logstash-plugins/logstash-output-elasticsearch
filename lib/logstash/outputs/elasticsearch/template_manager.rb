module LogStash; module Outputs; class ElasticSearch
  class TemplateManager
    # To be mixed into the elasticsearch plugin base
    def self.install_template(plugin)
      return unless plugin.manage_template
      plugin.logger.info("Using mapping template from", :path => plugin.template)
      template = get_template(plugin.template)
      plugin.logger.info("Attempting to install template", :manage_template => template)
      install(plugin.client, plugin.template_name, template, plugin.template_overwrite)
    rescue => e
      plugin.logger.error("Failed to install template.", :message => e.message, :class => e.class.name)
    end

    private

    def self.get_template(path)
      template_path = path || default_template_path
      read_template_file(template_path)
    end

    def self.install(client, template_name, template, template_overwrite)
      client.template_install(template_name, template, template_overwrite)
    end

    def self.default_template_path
      ::File.expand_path('elasticsearch-template.json', ::File.dirname(__FILE__))
    end

    def self.read_template_file(template_path)
      raise ArgumentError, "Template file '#{@template_path}' could not be found!" unless ::File.exists?(template_path)
      template_data = ::IO.read(template_path)
      LogStash::Json.load(template_data)
    end
  end
end end end