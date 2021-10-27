require "logstash/devutils/rake"

ECS_VERSIONS = {
    v1: 'v1.12.1'
}

ECS_LOGSTASH_INDEX_PATTERNS = %w(
  ecs-logstash-*
)

task :'vendor-ecs-schemata' do
  download_ecs_schema(:v1, 6)
  download_ecs_schema(:v1, 7)
end
task :vendor => :'vendor-ecs-schemata'

def download_ecs_schema(ecs_major_version, es_major)
  $stderr.puts("Vendoring ECS #{ecs_major_version} template for Elasticsearch #{es_major}")
  require 'net/http'
  require 'json'
  Net::HTTP.start('raw.githubusercontent.com', :use_ssl => true) do |http|
    ecs_release_tag = ECS_VERSIONS.fetch(ecs_major_version)
    response = http.get("/elastic/ecs/#{ecs_release_tag}/generated/elasticsearch/#{es_major}/template.json")
    fail "#{response.code} #{response.message}" unless (200...300).cover?(response.code.to_i)
    template_directory = File.expand_path("../lib/logstash/outputs/elasticsearch/templates/ecs-#{ecs_major_version}", __FILE__)
    Dir.mkdir(template_directory) unless File.exists?(template_directory)
    File.open(File.join(template_directory, "/elasticsearch-#{es_major}x.json"), "w") do |handle|
      handle.write(replace_index_patterns(response.body, ECS_LOGSTASH_INDEX_PATTERNS))
    end
  end
end

def replace_index_patterns(template_json, replacement_index_patterns)
  template_obj = JSON.load(template_json)
  template_obj.update('index_patterns' => replacement_index_patterns)
  JSON.pretty_generate(template_obj)
end
