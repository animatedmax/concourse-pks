module PubTools
  class Scheme
    def initialize(pipeline, group, name, config, opts = {})
      @pipeline, @group, @name, @config = pipeline, group, name, config
      @use_bookbinder_edge = !!opts[:bookbinder_edge]
      @s3_resource = "#{pipeline}-#{name}-s3"
    end

    def bind_resources
      resources = [
        { 'name' => 'bookbinder-release-complete',
          'type' => 's3',
          'source' => {
            'bucket' => 'concourse-interim-steps',
            'versioned_file' => 'bookbinder-release-complete.tar.gz',
            'private' => true,
            'access_key_id' => "{{aws-access-key}}",
            'secret_access_key' => "{{aws-secret-key}}" }},
      ]
          if @use_bookbinder_edge
            resources = [{ 'name' => 'bookbinder-edge-release-complete',
                               'type' => 's3',
                               'source' => {
                                 'bucket' => 'concourse-interim-steps',
                                 'versioned_file' => 'bookbinder-edge-release-complete.tar.gz',
                                 'private' => true,
                                 'access_key_id' => "{{aws-access-key}}",
                                 'secret_access_key' => "{{aws-secret-key}}" }}]
          end

          resources.concat config.all_repos.map { |repo|
        { 'name' => repo.full_name,
          'type' => 'git',
          'source' => { 'uri' => "git@github.com:#{repo.org}/#{repo.name}.git",
                        'branch' => repo.branch,
                        'private_key' => "{{github-deploy-bot}}" }}
      }
    end

    def bind_plan
      aggregate = config.all_repos.map { |repo|
        { 'get' => repo.friendly_name, 'resource' => repo.full_name, 'trigger' => repo.trigger, 'params' => { 'submodules' => 'none' } }
      }
      aggregate << { 'get' => 'bookbinder-release',
                     'resource' => @use_bookbinder_edge ? 'bookbinder-edge-release-complete' : 'bookbinder-release-complete',
                     'trigger' => true }
      if "#{pipeline}" == 'data-docs'
      [
        { 'aggregate' => aggregate },
        { 'task' => "#{name}-bind", 'file' => "concourse-scripts/#{pipeline}/#{group}/#{name}-bind/task.yml", 'on_failure' => {
          'put' => 'notify-data',
          'params' =>
              {'text' => 'The `$BUILD_PIPELINE_NAME` pipeline is broken. `$BUILD_JOB_NAME` job failed on build `$BUILD_NAME`: https://concourse.run.pivotal.io/teams/$BUILD_TEAM_NAME/pipelines/$BUILD_PIPELINE_NAME/jobs/$BUILD_JOB_NAME/builds/$BUILD_NAME'}
        } },
        { 'aggregate' =>
          [
            { 'put' => s3_resource, 'params' => { 'file' => 'bind_output/final_app.tar.gz'} },
          ]
        }
      ]
    else
      [
        { 'aggregate' => aggregate },
        { 'task' => "#{name}-bind", 'file' => "concourse-scripts/#{pipeline}/#{group}/#{name}-bind/task.yml", 'on_failure' => {
          'put' => 'notify',
          'params' =>
              {'text' => 'The `$BUILD_PIPELINE_NAME` pipeline is broken. `$BUILD_JOB_NAME` job failed on build `$BUILD_NAME`: https://concourse.run.pivotal.io/teams/$BUILD_TEAM_NAME/pipelines/$BUILD_PIPELINE_NAME/jobs/$BUILD_JOB_NAME/builds/$BUILD_NAME'}
        } },
        { 'aggregate' =>
          [
            { 'put' => s3_resource, 'params' => { 'file' => 'bind_output/final_app.tar.gz'} },
          ]
        }
      ]
    end
    end

    def bind_task
      { 'platform' => 'linux',
        'image_resource' => {
            'type' => 'docker-image',
            'source' => {
              'repository' => @use_bookbinder_edge ? 'pubtools/bookbinder-10.1.15' : 'pubtools/bookbinder-8.1'
            }
        },
        'inputs' => inputs,
        'outputs' => [{ 'name' => 'bind_output' }],
        'run' => { 'path' => 'concourse-scripts/bookbinder-bind-local.sh' }
      }
    end

    def deploy_plan(environment, stream_id, dependency, trigger)
      previous_job = "#{name}-#{dependency}"
      environment = environment.gsub('-', '_')
      aggregate = [
            { 'get' => 'concourse-scripts', 'resource' => 'concourse-scripts-docs-master', 'passed' => [previous_job]},
            { 'get' => 'concourse-scripts-bundle' },
            { 'get' => 'site-source', 'resource' => s3_resource, 'passed' => [previous_job], 'trigger' => trigger }
          ]
          deploy_task_file = 'concourse-scripts/deploy_task.yml'
          if @use_bookbinder_edge
            aggregate.push({ 'get' => 'concourse-scripts-bookbinder-edge', 'resource' => 'concourse-scripts-bookbinder-edge'})
            deploy_task_file = 'concourse-scripts-bookbinder-edge/deploy_task.yml'
          end
      [
        {
          'aggregate' => aggregate        },
        if "#{pipeline}" == "data-docs"
        { 'task' => 'deploy', 'file' => deploy_task_file, 'params' => {
          'DEPLOY_DETAILS' => "concourse-scripts/#{pipeline}/#{group}/config.yml",
          'DEPLOY_ENV' => environment,
          'BOOK_ID' => stream_id,
          'USERNAME' => "{{cloud-foundry-username}}",
          'PASSWORD' => "{{cloud-foundry-password}}"
        }, 'on_failure' => {
          'put' => 'notify-data',
          'params' =>
              {
                'text' => 'The `$BUILD_PIPELINE_NAME` pipeline is broken. `$BUILD_JOB_NAME` job failed on build `$BUILD_NAME`: https://concourse.run.pivotal.io/teams/$BUILD_TEAM_NAME/pipelines/$BUILD_PIPELINE_NAME/jobs/$BUILD_JOB_NAME/builds/$BUILD_NAME'}
        }
      }
    else
      { 'task' => 'deploy', 'file' => deploy_task_file, 'params' => {
        'DEPLOY_DETAILS' => "concourse-scripts/#{pipeline}/#{group}/config.yml",
        'DEPLOY_ENV' => environment,
        'BOOK_ID' => stream_id,
        'USERNAME' => "{{cloud-foundry-username}}",
        'PASSWORD' => "{{cloud-foundry-password}}"
      }, 'on_failure' => {
        'put' => 'notify',
        'params' =>
            {
              'text' => 'The `$BUILD_PIPELINE_NAME` pipeline is broken. `$BUILD_JOB_NAME` job failed on build `$BUILD_NAME`: https://concourse.run.pivotal.io/teams/$BUILD_TEAM_NAME/pipelines/$BUILD_PIPELINE_NAME/jobs/$BUILD_JOB_NAME/builds/$BUILD_NAME'}
      }
    }
  end
      ]
    end

    def deploy_resources
      resources = [
        {
          'name' => 'concourse-scripts-bundle',
          'type' => 's3',
          'source' => {
            'bucket' => 'concourse-interim-steps',
            'versioned_file' => 'concourse-scripts-bundle.tar.gz',
            'private' => true,
            'access_key_id' => '{{aws-access-key}}',
            'secret_access_key' => '{{aws-secret-key}}'
          }
        }
      ]
      if @use_bookbinder_edge
        resources.push({
          'name' => 'concourse-scripts-bookbinder-edge',
          'type' => 'git',
          'source' => {
            'uri' => 'git@github.com:pivotal-cf/concourse-scripts-docs.git',
            'branch' => 'bookbinder-edge',
            'private_key' => "{{github-deploy-bot}}",
          }
        })
      end
      if "#{pipeline}" == "data-docs"
        resources.push({
          'name' => 'notify-data',
          'type' => 'slack-notification-data',
          'source' => {
            'url' => '((data-docs-slack-webhook))'
          }
        })
      else
        resources.push({
          'name' => 'notify',
          'type' => 'slack-notification',
          'source' => {
            'url' => '((slack-webhook))'
          }
        })
      end
      resources
    end

    def deploy_details(deploy)
      {
        'endpoint' => deploy.fetch('endpoint'),
        'organization' => deploy.fetch('organization'),
        'space' => deploy.fetch('space'),
        'routes' => deploy.fetch('routes').map do |route|
          {'hostname' => '', 'path' => ''}.merge(route)
        end
      }
    end

    private

    attr_reader :pipeline, :group, :name, :config, :s3_resource

    def inputs
      names = %w[ bookbinder-release ]
      names.concat(config.all_repos.map(&:friendly_name))
      names.map { |name| { 'name' => name } }
    end
  end
end
