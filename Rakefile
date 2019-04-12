$LOAD_PATH.unshift(File.expand_path('../lib', __FILE__))

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
  task default: :spec
rescue LoadError
end

ENDPOINT_NAME = 'pws'
CONCOURSE_KEYS = File.expand_path('~/workspace/docs-concourse-creds/concourse_keys')

desc 'Set up dependencies'
task newb: ['bin/fly']

def write_yaml(file_path, object)
  File.write(file_path, "# Generated file...\n" + YAML.dump(object))
end

def update_scheme(path)
  require 'yaml'
  require 'pub_tools'
  require_relative 'lib/pub_tools/git_resource'

  pipeline, group = path.split('/')[-2..-1]
  scheme_configs = YAML.load_file(File.join(path, 'config.yml'))

  scheme_configs.each do |scheme_config|
    book_repo = PubTools::GitResource.from_id(scheme_config.fetch('book'), branch: scheme_config.fetch('book_branch', 'master'), friendly_name: 'book')

    validate_book(book_repo)

    config = PubTools::Config.new(book_repo, YAML.load_file(File.expand_path("../../#{book_repo.name}/config.yml", __FILE__)))
    book_branch = `cd ../#{book_repo.name} && echo \`git rev-parse --abbrev-ref HEAD\``.chomp

    abort "Config specifies #{config.book_repo.branch.inspect}, but you have #{book_branch.inspect} checked out locally" unless book_branch == config.book_repo.branch
    stream_id = scheme_config.fetch('id', group)

    #if we're just doing a "regular" update, check to make sure it's not blowing away a pipeline configured for bookbinder edge
    if !(ENV["BOOKBINDER_EDGE"] || ENV["REMOVE_BOOKBINDER_EDGE"])
      sources_file = File.join(path, "#{stream_id}-bind", 'sources.yml')
      using_bookbinder_edge = File.exist?(sources_file) && File.read(sources_file).include?("bookbinder-edge-release-complete")
      if using_bookbinder_edge
        abort "\n\n  ---- WHOA THERE ----\n\n" + 
          "  It looks like you're trying to change a pipeline that is configured to use a bookbinder edge build.\n\n" +
          "  If it should still use bookbinder edge but include your recent changes, set a BOOKBINDER_EDGE environment variable and re-run the task.\n" +
          "  e.g. BOOKBINDER_EDGE=true bundle exec rake the_task_you_just:ran\n\n\n" +
          "  If you are trying to change this book back to using the mainline bookbinder release, then set an environment variable called REMOVE_BOOKBINDER_EDGE and re-run the task\n" +
          "  This should remove all references to bookbinder edge.\n" + 
          "  e.g. REMOVE_BOOKBINDER_EDGE=true bundle exec rake the_task_you_just:ran\n\n\n" +
          "  If you are still having trouble or this message makes no sense to you, please check #cf-pubtools on Slack, and/or try tagging @ragaskar"
        end
    end

    scheme = PubTools::Scheme.new(pipeline, group, stream_id, config, {bookbinder_edge: ENV["BOOKBINDER_EDGE"]})
    FileUtils.mkdir_p(File.join(path, "#{stream_id}-bind"))
    write_yaml(File.join(path, "#{stream_id}-bind", 'sources.yml'), scheme.bind_resources)
    write_yaml(File.join(path, "#{stream_id}-bind", 'plan.yml'), scheme.bind_plan)
    write_yaml(File.join(path, "#{stream_id}-bind", 'task.yml'), scheme.bind_task)
    scheme_id = scheme_config.fetch('id', scheme_config.fetch('book'))

    scheme_config.fetch('deployments', []).each do |deploy|
      FileUtils.mkdir_p(File.join(path, "#{stream_id}-#{deploy['name']}"))
      write_yaml(File.join(path, "#{stream_id}-#{deploy['name']}", 'plan.yml'), scheme.deploy_plan(deploy.fetch('name'), scheme_id, deploy['depends_on'], deploy['trigger']))
      write_yaml(File.join(path, "#{stream_id}-#{deploy['name']}", 'sources.yml'), scheme.deploy_resources)
    end
  end

  pipeline
end

def validate_book(book_repo)

  cd "../#{book_repo.name}" do
    status = `git status --porcelain`.chomp
    message = <<-ABORT
