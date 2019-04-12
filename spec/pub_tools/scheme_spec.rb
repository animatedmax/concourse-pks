require_relative '../spec_helper'

require 'pub_tools/config'
require 'pub_tools/scheme'

#deploy sources are totally untested.

describe Scheme do
  subject(:scheme) { Scheme.new('cf-pre-release',
                                'group',
                                'oss',
                                config,
                                options) }

  let(:config) {
    PubTools::Config.new(GitResource.from_id('cloudfoundry/docs-book-cloudfoundry', branch: 'pre-release', friendly_name: 'book'),
      'cred_repo' => 'pivotal-cf/docs-oss-pre-release-site-credentials',
      'layout_repo' => 'pivotal-cf/docs-layout-repo',
      'layout_repo_ref' => 'pre-release',
      'sections' => [
        { 'repository' => { 'name' => 'cloudfoundry/docs-cloudfoundry-concepts',
                            'ref' => 'pre-release' },
          'directory' => 'concepts',
          'dependent_sections' => [
            { 'repository' => { 'name' => 'my-dependy/docs',
                                'ref' => 'master' },
              'directory' => 'dependy-docs' } ] },
        { 'repository' => { 'name' => 'cloudfoundry/docs-dev-guide',
                            'ref' => 'pre-release'},
          'directory' => 'devguide' },
        { 'repository' => { 'name' => 'my-cool-thing/docs',
                            'ref' => 'master'},
          'directory' => 'cool-things/stuff' },
        { 'repository' => { 'name' => 'my-cool-thing/docs',
                            'ref' => 'pre-release'},
          'directory' => 'cool-things/pre-release' },
        { 'repository' => { 'name' => 'my-cool-thing/docs',
                            'ref' => 'master'},
          'directory' => 'cool-things/things' }
      ]
    )
  }

  let(:options) { {bookbinder_edge: false} }

  describe '#bind_resources' do
    it 'should have Concourse resources' do
      expect(scheme.bind_resources).to match_array([
        { 'name' => 'concourse-scripts-docs-master',
          'type' => 'git',
          'source' => { 'uri' => 'git@github.com:pivotal-cf/concourse-scripts-docs.git',
                        'branch' => 'master',
                        'private_key' => '{{github-deploy-bot}}' }},
        { 'name' => 'docs-book-cloudfoundry-pre-release',
          'type' => 'git',
          'source' => { 'uri' => 'git@github.com:cloudfoundry/docs-book-cloudfoundry.git',
                        'branch' => 'pre-release',
                        'private_key' => '{{github-deploy-bot}}' }},
        { 'name' => 'docs-layout-repo-pre-release',
          'type' => 'git',
          'source' => { 'uri' => 'git@github.com:pivotal-cf/docs-layout-repo.git',
                        'branch' => 'pre-release',
                        'private_key' => '{{github-deploy-bot}}' }},
        { 'name' => 'docs-cloudfoundry-concepts-pre-release',
          'type' => 'git',
          'source' => { 'uri' => 'git@github.com:cloudfoundry/docs-cloudfoundry-concepts.git',
                        'branch' => 'pre-release',
                        'private_key' => '{{github-deploy-bot}}' }},
        { 'name' => 'docs-dev-guide-pre-release',
          'type' => 'git',
          'source' => { 'uri' => 'git@github.com:cloudfoundry/docs-dev-guide.git',
                        'branch' => 'pre-release',
                        'private_key' => '{{github-deploy-bot}}' }},
        { 'name' => 'docs-my-cool-thing-master',
          'type' => 'git',
          'source' => { 'uri' => 'git@github.com:my-cool-thing/docs.git',
                        'branch' => 'master',
                        'private_key' => '{{github-deploy-bot}}' }},
        { 'name' => 'docs-my-cool-thing-pre-release',
          'type' => 'git',
          'source' => { 'uri' => 'git@github.com:my-cool-thing/docs.git',
                        'branch' => 'pre-release',
                        'private_key' => '{{github-deploy-bot}}' }},
        { 'name' => 'docs-my-dependy-master',
          'type' => 'git',
          'source' => { 'uri' => 'git@github.com:my-dependy/docs.git',
                        'branch' => 'master',
                        'private_key' => '{{github-deploy-bot}}' }},
        { 'name' => 'bookbinder-release-complete',
          'type' => 's3',
          'source' => {
            'bucket' => 'concourse-interim-steps',
            'versioned_file' => 'bookbinder-release-complete.tar.gz',
            'private' => true,
            'access_key_id' => "{{aws-access-key}}",
            'secret_access_key' => "{{aws-secret-key}}" }},
      ])
    end

    context 'when bookbinder_edge option is set' do
      let(:options) { {bookbinder_edge: true} }
      it 'should have bookbinder-edge resources' do
        expect(scheme.bind_resources).to include(
          { 'name' => 'bookbinder-edge-release-complete',
            'type' => 's3',
            'source' => {
              'bucket' => 'concourse-interim-steps',
              'versioned_file' => 'bookbinder-edge-release-complete.tar.gz',
              'private' => true,
              'access_key_id' => "{{aws-access-key}}",
              'secret_access_key' => "{{aws-secret-key}}" }},
        )
      end
    end
  end

  describe '#bind_plan' do
    it 'should have a Concourse build plan' do
      expect(scheme.bind_plan).to eq([
        { 'aggregate' =>
          [
            { 'get' => 'concourse-scripts', 'resource' => 'concourse-scripts-docs-master', 'trigger' => false, 'params' => { 'submodules' => 'none' } },
            { 'get' => 'book', 'resource' => 'docs-book-cloudfoundry-pre-release', 'trigger' => true, 'params' => { 'submodules' => 'none' } },
            { 'get' => 'docs-layout-repo', 'resource' => 'docs-layout-repo-pre-release', 'trigger' => true, 'params' => { 'submodules' => 'none' } },
            { 'get' => 'docs-cloudfoundry-concepts-pre-release', 'resource' => 'docs-cloudfoundry-concepts-pre-release', 'trigger' => true, 'params' => { 'submodules' => 'none' } },
            { 'get' => 'docs-dev-guide-pre-release', 'resource' => 'docs-dev-guide-pre-release', 'trigger' => true, 'params' => { 'submodules' => 'none' } },
            { 'get' => 'docs-my-cool-thing-master', 'resource' => 'docs-my-cool-thing-master', 'trigger' => true, 'params' => { 'submodules' => 'none' } },
            { 'get' => 'docs-my-cool-thing-pre-release', 'resource' => 'docs-my-cool-thing-pre-release', 'trigger' => true, 'params' => { 'submodules' => 'none' } },
            { 'get' => 'docs-my-dependy-master', 'resource' => 'docs-my-dependy-master', 'trigger' => true, 'params' => { 'submodules' => 'none' } },
            { 'get' => 'bookbinder-release', 'resource' => 'bookbinder-release-complete', 'trigger' => true },
          ]
        },
        { 'task' => 'oss-bind', 'file' => 'concourse-scripts/cf-pre-release/group/oss-bind/task.yml',
          'on_failure'=>
            {'params'=>
              {'text'=>
                'The `$BUILD_PIPELINE_NAME` pipeline is broken. `$BUILD_JOB_NAME` job failed on build `$BUILD_NAME`: https://concourse.run.pivotal.io/teams/$BUILD_TEAM_NAME/pipelines/$BUILD_PIPELINE_NAME/jobs/$BUILD_JOB_NAME/builds/$BUILD_NAME'},
              'put'=>'notify'},
        },
        { 'aggregate' =>
          [
            { 'put' => 'cf-pre-release-oss-s3', 'params' => { 'file' => 'bind_output/final_app.tar.gz' } },
          ]
        }
      ])
    end
    context 'when bookbinder_edge option is set' do
      let(:options) { {bookbinder_edge: true} }
      it 'should have bookbinder-edge resources as the release' do
      expect(scheme.bind_plan).to eq([
        { 'aggregate' =>
          [
            { 'get' => 'concourse-scripts', 'resource' => 'concourse-scripts-docs-master', 'trigger' => false, 'params' => { 'submodules' => 'none' } },
            { 'get' => 'book', 'resource' => 'docs-book-cloudfoundry-pre-release', 'trigger' => true, 'params' => { 'submodules' => 'none' } },
            { 'get' => 'docs-layout-repo', 'resource' => 'docs-layout-repo-pre-release', 'trigger' => true, 'params' => { 'submodules' => 'none' } },
            { 'get' => 'docs-cloudfoundry-concepts-pre-release', 'resource' => 'docs-cloudfoundry-concepts-pre-release', 'trigger' => true, 'params' => { 'submodules' => 'none' } },
            { 'get' => 'docs-dev-guide-pre-release', 'resource' => 'docs-dev-guide-pre-release', 'trigger' => true, 'params' => { 'submodules' => 'none' } },
            { 'get' => 'docs-my-cool-thing-master', 'resource' => 'docs-my-cool-thing-master', 'trigger' => true, 'params' => { 'submodules' => 'none' } },
            { 'get' => 'docs-my-cool-thing-pre-release', 'resource' => 'docs-my-cool-thing-pre-release', 'trigger' => true, 'params' => { 'submodules' => 'none' } },
            { 'get' => 'docs-my-dependy-master', 'resource' => 'docs-my-dependy-master', 'trigger' => true, 'params' => { 'submodules' => 'none' } },
            { 'get' => 'bookbinder-release', 'resource' => 'bookbinder-edge-release-complete', 'trigger' => true },
          ]
        },
        { 'task' => 'oss-bind', 'file' => 'concourse-scripts/cf-pre-release/group/oss-bind/task.yml',
          'on_failure'=>
            {'params'=>
              {'text'=>
                'The `$BUILD_PIPELINE_NAME` pipeline is broken. `$BUILD_JOB_NAME` job failed on build `$BUILD_NAME`: https://concourse.run.pivotal.io/teams/$BUILD_TEAM_NAME/pipelines/$BUILD_PIPELINE_NAME/jobs/$BUILD_JOB_NAME/builds/$BUILD_NAME'},
              'put'=>'notify'},
        },
        { 'aggregate' =>
          [
            { 'put' => 'cf-pre-release-oss-s3', 'params' => { 'file' => 'bind_output/final_app.tar.gz' } },
          ]
        }
      ])
      end
    end
  end

  describe '#bind_task' do
    it 'should have a Concourse-compatible hash' do
      expect(scheme.bind_task).to eq(YAML.load(<<-TASK))
