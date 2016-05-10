
# this implementation is largely derived from the following code
#   https://github.com/scala/scala/blob/2.11.x/src/library/scala/util/hashing/MurmurHash3.scala
#
#
do ->
  BUF   = new ArrayBuffer(8)
  NUM32 = new Float32Array(BUF)
  NUM64 = new Float64Array(BUF)
  BITS  = new Uint32Array(BUF)

  # a register that can do proper unsigned math
  # - index 0       reserved for [k]
  # - index 1       reserved for [hash]
  # - index [2..N]  scratch space
  REG   = new Uint32Array(4)

  # constants stored as proper unsigned values
  CONST = new Uint32Array(8)
  CONST[0] = 0xCC9E2D51 # c1
  CONST[1] = 0x1B873593 # c2
  CONST[2] = 5          # m
  CONST[3] = 0xE6546B64 # n
  CONST[4] = 0x85EBCA6B # final(1)
  CONST[5] = 0xC2B2AE35 # final(2)
  CONST[6] = 0xDEADBEEF # seed
  CONST[7] = 0xFFFFFFFF # max int

  # XXX - Math.imul gives correct answers...whereas the fallback may not...
  imul = Math.imul || (a,b) -> (a|0)*(b|0)

  hashInPlace = ->
#console.log("k  = ?",REG[0].toString(16))
    REG[0]  = imul(REG[0],CONST[0])
#console.log("k *= 0xcc9e2d51",REG[0].toString(16))
    REG[2]  = REG[0] << 15
    REG[3]  = REG[0] >>> -15
    REG[0]  = REG[2] | REG[3]
#console.log("k  = rotl(k,15)",REG[0].toString(16))
    REG[0]  = imul(REG[0],CONST[1])
#console.log("k *= 0x1b873593",REG[0].toString(16))
    REG[1] ^= REG[0]
#console.log("hash ^= k",REG[1].toString(16))
    REG[2]  = REG[1] << 13
    REG[3]  = REG[1] >>> -13
    REG[1]  = REG[2] | REG[3]
#console.log("hash  = rotl(h,13)",REG[1].toString(16))
    REG[1]  = imul(REG[1],CONST[2])
    REG[1] += CONST[3] # put the result in REG[1] for cascading calls to hashInPlace()
#console.log("hash  = hash * 5 + 0xe6546b64",REG[1].toString(16))
    return

  finishInPlace = ->
#console.log("hash  = ?",REG[1].toString(16))
    REG[2]  = REG[1] >>> 16
    REG[1] ^= REG[2]
#console.log("hash ^= hash >>> 16",REG[1].toString(16))
    REG[1]  = imul(REG[1],CONST[4])
#console.log("hash *= 0x85ebca6",REG[1].toString(16))
    REG[2]  = REG[1] >>> 13
    REG[1] ^= REG[2]
#console.log("hash ^= hash >>> 13",REG[1].toString(16))
    REG[1]  = imul(REG[1],CONST[5])
#console.log("hash *= 0xc2b2ae35",REG[1].toString(16))
    REG[2]  = REG[1] >>> 16
    REG[1] ^= REG[2]
#console.log("hash ^= hash >>> 16",REG[1].toString(16))
    return

  mix = (hash,data) ->
    REG[0] = (data|0)
    REG[1] = (hash|0)
    hashInPlace()
    return REG[1]

  finalize = (hash) ->
    REG[1] = (hash|0)
    finishInPlace()
    return REG[1]

  hashNumber = (number) ->
    if 0 == ((number|0) % 1)
      if CONST[7] > (number|0)
#console.log("number is int32",number)
        return hashInt32(number|0)
      else
#console.log("number is int64",number)
        return hashInt64(number|0)
    else
#console.log("number is float64",number)
      return hashFloat64(number|0)

  hashInt32 = (number) ->
    REG[1] = CONST[6]
    REG[0] = (number|0)
    hashInPlace()
    finishInPlace()
    return REG[1]

  hashInt64 = (number) ->
    REG[1] = CONST[6]
    s = (number).toString(16)
    REG[0] = (parseInt("0x#{s.slice(0,8)}")|0)
    hashInPlace()
    REG[0] = (parseInt("0x#{s.slice(8)}")|0)
    hashInPlace()
    finishInPlace()
    return REG[1]

  hashFloat32 = (number) ->
    REG[1] = CONST[6]
    NUM32[0] = (+number)
    REG[0] = BITS[0]
    hashInPlace()
    finishInPlace()
    return REG[1]

  hashFloat64 = (number) ->
    REG[1] = CONST[6]
    NUM64[0] = (+number)
    REG[0] = BITS[0]
    hashInPlace()
    REG[0] = BITS[1]
    hashInPlace()
    finishInPlace()
    return REG[1]

  hashDate = (date) ->
    return hashInt64(date.getTime())

  hashString = (string) ->
    REG[1] = CONST[6]
    length = string.length
    for i in [0...length] by 1
      REG[0] = (string.charAt(i)|0)
      hashInPlace()
    REG[1] ^= (length|0)
    finishInPlace()
    return REG[1]

  hashTypedArray = (array) ->
    return hashArrayBuffer(array.buffer)

  hashArrayBuffer = (buffer) ->
    REG[1] = CONST[6]
    bytes = new Uint8Array(buffer)
    length = bytes.length
    for i in [0...length] by 1
      REG[0] = (bytes[i]|0)
      hashInPlace()
    REG[1] ^= (length|0)
    finishInPlace()
    return REG[1]

  root = typeof self == 'object' and self.self == self and self or typeof global == 'object' and global.global == global && global || this
  if (typeof module != "undefined" && module != null) and !module.nodeType
    exports = module.exports = {}
  else
    exports = root.murmurhash = {}

  exports["mix"]              = mix
  exports["finalize"]         = finalize
  exports["hashNumber"]       = hashNumber
  exports["hashInt32"]        = hashInt32
  exports["hashInt64"]        = hashInt64
  exports["hashFloat32"]      = hashFloat32
  exports["hashFloat64"]      = hashFloat64
  exports["hashDate"]         = hashDate
  exports["hashString"]       = hashString
  exports["hashTypedArray"]   = hashTypedArray
  exports["hashArrayBuffer"]  = hashArrayBuffer