The #{book_repo.name} has uncommited changes and/or untracked files:
#{status}
    ABORT
    abort message unless status.empty?

    sh "git checkout #{book_repo.branch}"
    sh 'git pull --ff-only'
    local = `git log --format=oneline -1 #{book_repo.branch}`.chomp
    remote = `git log --format=oneline -1 origin/#{book_repo.branch}`.chomp
    message = <<-ABORT
#{book_repo.name} #{book_repo.branch} not synced with origin:
  Local:  #{local}
  Remote: #{remote}
    ABORT
    abort message unless local == remote
  end
end

namespace :scheme do
  desc 'Update scheme from a book config file'
  task :update, [ :path ] do |t, args|
    path = args.path
    abort 'Path to pipeline/group/scheme is required' if path.nil?

    pipeline = update_scheme(path)

    Rake::Task['pipeline:update'].invoke(pipeline)
  end

  desc 'Update all schemes for a pipeline'
  task :update_all, [ :pipeline ] do |t, args|
    pipeline = args.pipeline
    abort 'Pipeline name required' if pipeline.nil?

    pipeline_path = File.expand_path("../#{pipeline}", __FILE__)
    Dir.entries(pipeline_path).each do |pipeline_group|
      next if pipeline_group =~ /\A\.\.?\z/

      group_path = File.join(pipeline_path, pipeline_group)
      next unless File.directory?(group_path)

      if File.file?(File.join(group_path, 'config.yml'))
        puts "Updating #{pipeline_group}..."
        update_scheme(group_path)
      else
        puts "Skipping #{pipeline_group}..."
      end
    end

    Rake::Task['pipeline:update'].invoke(pipeline)
  end
end

