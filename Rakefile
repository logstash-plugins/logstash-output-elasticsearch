require "logstash/devutils/rake"

task :'vendor-ecs-schemata' do
  # WARNING: v1.11 breaks 6.x (see: https://github.com/elastic/ecs/issues/1649)
  download_ecs_schemata(:v1, elasticsearch_major: 6, ecs_release_tag: 'v1.10.0')
  download_ecs_schemata(:v1, elasticsearch_major: 7, ecs_release_tag: 'v1.10.0')
  download_ecs_schemata(:v1, elasticsearch_major: 8, ecs_release_tag: 'v1.10.0', generated_for: 7)

  # PRERELEASE: 8.0 branch
  # when pinning to released tag, remove BETA warning.
  download_ecs_schemata(:v8, elasticsearch_major: 7, ecs_release_tag: '8.0')
  download_ecs_schemata(:v8, elasticsearch_major: 8, ecs_release_tag: '8.0')
end

task :vendor => :'vendor-ecs-schemata'


ECS_LOGSTASH_INDEX_PATTERNS = %w(
  ecs-logstash-*
).freeze

def download_ecs_schemata(ecs_major, elasticsearch_major:, ecs_release_tag:, generated_for: elasticsearch_major)
  # when talking with ES >= 8, this plugin uses the v2 _index_template API and needs
  # the generated monolith legacy index template to be transformed into a v2 index template
  transform = Proc.new { |template| transform_legacy_template_to_v2!(template) if elasticsearch_major >= 8 }

  return download_ecs_v1(elasticsearch_major: elasticsearch_major, ecs_release_tag: ecs_release_tag, generated_for: generated_for, &transform) if ecs_major == :v1

  fail(ArgumentError, "Stack-aligned #{ecs_major} does not support `generated_for`") if generated_for != elasticsearch_major

  download_ecs_aligned(ecs_major, elasticsearch_major: elasticsearch_major, ecs_release_tag: ecs_release_tag, &transform)
end

def download_ecs_v1(elasticsearch_major:, ecs_release_tag:, generated_for: elasticsearch_major, &transform)
  $stderr.puts("Vendoring v1 ECS template (#{ecs_release_tag}) for Elasticsearch #{elasticsearch_major}"+(elasticsearch_major==generated_for ? '': " (transformed from templates pre-generated for ES #{generated_for})"))

  source_url = "/elastic/ecs/#{ecs_release_tag}/generated/elasticsearch/#{generated_for}/template.json"
  download_and_transform(source_url: source_url, ecs_major: :v1, es_major: elasticsearch_major, &transform)
end

def download_ecs_aligned(ecs_major, elasticsearch_major:, ecs_release_tag:, &transform)
  $stderr.puts("Vendoring Stack-aligned ECS template (#{ecs_release_tag}) for Elasticsearch #{elasticsearch_major}")

  source_url = "/elastic/ecs/#{ecs_release_tag}/generated/elasticsearch/legacy/template.json"
  download_and_transform(source_url: source_url, ecs_major: ecs_major, es_major: elasticsearch_major, &transform)
end

def download_and_transform(source_url:, ecs_major:, es_major:)
  require 'net/http'
  require 'json'
  Net::HTTP.start('raw.githubusercontent.com', :use_ssl => true) do |http|
    response = http.get(source_url)
    fail "#{response.code} #{response.message}" unless (200...300).cover?(response.code.to_i)
    template_directory = File.expand_path("../lib/logstash/outputs/elasticsearch/templates/ecs-#{ecs_major}", __FILE__)
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

# destructively transforms an ES7-style legacy template into an ES8-compatible index_template.
def transform_legacy_template_to_v2!(template)
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
