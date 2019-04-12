# General Stuff

This repository contains the Concourse setup for
[Bookbinder](https://github.com/pivotal-cf/bookbinder)-bound books deployed to 
Cloud Foundry.

The Concourse pipelines live at https://concourse.run.pivotal.io/. 
If you need to log in, use the 'Pubtools Concourse CI' username and password in 
Last Pass.

# Concourse Pipelines

A [Concourse](http://concourse.ci/) pipeline is a collection of resources and 
jobs that, together, accomplish some task. 
More information on concourse pipelines can be found in the
[concourse docs](http://concourse.ci/introduction.html).

A pipeline for a book is generated based on the `config.yml` in the book's
repository. To create a new pipeline:

1. Make a new folder with the name of the pipeline
1. Make a child folder with the name of the group
1. Add a `config.yml` and `deployment-resources.yml` for the group
1. Generate the `pipeline.yml` and upload it to concourse

Given the following example config.yml:

```yaml
---
- book: <book-org>/<book-repo-name>
  book_branch: <optional book branch (defaults to master)>
  deployments:
    - name: staging
      depends_on: bind
      trigger: true
    - name: production
      depends_on: staging
      trigger: false
```


The resulting pipeline will look like:

```
                        ----------
[this repo] - - - - - - |        |         -----------         --------------
                        |        |         |         |         |            |
[book] ---------------- |        | ------- | staging | - - - - | production |
                        |  bind  |         | deploy  |         | deploy     |
[book credentials] ---- |        |         |         |         |            |
                        |        |         -----------         --------------
[book section] -------- |        |
                        ----------
```

The incoming lines indicate whether a change will trigger the job. Dashed will
not trigger, and solid line will trigger.

## The bind job

The bind job is responsible for creating the bound book for deployment by later
jobs.

The book is saved to s3 in the "concourse-interim-steps" bucket.

## The deploy jobs

A deploy job is responsible for deploying the bound book onto Cloud Foundry.

* `name` - both the name displayed on the Concourse job and maps to the key under `env` in the `credentials.yml` of the credentials repo for the book.

* `depends_on` - adds a `passed` constraint on inputs for the given job.

* `trigger` - whether or not to automatically run the deploy when previous steps complete.

# Using this repo

## Getting set up

### Requirements

Make sure that you have saved the credentials.yml from LastPass. Within the 'Shared-PubTools' folder there is an item called 'pubtools-concourse-credentials.yml'. The contents of this note should be saved into `pipelines/credentials.yml`. 

`rake newb` will download `fly` from the Concourse instance and do any other initial setup.

This can also be done independently with `rake 'bin/fly'`.

## Generate pipeline.yml

1. Run `rake fly:login` if necessary using the same Pubtools Concourse CI credentials from LastPass
1. Run `rake scheme:update_all[<pipeline>]`
1. Run `rake fly:set_pipeline[<pipeline>]`

## More fine-grained control over generating your pipeline

1. Run `rake scheme:update[<pipeline>/<group>]`
1. Run `rake pipeline:update[<pipeline>]`

## Add a Repo to a Pipeline

**Prerequisite:** 

The repo must be in the `config.yml` for the book, for example `docs-book-pivotalcf`. You must push this change in order for the commands in this procedure to work.  

1. If the repo is private, add `pubtools-docs-helper` as an admin for the repo on github. All github access is done through this pubtools bot on github now. 
1. Navigate to the `concourse-scripts-docs` repo in your workspace and pull the master branch. 
1. Check to see that your `concourse-scripts-docs` directory contains a subdirectory `pipelines` with a file `credentials.yml`. Create the file and directory if they do not exist. 
1. Log in to LastPass and click on 'pubtools-concourse-credentials.yml' in the 'Shared-PubTools' folder. Paste the contents into `pipelines/credentials.yml`. If you have done this step before, you may not need to repeat it.
1. Run `rake fly:login` and use the Pubtools Concourse CI credentials from Lastpass.
1. Run `rake scheme:update[PIPELINE/GROUP]`. The following example updates the cf-current pipeline and the pcf group: `rake scheme:update[cf-current/pcf]`. If you are unsure about the pipeline or group name, see https://pubtools.ci.cf-app.com. The pipelines are listed under the hamburger icon, for example click on `data-docs`, then `gemfire` to obtain `rake scheme:update[data-docs/gemfire]`. The PIPELINE is `data-docs` and the GROUP is `gemfire`.
1. Run `rake fly:set_pipeline[PIPELINE]`. 
1. Type 'y', for yes, when prompted to review configuration changes. 
1. Add, commit, and push the resulting changes to the `concourse-scripts-docs` repo.
1. Go to checkman to confirm that the next build displays the new repo listed in the pipeline. 

## Delete a Job from a Pipeline

Follow the **Add a Repo** sequence, but also delete job-specific directories:

1. Edit `PIPELINE-GROUP/config.yml`, removing entries for the job.
2. Edit `PIPELINE/deployment-resources.yml`, removing any job resources that are no longer needed.
3. Delete job-specific directories, the ones that contain `*.plan` files.
4. Update the pipeline:

    ```
    $ rake scheme:update[PIPELINE/GROUP]
    $ rake pipeline:update[PIPELINE]
    $ rake fly:set_pipeline[PIPELINE]
    ```
1. Type 'y', for yes, when prompted to review configuration changes. 
1. Add, commit, and push the resulting changes to the `concourse-scripts-docs` repo.

## Troubleshooting

Slack Pubtools via the `#cf-pubtools` channel. 

## File Structure

```
concourse-scripts-docs
 |- pipeline-name
     |- deployment-resources.yml
     |- pipeline.yml
     |- pipeline-group-1
     |   |- config.yml
     |   |- pipeline-job-1
     |   |   |- plan.yml
     |   |   |- sources.yml
     |   |   |- task.yml
     |   |- pipeline-job-2
     |       |- plan.yml
     |       |- sources.yml
     |       |- task.yml
     |- pipeline-group-2
         |- config.yml
         |- pipeline-job-1
         |   |- plan.yml
         |   |- sources.yml
         |   |- task.yml
         |- pipeline-job-2
             |- plan.yml
             |- sources.yml
             |- task.yml
```

* `plan.yml` - Includes the steps for a [Concourse job](http://concourse.ci/build-plans.html)
  * does not include the name of the job
  * the pipeline will mark these jobs as serial, so that it will not run more than one at a time
  * generated by `rake scheme:update` or `rake scheme:update_all`
* `sources.yml` - Includes the incoming resources
  * except bundle
  * generated by `rake scheme:update` or `rake scheme:update_all`
* `task.yml` - Includes the whole task configuration for a [Concourse task](http://concourse.ci/running-tasks.html)
  * generated by `rake scheme:update` or `rake scheme:update_all`
* `config.yml` - Config file for generating the pipeline
* `deployment-resources.yml` - Extra resources used for deploying
* `pipeline.yml` - The generated pipeline.yml to upload to Concourse


# Docker

To update the Docker images, modify [docker/Dockerfile](https://github.com/pivotal-cf/concourse-scripts-docs/blob/master/docker/Dockerfile) and then run the following commands in that directory:

Prerequisites:

Install [Docker for Mac](https://docs.docker.com/docker-for-mac/install/). 

Steps:

1. Run the Docker for Mac app and confirm that the Docker daemon is running:

  ```
  $ docker run hello-world
  ```
1. In a terminal, navigate to the `~/workspace/concourse-scripts-docs/docker` directory.
1. Build a new Docker image from the modified Dockerfile with the tag `pubtools/bookbinder-8.1`:

  ```
  $ docker build -t pubtools/bookbinder-8.1 .
  ```
1. Log in to Docker with the credentials in LastPass under the Shared-PubTools folder, listed as "Pubtools Docker Hub":

  ```
  $ docker login
  ```
1. Push your new Docker image to Docker Hub:

  ```
  $ docker push pubtools/bookbinder-8.1
  ```