namespace :pipeline do
  desc 'Update pipeline from schemes'
  task :update, [ :pipeline_name ] do |t, args|
    pipeline_name = args.pipeline_name
    abort 'Pipeline name required' if pipeline_name.nil?

    require 'yaml'
    require 'pub_tools'

    group_folders = FileList.new(File.join(pipeline_name, '*'))
    group_folders.exclude(File.join(pipeline_name, '*.yml'))
    group_folders.exclude(File.join(pipeline_name, '*.sh'))
    group_folders.exclude(File.join(pipeline_name, '*.rb'))

    groups = group_folders.to_a.map do |group_name|
      jobs = FileList.new(File.join(group_name, '*'))
      jobs.exclude(File.join(group_name, '*.yml'))
      jobs.exclude(File.join(group_name, '*.sh'))

      {
        'name' => group_name.split('/').last,
        'jobs' => jobs.to_a.map { |job_path| job_path.split('/').last }
      }
    end

    schemes = groups.each_with_object({}) do |group, all_schemes|
      group['jobs'].each.with_object(all_schemes) { |job_name, schemes|
        schemes[job_name] = {
          'sources' => YAML.load_file(File.join(pipeline_name, group['name'], job_name, 'sources.yml')),
          'plan' => YAML.load_file(File.join(pipeline_name, group['name'], job_name, 'plan.yml')),
        }
      }
    end

    deployment_resources = YAML.load_file(File.join(pipeline_name, 'deployment-resources.yml'))
    pipeline = PubTools::Pipeline.new(schemes, deployment_resources, groups)

    # Concourse takes invalid YAML. 😡
    yaml = YAML.dump(pipeline.to_h).gsub(/(['"])({{[^}]+}})\1/, '\\2')
    if pipeline_name == 'data-docs'
      File.write(File.join(pipeline_name, 'pipeline.yml'), "# Generated file...\n" + yaml + "resource_types:
  - name: slack-notification-data
    type: docker-image
    source:
      repository: cfcommunity/slack-notification-resource")
    else 
      File.write(File.join(pipeline_name, 'pipeline.yml'), "# Generated file...\n" + yaml + "resource_types:
  - name: slack-notification
    type: docker-image
    source:
      repository: cfcommunity/slack-notification-resource")
    end  
  end
end

namespace :fly do
  desc 'Login to Concourse'
  task login: 'bin/fly' do
    sh "bin/fly --target #{ENDPOINT_NAME} login --concourse-url https://concourse.run.pivotal.io -n cf-docs"
  end

  desc 'Set pipeline'
  task :set_pipeline, [ :pipeline ] => %w[ bin/fly ~/workspace/docs-concourse-creds/credentials.yml ] do |t, args|
    pipeline_name = args.pipeline
    abort 'Pipeline name required' if pipeline_name.nil?

    pipeline_path = File.join(pipeline_name, 'pipeline.yml')

    abort "#{pipeline_path} not found" unless File.exist?(pipeline_path)

    args = {
      config: pipeline_path,
      pipeline: pipeline_name,
      load_vars_from: '~/workspace/docs-concourse-creds/credentials.yml',
    }
    sh "bin/fly --target #{ENDPOINT_NAME} set-pipeline #{args.map {|k,v| "--#{k.to_s.gsub('_', '-')} #{v}" }.join(' ')}"
  end
end

namespace :docker do
  desc 'Build Docker image'
  task :build, [ :name ] do |t, args|
    abort 'Docker image name required' if args.name.nil?
    name = "pubtools/#{args.name}"

    sh "docker build -t #{name} docker"
  end

  desc 'Push Docker image'
  task :push, [ :name ] do |t, args|
    abort 'Docker image name required' if args.name.nil?
    name = "pubtools/#{args.name}"

    sh "docker push #{name}"
  end
end

namespace :time do
  require 'yaml'
  desc 'Add a periodic trigger to a production job'
  task :add, [ :path ] do |t, args|

    abort 'Path (pipeline/group) required' if args.path.nil?
    abort "No time.yml file found in #{args.path}. See the Docs Wiki for more information about creating a time.yml file." if not File.exist?(File.join(args.path, "time.yml"))

    path = args.path

    pipeline_name = path.split("/").first
    group_name = path.split("/").last

    # Delete time-resource from deployment-resources.yml if it exists
    deployment_resources = YAML.load_file(File.join(pipeline_name, 'deployment-resources.yml'))
    time_resource_1 = deployment_resources.detect { |t| t["name"] == "time-resource-1"}
    time_resource_2 = deployment_resources.detect { |t| t["name"] == "time-resource-2"}
    time_resource_3 = deployment_resources.detect { |t| t["name"] == "time-resource-3"}
    time_resource_4 = deployment_resources.detect { |t| t["name"] == "time-resource-4"}
    time_resource_5 = deployment_resources.detect { |t| t["name"] == "time-resource-5"}
    deployment_resources.delete(time_resource_1)
    deployment_resources.delete(time_resource_2)
    deployment_resources.delete(time_resource_3)
    deployment_resources.delete(time_resource_4)
    deployment_resources.delete(time_resource_5)

    File.open(File.join(pipeline_name, 'deployment-resources.yml'), "w") {
      |f| YAML.dump(deployment_resources, f)
    }

    # Add contents of time.yml to deployment-resources.yml
    time_resource = File.read(File.join(path, 'time.yml'))
    File.open(File.join(pipeline_name, 'deployment-resources.yml'), "a") do |t|
      t.puts "\n" + time_resource
    end

    # Update plan.yml with get time resource if it doesn't already exist
    plan = YAML.load_file(File.join(path, group_name + '-production', 'plan.yml'))
    get_time_resource_1 = {
      "get" => "time-resource-1",
      "trigger" => true
    }
    get_time_resource_2 = {
      "get" => "time-resource-2",
      "trigger" => true
    }
    get_time_resource_3 = {
      "get" => "time-resource-3",
      "trigger" => true
    }
        get_time_resource_4 = {
      "get" => "time-resource-4",
      "trigger" => true
    }
        get_time_resource_5 = {
      "get" => "time-resource-5",
      "trigger" => true
    }

    if not plan[0]['aggregate'].detect { |t| t["get"] == "time-resource-1" && "time-resource-2" && "time-resource-3" && "time-resource-4" && "time-resource-5"}
      plan[0]['aggregate'].push(get_time_resource_1, get_time_resource_2, get_time_resource_3, get_time_resource_4, get_time_resource_5)
      File.open(File.join(path, group_name + '-production', 'plan.yml'), "w") {
        |f| YAML.dump(plan, f)
      }
    end

    Rake::Task['pipeline:update'].invoke(pipeline_name)
    Rake::Task['fly:set_pipeline'].invoke(pipeline_name)
  end

end


file '~/workspace/docs-concourse-creds/credentials.yml' => FileList.new(File.join(CONCOURSE_KEYS, '*')) do |t|
end

file 'bin/fly' => 'bin' do |t|
  sh "curl 'https://concourse.run.pivotal.io/api/v1/cli?arch=amd64&platform=darwin' > #{t.name}"
  chmod 0755, t.name

  Rake::Task['fly:login'].invoke
end

directory 'bin'
