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
        build-push.sh
        deploy.sh
    ports.json
    AWSConfig.json
    swarmConfig.json
    package.json
    create-service.sh
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
The test entrypoint for the service. Integration and unit tests should go here.

### [<service_name>/package.json](/example-service/package.json)
The service project configuration.

`package.json` fields:
  * `name` - the name of the service. Can only contain letters, numbers, and dashes (`-`).
  * `version` - the version of the service.
  * `dependencies` - external dependencies needed by the service.
  * `env` - the environment-specific environment variables that will be provided to the service environment.
  * `secrets` - the environment-specific secrets that will be provided to and read from the `.secrets` file of the service.

`env` structure:
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

### [<service_name>/build-push.sh](/example-service/build-push.sh)
The service `build-push.sh` script. Builds the service with Docker, creating a Docker image of the service, and pushes the Docker image of the service to [Amazon ECR](https://aws.amazon.com/ecr/). Should only be run on a machine with the same architecture as an EC2 instance (`x86_64` or `arm64`).

### [<service_name>/deploy.sh](/example-service/deploy.sh)
The service `deploy.sh` script. Deploys the service to the Docker swarm using the Presidium Docker client. If the service has a port allocated, `deploy.sh` reads the service port from [`ports.json`](#ports.json). Should only be run on a manger node.

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
The `create-service.sh` script. Creates a new service project. If the `--allocate-port` option is specified, allocates a new port in `ports.json` for the service.

The new service project will be created with the following files:
  * [run.sh](#<service_name>/run.sh)
  * [test.sh](#<service_name>/test.sh)
  * [package.json](#<service_name>/package.json)
  * [build-push.sh](#<service_name>/build-push.sh)
  * [deploy.sh](#<service_name>/deploy.sh)

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
