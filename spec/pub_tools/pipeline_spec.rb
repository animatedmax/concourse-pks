require_relative '../spec_helper'

require 'pub_tools/pipeline'

describe Pipeline do
  subject(:pipeline) { Pipeline.new(schemes, cf_resources, groups) }

  let(:schemes) {{ 'totally-sweet-job' => totally_sweet_job,
                 'awesome-job' => awesome_job }}

  let(:totally_sweet_job) { YAML.load(<<-JOB) }
sources:
- name: my-awesome-resource
  type: git
  source:
    uri: git@github.com:some-org/a-repo.git
    branch: pre-release
    private_key: "{{my-awesome-resource}}"
- name: another-sweet-resource
  type: git
  source:
    uri: git@github.com:some-org/b-repo.git
    branch: pre-release
    private_key: "{{another-sweet-resource}}"
plan:
- aggregate:
  - get: my-awesome-resource
    resource: yadda-yadda-yadda
    trigger: true
  - get: another-sweet-resource
    trigger: true
- task: do-cool-things
  file: path/to/a/file.yml
  JOB

  let(:awesome_job) { YAML.load(<<-JOB) }
sources:
- name: yet-another-resource
  type: git
  source:
    uri: git@github.com:another-org/another-repo.git
    branch: pre-release
    private_key: "{{yet-another-resource}}"
plan:
- get: yet-another-resource
  trigger: true
- task: do-more-stuff
  file: more/paths/to/stuff.yml
  JOB

  let(:cf_resources) { YAML.load(<<-CF_RESOURCES)
- name: cool-resource-name
  type: a-concourse-put-type
  source:
    a-key: some-value
  CF_RESOURCES
  }

  let(:groups) { YAML.load(<<-GROUPS) }
- name: group one!
  jobs:
  - totally-sweet-job
  - awesome-job
  GROUPS

  describe '#resources' do
    it 'should merge the resources' do
      expect(pipeline.resources).to eq(YAML.load(<<-RESOURCES))
- name: my-awesome-resource
  type: git
  source:
    uri: git@github.com:some-org/a-repo.git
    branch: pre-release
    private_key: "{{my-awesome-resource}}"
- name: another-sweet-resource
  type: git
  source:
    uri: git@github.com:some-org/b-repo.git
    branch: pre-release
    private_key: "{{another-sweet-resource}}"
- name: yet-another-resource
  type: git
  source:
    uri: git@github.com:another-org/another-repo.git
    branch: pre-release
    private_key: "{{yet-another-resource}}"
- name: cool-resource-name
  type: a-concourse-put-type
  source:
    a-key: some-value
      RESOURCES
    end

    context 'when there are duplicate resources' do
      let(:duplicate_resource) { totally_sweet_job['sources'].first }
      let(:awesome_job) {
        super().tap { |job| job['sources'] << duplicate_resource }
      }

      it 'should not include the same resource more than once' do
        expect(pipeline.resources.count(duplicate_resource)).to eq(1)
      end
    end

    context 'when there are different resources with the same name' do
      let(:awesome_job) {
        resource = { 'name' => 'my-awesome-resource',
                     'type' => 'git',
                     'source' => { 'uri' => 'git@github.com:some-org/a-repo.git',
                                   'branch' => 'master',
                                   'private_key' => '{{my-awesome-resource}}'} }
        super().tap { |job| job['sources'] << resource }
      }

      it 'should raise an error' do
        expect { pipeline.resources }.to raise_error(ResourceConflictError) { |error|
          expect(error.message).to include('totally-sweet-job')
          expect(error.message).to include('awesome-job')
          expect(error.message).to include('my-awesome-resource')
        }
      end
    end
  end

  describe '#jobs' do
    it 'should merge the jobs' do
      expect(pipeline.jobs).to eq(YAML.load(<<-JOBS))
- name: totally-sweet-job
  serial: true
  plan:
  - aggregate:
    - get: my-awesome-resource
      resource: yadda-yadda-yadda
      trigger: true
    - get: another-sweet-resource
      trigger: true
  - task: do-cool-things
    file: path/to/a/file.yml
- name: awesome-job
  serial: true
  plan:
  - get: yet-another-resource
    trigger: true
  - task: do-more-stuff
    file: more/paths/to/stuff.yml
      JOBS
    end
  end

  describe '#groups' do
    it 'should merge the groups' do
      expect(pipeline.groups).to eq(YAML.load(<<-GROUPS))
- name: group one!
  jobs:
  - totally-sweet-job
  - awesome-job
      GROUPS
    end
  end
end
