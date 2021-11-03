require "logstash/devutils/rake"

ECS_VERSIONS = {
    v1: 'v1.10.0', # WARNING: v1.11 breaks 6.x (see: https://github.com/elastic/ecs/issues/1649)

    # PRERELEASE: 8.0@{2021-11-02T20:09:42Z}
    # when pinning to released tag, remove BETA warning.
    v8: 'b3dace43afb0dce743605cdd4cc067a3a6b8131c',
}

ECS_LOGSTASH_INDEX_PATTERNS = %w(
  ecs-logstash-*
)

task :'vendor-ecs-schemata' do
  download_ecs_schema(:v1, 6)
  download_ecs_schema(:v1, 7)
  download_ecs_schema(:v1, 8, 7) { |template| transform_for_es8!(template) }

  download_ecs_schema(:v8, 7)
  download_ecs_schema(:v8, 8, 7) { |template| transform_for_es8!(template) }
end
task :vendor => :'vendor-ecs-schemata'

def download_ecs_schema(ecs_major_version, es_major, generated_for_es_major=es_major)
  $stderr.puts("Vendoring ECS #{ecs_major_version} template for Elasticsearch #{es_major}"+(es_major==generated_for_es_major ? '': " (transformed from templates pre-generated for ES #{generated_for_es_major})"))
  require 'net/http'
  require 'json'
  Net::HTTP.start('raw.githubusercontent.com', :use_ssl => true) do |http|
    ecs_release_tag = ECS_VERSIONS.fetch(ecs_major_version)
    response = http.get("/elastic/ecs/#{ecs_release_tag}/generated/elasticsearch/#{generated_for_es_major}/template.json")
    fail "#{response.code} #{response.message}" unless (200...300).cover?(response.code.to_i)
    template_directory = File.expand_path("../lib/logstash/outputs/elasticsearch/templates/ecs-#{ecs_major_version}", __FILE__)
    Dir.mkdir(template_directory) unless File.exists?(template_directory)
    File.open(File.join(template_directory, "/elasticsearch-#{es_major}x.json"), "w") do |handle|
      template = JSON.load(response.body)
      replace_index_patterns!(template, ECS_LOGSTASH_INDEX_PATTERNS)
      yield(template) if block_given?
      handle.write(JSON.pretty_generate template)
    end
  end
end

# destructively replaces the index pattern with the provided replacements
def replace_index_patterns!(template, replacement_index_patterns)
  template.update('index_patterns' => replacement_index_patterns)
end

# destructively transforms a legacy template into an ES8-compatible index_template.
def transform_for_es8!(template)
  # `settings` and `mappings` are now nested under top-level `template`
  template["template"] = {
    "settings" => template.delete("settings"),
    "mappings" => template.delete("mappings"),
  }

  # `order` is gone, replaced with `priority`.
  template.delete('order')
  template["priority"] = 200 #arbitrary

  # a new free-form `_meta` exists, so let's add a note about where the template came from
  template["_meta"] = { "description" => "ECS index template for logstash-output-elasticsearch" }

  nil
end