platform: linux

image_resource:
  type: docker-image
  source:
    repository: pubtools/bookbinder-8.1

inputs:
  - name: bookbinder-release
  - name: concourse-scripts
  - name: book
  - name: docs-layout-repo
  - name: docs-cloudfoundry-concepts-pre-release
  - name: docs-dev-guide-pre-release
  - name: docs-my-cool-thing-master
  - name: docs-my-cool-thing-pre-release
  - name: docs-my-dependy-master

outputs:
  - name: bind_output

run:
  path: concourse-scripts/bookbinder-bind-local.sh
      TASK
    end
    context 'when bookbinder_edge option is set' do
      let(:options) { {bookbinder_edge: true} }
      it 'should have bookbinder-edge resources' do
      expect(scheme.bind_task).to eq(YAML.load(<<-TASK))
platform: linux

image_resource:
  type: docker-image
  source:
    repository: pubtools/bookbinder-10.1.15

inputs:
  - name: bookbinder-release
  - name: concourse-scripts
  - name: book
  - name: docs-layout-repo
  - name: docs-cloudfoundry-concepts-pre-release
  - name: docs-dev-guide-pre-release
  - name: docs-my-cool-thing-master
  - name: docs-my-cool-thing-pre-release
  - name: docs-my-dependy-master

