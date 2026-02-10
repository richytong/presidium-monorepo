#!/usr/bin/env node

const fs = require('fs')
const package = require('./package')

setImmediate(async () => {
  const serviceName = process.argv[2]

  if (serviceName == null) {
    throw new Error('serviceName argument required.')
  }

  if (/[^a-z0-9-]/g.test(serviceName)) {
    throw new Error('serviceName can only contain lowercase letters, numbers, and dashes (`-`)')
  }

  console.log(`Creating service ${serviceName}...`)

  const baseImage = process.argv.includes('--base-image')
    ? process.argv[process.argv.indexOf('--base-image') + 1]
    : package.defaultBaseImage

  console.log(`Base image: ${baseImage}`)

  await fs.promises.mkdir(`${__dirname}/${serviceName}`)

  await fs.promises.writeFile(`${__dirname}/${serviceName}/run.sh`, `
#!/usr/bin/env node

if (process.env.NODE_ENV == null) {
  throw new Error('NODE_ENV required')
}

const Secrets = require('presidium/Secrets')

async function run() {
  const secrets = await Secrets()
}

run()
  `.trim())

  await fs.promises.chmod(`${__dirname}/${serviceName}/run.sh`, 0o755)

  await fs.promises.writeFile(`${__dirname}/${serviceName}/test.sh`, `
#!/usr/bin/env node

process.env.NODE_ENV = 'test'

const AwsCredentials = require('presidium/AwsCredentials')
const SecretsManager = require('presidium/SecretsManager')
const fs = require('fs')
const { spawn } = require('child_process')
const AWSConfig = require('../AWSConfig.json')
const package = require('./package.json')

const packageEnv = package.env[process.env.NODE_ENV]
for (const name in packageEnv) {
  process.env[name] = packageEnv[name]
}

async function test() {
  const awsCreds = await AwsCredentials(AWSConfig.profile)
  awsCreds.region = AWSConfig.region

  const secretsManager = new SecretsManager({ ...awsCreds })
  const secretsFile = fs.createWriteStream(\`\${__dirname}/.secrets\`)
  secretsFile.write(\`AWS_ACCESS_KEY_ID=\${awsCreds.accessKeyId}\\n\`)
  secretsFile.write(\`AWS_SECRET_ACCESS_KEY=\${awsCreds.secretAccessKey}\\n\`)
  secretsFile.write(\`AWS_REGION=\${awsCreds.region}\\n\`)
  const packageSecrets = package.secrets[process.env.NODE_ENV]
  for (const secretName of packageSecrets) {
    try {
      const secret = await secretsManager.getSecret(secretName)
      secretsFile.write(\`\${secretName}=\${secret.SecretString}\\n\`)
    } catch (error) {
      error.secretName = secretName
      console.error(error)
      continue
    }
  }
  secretsFile.end()
  await new Promise(resolve => secretsFile.on('close', resolve))

  const cmd = spawn(\`\${__dirname}/run.sh\`)
  cmd.stdout.pipe(process.stdout)
  cmd.stderr.pipe(process.stderr)

  process.on('exit', () => {
    cmd.kill()
  })

  const { promise: exitPromise, resolve, reject } = Promise.withResolvers()
  cmd.on('exit', code => {
    if (code == null || code == 0) {
      console.log('Success')
      resolve()
    } else {
      reject(new Error('Failure'))
    }
  })

  // assertions

  // cmd.kill()

  await exitPromise
}

test()
  `.trim())

  await fs.promises.chmod(`${__dirname}/${serviceName}/test.sh`, 0o755)

  await fs.promises.writeFile(`${__dirname}/${serviceName}/package.json`, `
{
  "name": "${serviceName}",
  "version": "0.0.0",
  "dependencies": {
    "presidium": "^1.4.4"
  },
  "env": {
    "production": {
      "MYVAR1": "example1",
      "MYVAR2": "example2"
    },
    "test": {
      "MYVAR1": "testexample1",
      "MYVAR2": "testexample2"
    }
  },
  "secrets": {
    "production": [
      "MYSECRET1",
      "MYSECRET2"
    ],
    "test": [
      "MYSECRET1",
      "MYSECRET2"
    ]
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

  await new Promise(resolve => {
    npmrc.on('close', resolve)
  })

  const secretsFile = fs.createWriteStream(\`\${__dirname}/.secrets\`)
  secretsFile.write(\`AWS_ACCESS_KEY_ID=\${awsCreds.accessKeyId}\\n\`)
  secretsFile.write(\`AWS_SECRET_ACCESS_KEY=\${awsCreds.secretAccessKey}\\n\`)
  secretsFile.write(\`AWS_REGION=\${awsCreds.region}\\n\`)

  if (package.secrets) {
    for (const secretName of package.secrets[env] ?? []) {
      const secret = await secretsManager.getSecret(secretName)
      secretsFile.write(\`\${secretName}=\${secret.SecretString}\\n\`)
    }
  }
  secretsFile.end()

  await new Promise(resolve => {
    secretsFile.on('close', resolve)
  })

  const docker = new Docker({ apiVersion: '1.44' })

  const ecr = new ECR({ ...awsCreds })

  const serviceRepository = \`\${monorepoPackage.name}/\${package.name}\`
  const image = \`\${serviceRepository}:\${package.version}\`

  const DockerfilePath = process.argv.includes('--Dockerfile')
    ? process.argv[process.argv.indexOf('--Dockerfile') + 1]
    : 'Dockerfile'

  const buildStream = await docker.buildImage(__dirname, {
    ignore: ['.github', 'node_modules', 'build-push', 'deploy', 'test.js'],
    image,
    platform: 'x86_64',
    archiveDockerfile: DockerfilePath,
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

  await fs.promises.writeFile(`${__dirname}/${serviceName}/Dockerfile`, `
FROM ${baseImage}
WORKDIR /home/node
COPY . .
RUN apk add curl \\
  && npm i \\
  && chmod +x ./run.sh \\
  && rm .npmrc \\
  && rm Dockerfile
USER node
  `.trim())

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

  const serviceName = package.name.toLowerCase().replace(/[^a-z0-9]/g, '-')
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

  console.log(\`Deploying \${serviceName}@\${package.version}...\`)
  try {
    await docker.createService(serviceName, serviceOptions)
  } catch (_error) {
    await docker.updateService(serviceName, serviceOptions)
  }
})
  `.trim())

  await fs.promises.chmod(`${__dirname}/${serviceName}/deploy.sh`, 0o755)

  const allocatePort = process.argv.indexOf('--allocate-port') > 0
  if (allocatePort) {
    console.log('Allocating port...')

    const ports = require('./ports.json')
    if (serviceName in ports) {
      throw new Error(`Service ${serviceName} is already in ports.json.`)
    }

    const maximumPort = Math.max(...Object.values(ports))
    if (maximumPort + 1 > 65535) {
      throw new Error('Maximum port reached in ports.json.')
    }

    ports[serviceName] = maximumPort + 1

    await fs.promises.writeFile(
      `${__dirname}/ports.json`,
      JSON.stringify(ports, null, 2)
    )
  }
})
