/**
 * @module Crypto
 *
 * Some high-level methods around the `crypto.subtle`API for getting
 * random bytes and hashing.
 */

import { toBuffer } from './util.js'
import { Buffer } from './buffer.js'
import console from './console.js'

import * as exports from './crypto.js'

const sodium = {
  ready: new Promise((resolve) => {
    import('./crypto/sodium.js').then((module) => {
      Object.assign(sodium, module.default.libsodium)
      resolve()
    })
  })
}

/**
 * libsodium API
 * @see {https://doc.libsodium.org/}
 * @see {https://github.com/jedisct1/libsodium.js}
 */
export { sodium }

/**
 * WebCrypto API
 * @see {https://developer.mozilla.org/en-US/docs/Web/API/Crypto}
 */
export const webcrypto = globalThis.crypto?.webcrypto ?? globalThis.crypto

/**
 * Generate cryptographically strong random values into the `buffer`
 * @param {TypedArray} buffer
 * @see {@link https://developer.mozilla.org/en-US/docs/Web/API/Crypto/getRandomValues}
 * @return {TypedArray}
 */
export function getRandomValues (buffer, ...args) {
  if (typeof webcrypto?.getRandomValues === 'function') {
    return webcrypto?.getRandomValues(buffer, ...args)
  }

  if (sodium.libsodium.randombytes_buf) {
    const input = toBuffer(sodium.libsodium.randombytes_buf(buffer.byteLength))
    const output = toBuffer(buffer)
    input.copy(output)
    return buffer
  }

  console.warn('Missing implementation for window.crypto.getRandomValues()')
  return null
}

// so this is re-used instead of creating new one each rand64() call
const tmp = new Uint32Array(2)

export function rand64 () {
  getRandomValues(tmp)
  return (BigInt(tmp[0]) << 32n) | BigInt(tmp[1])
}

/**
 * Maximum total size of random bytes per page
 */
export const RANDOM_BYTES_QUOTA = 64 * 1024

/**
 * Maximum total size for random bytes.
 */
export const MAX_RANDOM_BYTES = 0xFFFF_FFFF_FFFF

/**
 * Maximum total amount of allocated per page of bytes (max/quota)
 */
export const MAX_RANDOM_BYTES_PAGES = MAX_RANDOM_BYTES / RANDOM_BYTES_QUOTA
// note: should it do Math.ceil() / Math.round()?

/**
 * Generate `size` random bytes.
 * @param {number} size - The number of bytes to generate. The size must not be larger than 2**31 - 1.
 * @returns {Buffer} - A promise that resolves with an instance of socket.Buffer with random bytes.
 */
export function randomBytes (size) {
  const buffers = []

  if (size < 0 || size >= MAX_RANDOM_BYTES || !Number.isInteger(size)) {
    throw Object.assign(new RangeError(
      `The value of "size" is out of range. It must be >= 0 && <= ${MAX_RANDOM_BYTES}. ` +
      `Received ${size}`
    ), {
      code: 'ERR_OUT_OF_RANGE'
    })
  }

  do {
    const length = size > RANDOM_BYTES_QUOTA ? RANDOM_BYTES_QUOTA : size
    let bytes = getRandomValues(new Int8Array(length))
    if (!bytes) {
      bytes = sodium.libsodium.randombytes_buf(length)
    }
    buffers.push(Buffer.from(bytes))
    size = Math.max(0, size - RANDOM_BYTES_QUOTA)
  } while (size > 0)

  return Buffer.concat(buffers)
}

/**
 * @param {string} algorithm - `SHA-1` | `SHA-256` | `SHA-384` | `SHA-512`
 * @param {Buffer | TypedArray | DataView} message - An instance of socket.Buffer, TypedArray or Dataview.
 * @returns {Promise<Buffer>} - A promise that resolves with an instance of socket.Buffer with the hash.
 */
export async function createDigest (algorithm, buf) {
  return Buffer.from(await webcrypto.subtle.digest(algorithm, buf))
}

export default exports