outputs:
  - name: bind_output

run:
  path: concourse-scripts/bookbinder-bind-local.sh
      TASK
      end
    end
  end

  describe '#deploy_plan' do
    it 'should have a Concourse deploy plan for a staging environment' do
      expect(scheme.deploy_plan('staging', 'book_id', 'bind', true)).to eq([
        { 'aggregate' =>
          [
            { 'get' => 'concourse-scripts', 'resource' => 'concourse-scripts-docs-master', 'passed' => ['oss-bind'] },
            { 'get' => 'concourse-scripts-bundle' },
            { 'get' => 'site-source', 'resource' => 'cf-pre-release-oss-s3', 'passed' => ['oss-bind'], 'trigger' => true },
          ]
        },
        {
          'task' => 'deploy',
          'file' => 'concourse-scripts/deploy_task.yml',
          'on_failure'=>
            {'params'=>
              {'text'=>
                'The `$BUILD_PIPELINE_NAME` pipeline is broken. `$BUILD_JOB_NAME` job failed on build `$BUILD_NAME`: https://concourse.run.pivotal.io/teams/$BUILD_TEAM_NAME/pipelines/$BUILD_PIPELINE_NAME/jobs/$BUILD_JOB_NAME/builds/$BUILD_NAME'},
              'put'=>'notify'},
          'params' => {
            'DEPLOY_DETAILS' => 'concourse-scripts/cf-pre-release/group/config.yml',
            'DEPLOY_ENV' => 'staging',
            'BOOK_ID' => 'book_id',
            'USERNAME' => "{{cloud-foundry-username}}",
            'PASSWORD' => "{{cloud-foundry-password}}"
          }
        }
      ])
    end

    context 'when bookbinder_edge option is set' do
      let(:options) { {bookbinder_edge: true} }
      it 'should use bookbinder-edge branch to deploy to staging' do
      expect(scheme.deploy_plan('staging', 'book_id', 'bind', true)).to eq([
        { 'aggregate' =>
          [
            { 'get' => 'concourse-scripts', 'resource' => 'concourse-scripts-docs-master', 'passed' => ['oss-bind'] },
            { 'get' => 'concourse-scripts-bundle' },
            { 'get' => 'site-source', 'resource' => 'cf-pre-release-oss-s3', 'passed' => ['oss-bind'], 'trigger' => true },
            { 'get' => 'concourse-scripts-bookbinder-edge', 'resource' => 'concourse-scripts-bookbinder-edge' },
          ]
        },
        {
          'task' => 'deploy',
          'file' => 'concourse-scripts-bookbinder-edge/deploy_task.yml',
          'on_failure'=>
            {'params'=>
              {'text'=>
                'The `$BUILD_PIPELINE_NAME` pipeline is broken. `$BUILD_JOB_NAME` job failed on build `$BUILD_NAME`: https://concourse.run.pivotal.io/teams/$BUILD_TEAM_NAME/pipelines/$BUILD_PIPELINE_NAME/jobs/$BUILD_JOB_NAME/builds/$BUILD_NAME'},
              'put'=>'notify'},
          'params' => {
            'DEPLOY_DETAILS' => 'concourse-scripts/cf-pre-release/group/config.yml',
            'DEPLOY_ENV' => 'staging',
            'BOOK_ID' => 'book_id',
            'USERNAME' => "{{cloud-foundry-username}}",
            'PASSWORD' => "{{cloud-foundry-password}}"
          }
        }
      ])
    end
    end

    it 'should have a custom Concourse deploy plan' do
      expect(scheme.deploy_plan('thingy-1-7', 'book_id', 'dependency', false)).to eq([
        { 'aggregate' =>
          [
            { 'get' => 'concourse-scripts', 'resource' => 'concourse-scripts-docs-master', 'passed' => ['oss-dependency'] },
            { 'get' => 'concourse-scripts-bundle' },
            { 'get' => 'site-source', 'resource' => 'cf-pre-release-oss-s3', 'passed' => ['oss-dependency'], 'trigger' => false },
          ]
        },
        {
          'task' => 'deploy',
          'file' => 'concourse-scripts/deploy_task.yml',
          'on_failure'=>
            {'params'=>
              {'text'=>
                'The `$BUILD_PIPELINE_NAME` pipeline is broken. `$BUILD_JOB_NAME` job failed on build `$BUILD_NAME`: https://concourse.run.pivotal.io/teams/$BUILD_TEAM_NAME/pipelines/$BUILD_PIPELINE_NAME/jobs/$BUILD_JOB_NAME/builds/$BUILD_NAME'},
              'put'=>'notify'},
          'params' => {
            'DEPLOY_DETAILS' => 'concourse-scripts/cf-pre-release/group/config.yml',
            'DEPLOY_ENV' => 'thingy_1_7',
            'BOOK_ID' => 'book_id',
            'USERNAME' => "{{cloud-foundry-username}}",
            'PASSWORD' => "{{cloud-foundry-password}}"
          }
        }
      ])
    end

    context 'when bookbinder_edge option is set' do
      let(:options) { {bookbinder_edge: true} }
      it 'should use bookbinder-edge branch to deploy' do
        expect(scheme.deploy_plan('thingy-1-7', 'book_id', 'dependency', false)).to eq([
          { 'aggregate' =>
            [
              { 'get' => 'concourse-scripts', 'resource' => 'concourse-scripts-docs-master', 'passed' => ['oss-dependency'] },
              { 'get' => 'concourse-scripts-bundle' },
              { 'get' => 'site-source', 'resource' => 'cf-pre-release-oss-s3', 'passed' => ['oss-dependency'], 'trigger' => false },
              { 'get' => 'concourse-scripts-bookbinder-edge', 'resource' => 'concourse-scripts-bookbinder-edge'},
            ]
          },
          {
            'task' => 'deploy',
            'file' => 'concourse-scripts-bookbinder-edge/deploy_task.yml',
            'on_failure'=>
              {'params'=>
                {'text'=>
                  'The `$BUILD_PIPELINE_NAME` pipeline is broken. `$BUILD_JOB_NAME` job failed on build `$BUILD_NAME`: https://concourse.run.pivotal.io/teams/$BUILD_TEAM_NAME/pipelines/$BUILD_PIPELINE_NAME/jobs/$BUILD_JOB_NAME/builds/$BUILD_NAME'},
                'put'=>'notify'},
            'params' => {
              'DEPLOY_DETAILS' => 'concourse-scripts/cf-pre-release/group/config.yml',
              'DEPLOY_ENV' => 'thingy_1_7',
              'BOOK_ID' => 'book_id',
              'USERNAME' => "{{cloud-foundry-username}}",
              'PASSWORD' => "{{cloud-foundry-password}}"
            }
          }
        ])
    end
    end
  end

  describe '#deploy_details' do
    it 'should ensure routes have all keys' do
      expect(scheme.deploy_details('endpoint' => 'foo.com', 'organization' => 'bar', 'space' => 'baz', 'routes' => [
        { 'domain' => 'baz.io', 'hostname' => 'hello' },
        { 'domain' => 'bar.io', 'path' => 'foo' }
      ])).to eq({
        'endpoint' => 'foo.com',
        'organization' => 'bar',
        'space' => 'baz',
        'routes' => [
          { 'domain' => 'baz.io', 'hostname' => 'hello', 'path' => '' },
          { 'domain' => 'bar.io', 'hostname' => '', 'path' => 'foo' }
        ]
      })
    end
  end

  context 'with no layout repo' do
    let(:config) do
      PubTools::Config.new(GitResource.from_id('cloudfoundry/docs-book-cloudfoundry', branch: 'pre-release', friendly_name: 'book'),
        'cred_repo' => 'pivotal-cf/docs-oss-pre-release-site-credentials',
        'sections' => [
          { 'repository' => { 'name' => 'my-cool-thing/docs',
                              'ref' => 'master'},
            'directory' => 'cool-things/things' }
        ]
      )
    end

    it 'should not include layout in sources' do
      expect(scheme.bind_resources).to match_array([
        { 'name' => 'concourse-scripts-docs-master',
          'type' => 'git',
          'source' => { 'uri' => 'git@github.com:pivotal-cf/concourse-scripts-docs.git',
                        'branch' => 'master',
                        'private_key' => '{{github-deploy-bot}}' }},
        { 'name' => 'docs-book-cloudfoundry-pre-release',
          'type' => 'git',
          'source' => { 'uri' => 'git@github.com:cloudfoundry/docs-book-cloudfoundry.git',
                        'branch' => 'pre-release',
                        'private_key' => '{{github-deploy-bot}}' }},
        { 'name' => 'docs-my-cool-thing-master',
          'type' => 'git',
          'source' => { 'uri' => 'git@github.com:my-cool-thing/docs.git',
                        'branch' => 'master',
                        'private_key' => '{{github-deploy-bot}}' }},
        { 'name' => 'bookbinder-release-complete',
          'type' => 's3',
          'source' => {
            'bucket' => 'concourse-interim-steps',
            'versioned_file' => 'bookbinder-release-complete.tar.gz',
            'private' => true,
            'access_key_id' => "{{aws-access-key}}",
            'secret_access_key' => "{{aws-secret-key}}" }},
      ])
    end

    it 'should not include layout in plan' do
      expect(scheme.bind_plan).to eq([
        { 'aggregate' =>
          [
            { 'get' => 'concourse-scripts', 'resource' => 'concourse-scripts-docs-master', 'trigger' => false, 'params' => { 'submodules' => 'none' } },
            { 'get' => 'book', 'resource' => 'docs-book-cloudfoundry-pre-release', 'trigger' => true, 'params' => { 'submodules' => 'none' } },
            { 'get' => 'docs-my-cool-thing-master', 'resource' => 'docs-my-cool-thing-master', 'trigger' => true, 'params' => { 'submodules' => 'none' } },
            { 'get' => 'bookbinder-release', 'resource' => 'bookbinder-release-complete', 'trigger' => true },
          ]
        },
        { 'task' => 'oss-bind', 'file' => 'concourse-scripts/cf-pre-release/group/oss-bind/task.yml',
          'on_failure'=>
            {'params'=>
              {'text'=>
                'The `$BUILD_PIPELINE_NAME` pipeline is broken. `$BUILD_JOB_NAME` job failed on build `$BUILD_NAME`: https://concourse.run.pivotal.io/teams/$BUILD_TEAM_NAME/pipelines/$BUILD_PIPELINE_NAME/jobs/$BUILD_JOB_NAME/builds/$BUILD_NAME'},
              'put'=>'notify'},
        },
        { 'aggregate' =>
          [
            { 'put' => 'cf-pre-release-oss-s3', 'params' => { 'file' => 'bind_output/final_app.tar.gz' } },
          ]
        }
      ])
    end

    it 'should not include layout in bind task yml' do
      expect(scheme.bind_task).to eq(YAML.load(<<-TASK))
platform: linux

image_resource:
  type: docker-image
  source:
    repository: pubtools/bookbinder-8.1

inputs:
  - name: bookbinder-release
  - name: concourse-scripts
  - name: book
  - name: docs-my-cool-thing-master

outputs:
  - name: bind_output

run:
  path: concourse-scripts/bookbinder-bind-local.sh
      TASK
    end
  end
end
