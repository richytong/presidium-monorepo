# presidium-monorepo
Quickstart project for a monorepo using Presidium.

Tech stack:
  * Presidium - clients for web services including AWS and Docker
  * Node.js - JavaScript runtime
  * AWS - hosting, databases, file storage
  * Docker - containerization
  * Docker Swarm - container orchestration

## Project Structure
```
presidium-monorepo/
    <service_name>/
        run.sh
        test.sh
        package.json
        Dockerfile
        build-push.sh
        deploy.sh
    ports.json
    AWSConfig.json
    swarmConfig.json
    package.json
    create-service.sh
    import-service.sh
    deploy-all.sh
    init-swarm.sh
    destroy-swarm.sh
    join-swarm.sh
```

### [<service_name>](/example-service)
A project that represents a service running on the Docker swarm.

### [<service_name>/run.sh](/example-service/run.sh)
The service entrypoint. This file is used to start the service.

### [<service_name>/test.sh](/example-service/test.sh)
The test entrypoint for the service. The test command should go here

### [<service_name>/package.json](/example-service/package.json)
The service project configuration.

`package.json` fields:
  * `name` - the name of the service. Can only contain lowercase letters, numbers, and dashes (`-`).
  * `version` - the version of the service.
  * `dependencies` - external dependencies needed by the service.
  * `env` - the environment-specific environment variables that will be provided to the service environment.
  * `secrets` - the environment-specific secrets that will be provided to and read from the `.secrets` file of the service. Warning: the `.secrets` file MUST be removed once read in production. The Presidium library offers a [`Secrets`](https://presidium.services/docs/Secrets) class that reads the `.secrets` file and removes the file after reading.

`package.json` `env` structure:
```
{
  production: {
    VARIABLE_1: 'production-example',
    VARIABLE_2: 'production-example',
    ...
  },
  local: {
    VARIABLE_1: 'local-example',
    VARIABLE_2: 'local-example',
    ...
  },
  ...
}
```

`package.json` `secrets` structure
```
{
  production: [
    "production/SECRET_VARIABLE_1"
    "production/SECRET_VARIABLE_2"
    ...
  ],
}
```

`.secrets` file structure
```
production/SECRET_VARIABLE_1=<secret_variable_1_value>
production/SECRET_VARIABLE_2=<secret_variable_2_value>
```

### [<service_name>/Dockerfile](/example-service/Dockerfile)
The service `Dockerfile`. Used to build the Docker image of the service.

References:
  * [Dockerfile](https://docs.docker.com/reference/dockerfile/)

### [<service_name>/build-push.sh](/example-service/build-push.sh)
The service `build-push.sh` script. Builds the service with Docker, creating a Docker image of the service, and pushes the Docker image of the service to [Amazon ECR](https://aws.amazon.com/ecr/). Should only be run on a machine with the same architecture as an EC2 instance (`x86_64` or `arm64`).

Usage:
```sh
`./build-push [--Dockerfile <Dockerfile_path>]`
```

Options:
  * `--Dockerfile <Dockerfile_path>` - tells Docker to use the Dockerfile at the path `<Dockerfile_path>` to build the service.

### [<service_name>/deploy.sh](/example-service/deploy.sh)
The service `deploy.sh` script. Deploys the service to the Docker swarm using the Presidium Docker client. If the service has a port allocated, `deploy.sh` reads the service port from [`ports.json`](/ports.json). Should only be run on a manger node.

References:
  * [Docker Swarm](https://docs.docker.com/engine/swarm/)
  * [Presidium Docker createService](https://presidium.services/docs/Docker#createService)

### [ports.json](/ports.json)
A JSON file that maps service names onto ports. Used by the `create-service.sh` and `deploy.sh` scripts.

### [AWSConfig.json](/AWSConfig.json)
A JSON config for AWS.

`AWSConfig` fields:
  * `profile` - your AWS profile.
  * `accountId` - your AWS account ID.
  * `region` - your AWS region.

### [swarmConfig.json](/swarmConfig.json)
A JSON config for the Docker swarm.

`swarmConfig` fields.
  * `<env>` - the environment, e.g. `'production'`
    * `name` - the swarm name

### [package.json](/package.json)
The monorepo project configuration.

`package.json` fields:
  * `name` - the name of the monorepo. This could be a domain name.
  * `dependencies` - external dependencies needed by the monorepo.

### [create-service.sh](/create-service.sh)
The `create-service.sh` script. Creates a new service project with the following files:
  * [run.sh](#<service_name>/run.sh)
  * [test.sh](#<service_name>/test.sh)
  * [package.json](#<service_name>/package.json)
  * [Dockerfile](#<service_name>/Dockerfile)
  * [build-push.sh](#<service_name>/build-push.sh)
  * [deploy.sh](#<service_name>/deploy.sh)

Usage:
```sh
./create-service.sh <service_project_name> [--base-image <base_docker_image>] [--allocate-port]
```

Arguments:
  * `service_project_name` - an optional name of the imported service project. If this argument is missing, the service project name defaults to the value of `your_project`.

Options:
  * `--base-image <base_docker_image>` - the base docker image for the imported service project. Defaults to `node:24-alpine` (defined as `defaultBaseImage` in the monorepo `package.json`).
  * `--allocate-port` - allocates a new port in `ports.json` for the service.

### [import-service.sh](/import-service.sh)
The `import-service.sh` script. Imports a GitHub repository as a service project.

Usage:
```sh
./import-service.sh <github_url> [service_project_name] [--base-image <base_docker_image>] [--allocate-port]
```

Arguments:
  * `github_url` - the GitHub url of the service project. Can have the following formats:
    * `git@github.com/<your_username>/<your_project>`
    * `https://github.com/<your_username>/<your_project>`

Options:
  * `service_project_name` - an optional name of the imported service project. If this argument is missing, the service project name defaults to the value of `your_project`.
  * `--base-image <base_docker_image>` - the base docker image for the imported service project. Defaults to `node:24-alpine` (defined as `defaultBaseImage` in the monorepo `package.json`).
  * `--allocate-port` - allocates a new port in `ports.json` for the service.

### [deploy-all.sh](/deploy-all.sh)
The `deploy-all.sh` script. Deploys all services in the monorepo to the Docker swarm.

### [init-swarm.sh](/init-swarm.sh)
The `init-swarm.sh` script. Initializes the Docker swarm. Reads the environment-specific swarm name from `swarmConfig.json`.

### [destroy-swarm.sh](/join-swarm.sh)
The `destroy-swarm.sh` script. Force leaves the current node from the Docker swarm and deletes all swarm data.

### [join-swarm.sh](/join-swarm.sh)
The `join-swarm.sh` script. Joins the current node to the Docker swarm. Reads the environment-specific swarm name from `swarmConfig.json`.

## Configure your local environment for AWS
Ensure there is a file at `~/.aws/credentials` of your local development machine. The file should contain at least the following content:
```
[<your_aws_profile>]
aws_access_key_id = <your_aws_access_key_id>
aws_secret_access_key = <your_aws_secret_access_key>
```

If you don't have your AWS access key ID `<your_aws_access_key_id>` or your AWS secret access key `<your_aws_secret_access_key>`, consult the following guides:
  * [How an IAM administrator can manage IAM user access keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/access-keys-admin-managed.html)
  * [How IAM users can manage their own access keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/access-key-self-managed.html)

Ensure `<your_aws_profile>` matches the value for `profile` in `AWSConfig.json`. Ensure the value of `accountId` in `AWSConfig.json` matches the value of your AWS account ID. Ensure the region in `AWSConfig.json` matches your expected [AWS region](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.RegionsAndAvailabilityZones.html).

## Create a new service
Create a new service project under the path and name `service_name`. The new service project will contain the `run.sh`, `test.sh`, and `package.json` files.
```sh
./create-service.sh <service_name>
```

## Import a project as a service
Project requirements:
  * `run.sh` file - the service entrypoint. This file is used to start the service.

Run the `import-service.sh` script.
```
# ssh
./import-service.sh git@github.com/<your_username>/<your_project>

# https
./import-service.sh https://github.com/<your_username>/<your_project>
```

## Build and push a service
Build and push the service under the name and path `service_name`. A Docker image of the service will be created and pushed up to Amazon ECR.
```sh
./<service_name>/build-push.sh
```

## Deploy a service
Deploy a service to a Docker swarm. Should only be run on a manager node.
```sh
./<service_name>/deploy.sh
```

## AWS tips
  * EC2 security groups should use the default VPC security group.
  * Amazon Linux 2023 is recommended for general use with Docker Swarm.
  * Each EC2 instance needs to install git, Docker, Node.js, and npm.
  * Manager nodes need to have the `~/.npmrc` and `~/.aws/credentials` files.
  * Worker nodes need to have the `~/.aws/credentials` file.

## Useful Docker Swarm cli commands
  * `docker service ls` - lists the Docker services currently running on the swarm.
  * `docker node ls` - lists the Docker nodes currently running on the swarm.
  * `docker service ps` - inspect the tasks of a service. Useful for seeing the status of the deployment of a service.
  * `docker service update --force` - force resets a Docker service. Sometimes useful for fixing a service that has issues deploying.
  * `docker service rollback` - rolls a service back to the previous version.
  * `docker service rm` - removes a service.
  * `docker system prune -af` - prunes unused containers and images from the node / EC2 instance.
