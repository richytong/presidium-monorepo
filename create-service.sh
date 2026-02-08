#!/usr/bin/env node

const fs = require('fs')

setImmediate(async () => {
  const serviceName = process.argv[2]

  if (!serviceName) {
    throw new Error('serviceName required.')
  }

  if (/[^a-z0-9-]/g.test(serviceName)) {
    throw new Error('serviceName can only contain lowercase letters, numbers, and dashes (`-`)')
  }

  console.log(`Creating service ${serviceName}...`)

  await fs.promises.mkdir(`${__dirname}/${serviceName}`)

  await fs.promises.writeFile(`${__dirname}/${serviceName}/run.sh`, `
#!/usr/bin/env node

if (process.env.NODE_ENV == null) {
  throw new Error('NODE_ENV required')
}

async function run() {
}

run()
  `.trim())

  await fs.promises.chmod(`${__dirname}/${serviceName}/run.sh`, 0o755)

  await fs.promises.writeFile(`${__dirname}/${serviceName}/test.sh`, '#!/bin/sh\n\n')

  await fs.promises.chmod(`${__dirname}/${serviceName}/test.sh`, 0o755)

  await fs.promises.writeFile(`${__dirname}/${serviceName}/package.json`, `
{
  "name": "${serviceName}",
  "version": "0.0.0",
  "env": {
    "test": {
    },
    "production": {
    }
  },
  "secrets": {
    "production": []
  }
}
  `.trim())

  await fs.promises.writeFile(`${__dirname}/${serviceName}/build-push.sh`, `
#!/usr/bin/env node

const AwsCredentials = require('presidium/AwsCredentials')
const NpmToken = require('presidium/NpmToken')
const SecretsManager = require('presidium/SecretsManager')
const Docker = require('presidium/Docker')
const ECR = require('presidium/ECR')
const fs = require('fs')
const AWSConfig = require('../AWSConfig.json')
const ports = require('../ports.json')
const monorepoPackage = require('../package.json')
const package = require('./package.json')

setImmediate(async function () {
  const env = process.env.NODE_ENV

  if (env == null) {
    throw new Error('NODE_ENV required')
  }

  const awsCreds = await AwsCredentials(AWSConfig.profile)
  awsCreds.region = AWSConfig.region

  const npmToken = await NpmToken()

  const secretsManager = new SecretsManager({ ...awsCreds })

  const npmrc = fs.createWriteStream(\`\${__dirname}/.npmrc\`)
  npmrc.write(\`//registry.npmjs.org/:_authToken=\${npmToken}\`)
  npmrc.end()

  const secretsFile = fs.createWriteStream(\`\${__dirname}/.secrets\`)
  secretsFile.write(\`AWS_ACCESS_KEY_ID=\${awsCreds.accessKeyId}\\n\`)
  secretsFile.write(\`AWS_SECRET_ACCESS_KEY=\${awsCreds.secretAccessKey}\\n\`)
  secretsFile.write(\`AWS_REGION=\${awsCreds.region}\\n\`)

  for (const secretName of package.secrets[env] ?? []) {
    const secret = await secretsManager.getSecret(secretName)
    secretsFile.write(\`\${secretName}=\${secret.SecretString}\\n\`)
  }
  secretsFile.end()

  const docker = new Docker({ apiVersion: '1.44' })

  const ecr = new ECR({ ...awsCreds })

  const serviceRepository = \`\${monorepoPackage.name}/\${package.name}\`
  const image = \`\${serviceRepository}:\${package.version}\`

  const buildStream = await docker.buildImage(__dirname, {
    ignore: ['.github', 'node_modules', 'build-push', 'deploy', 'test.js'],
    image,
    archive: {
      Dockerfile: \`
FROM node:24-alpine
WORKDIR /home/node
COPY . .
RUN apk add curl \
  && npm i \
  && chmod +x ./run.sh \
  && rm .npmrc \
  && rm Dockerfile
USER node
      \`, 
    },
    platform: 'x86_64',
  })

  buildStream.on('data', chunk => {
    const message = chunk.toString('utf8')
    if (message.includes('error')) {
      throw new Error(message)
    }
  })

  buildStream.pipe(process.stdout)

  await new Promise(resolve => buildStream.on('end', resolve))

  const registry = \`\${AWSConfig.accountId}.dkr.ecr.\${AWSConfig.region}.amazonaws.com\`

  await docker.tagImage(
    image,
    \`\${registry}/\${image}\`,
  )

  await ecr.createRepository(serviceRepository).catch(() => {})

  const authToken = await ecr.getAuthorizationToken()

  const pushStream = await docker.pushImage({
    image,
    registry,
    authToken,
  })
  pushStream.pipe(process.stdout)

  pushStream.on('data', chunk => {
    const message = chunk.toString('utf8')
    if (message.includes('error')) {
      throw new Error(message)
    }
  })

  await new Promise(resolve => pushStream.on('end', resolve))

  await fs.promises.rm(\`\${__dirname}/.npmrc\`)
  await fs.promises.rm(\`\${__dirname}/.secrets\`)
})
  `.trim())

  await fs.promises.chmod(`${__dirname}/${serviceName}/build-push.sh`, 0o755)

  await fs.promises.writeFile(`${__dirname}/${serviceName}/deploy.sh`, `
#!/usr/bin/env node

if (process.env.NODE_ENV == null) {
  throw new Error('NODE_ENV required')
}

const AwsCredentials = require('presidium/AwsCredentials')
const SecretsManager = require('presidium/SecretsManager')
const Docker = require('presidium/Docker')
const ECR = require('presidium/ECR')
const AWSConfig = require('../AWSConfig.json')
const ports = require('../ports.json')
const monorepoPackage = require('../package.json')
const package = require('./package')

setImmediate(async () => {
  const awsCreds = await AwsCredentials(AWSConfig.profile)
  awsCreds.region = AWSConfig.region

  const secretsManager = new SecretsManager({ ...awsCreds })

  const docker = new Docker({ apiVersion: '1.44' })

  const ecr = new ECR({ ...awsCreds })

  const registry = \`\${AWSConfig.accountId}.dkr.ecr.\${AWSConfig.region}.amazonaws.com\`
  const serviceRepository = \`\${monorepoPackage.name}/\${package.name}\`
  const image = \`\${serviceRepository}:\${package.version}\`

  const authToken = await ecr.getAuthorizationToken()
  const decoded = Buffer.from(authToken, 'base64').toString('utf8')
  const [username, password] = decoded.split(':')

  const servicePort = ports[package.name]

  const serviceOptions = {
    image: \`\${registry}/\${image}\`,
    cmd: ['./run.sh'],
    healthCmd: ['curl', '127.0.0.1:8080/health'],
    env: {
      NODE_ENV: process.env.NODE_ENV,
      ...package.env[process.env.NODE_ENV],
    },
    ...servicePort == null ? {} : {
      publish: {
        [servicePort]: 8080,
      },
    },
    replicas: 1,
    restart: 'any',
    username,
    password,
  }

  console.log(\`Deploying \${package.name}@\${package.version}...\`)
  try {
    await docker.createService(package.name, serviceOptions)
  } catch (_error) {
    await docker.updateService(package.name, serviceOptions)
  }
})
  `.trim())

  await fs.promises.chmod(`${__dirname}/${serviceName}/deploy.sh`, 0o755)
})
