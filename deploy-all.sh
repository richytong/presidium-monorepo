#!/usr/bin/env node

if (!process.env.NODE_ENV) {
  throw new Error('NODE_ENV required')
}

