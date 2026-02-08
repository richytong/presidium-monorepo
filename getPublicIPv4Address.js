const os = require('os')

function getPublicIPv4Address() {
  const interfaces = os.networkInterfaces();
  for (const name in interfaces) {
    const networkInterface = interfaces[name];
    for (const iface of networkInterface) {
      // Filter for IPv4 addresses that are not internal (e.g., not loopback)
      if (iface.family === 'IPv4' && !iface.internal) {
        return iface.address;
      }
    }
  }
  return null; // Return null if no such address is found
}

module.exports = getPublicIPv4Address
