$ = {}


$.w = w = (string) -> string.trim().split /\s+/


# type - reliable, consistent type function. Adapted from:
# http://coffeescriptcookbook.com/chapters/classes_and_objects/type-function
# See also, of course: http://javascript.crockford.com/remedial.html

classToType = new Object
for name in w "Boolean Number String Function Array Date RegExp"
  classToType["[object " + name + "]"] = name.toLowerCase()

$.type = (object) ->
  return "undefined" if object is undefined
  return "null" if object is null
  myClass = Object.prototype.toString.call object
  if myClass of classToType
    return classToType[myClass]
  else
    return "object"

class Signature 
  
  constructor: -> 
    @signatures = {}
    @failHandler = => false
  
  on: (types,processor) ->
    @signatures[types.join "."] = processor
    @
  
  fail: (handler) =>
    @failHandler = handler
    @

  match: (args) -> 
    types = ($.type arg for arg in args)
    signature = types.join "."
    processor = @signatures[signature]
    if processor?
      processor
    else
      console.log signature
      console.log @signatures
      @failHandler
    
$.overload = (declarations) ->
  signature = (declarations new Signature)
  (args...) ->
    ((signature.match args) args...)

$.Overloading = 
  overload: (name,declarations) ->
    @::[name] = $.overload declarations
    @
    
$.to = (to,from) ->
  if from instanceof to then from else new to from

$.Catalog = 
  messages: {}
  errors: {}
  add: (messages) ->
    for key,fn of messages
      $.Catalog.messages[key] = fn
      $.Catalog.errors[key] = (args...) ->
        new Error fn args...
    $.Catalog

$.message = (key) -> $.Catalog.messages[key]

$.toError = (thing,args...) -> 
  switch ($.type thing)
    when "string"
      if errorFunction = $.Catalog.errors[thing]
        errorFunction args...
      else
        new Error thing
    else
      $.to Error, thing
      
$.throwError = (args...) ->
  throw ($.toError args...)

$.read = (path) -> 
  FileSystem = require "fs"
  FileSystem.readFileSync(path,'utf-8')

$.readdir = (path) -> 
  FileSystem = require "fs"
  FileSystem.readdirSync(path)

$.stat = (path) -> 
  FileSystem = require "fs"
  FileSystem.statSync(path)
  
$.write = (path,content) ->
  FileSystem = require "fs"
  FileSystem.writeFileSync path, content

$.chdir = (dir,fn) ->
  cwd = process.cwd()
  process.chdir dir
  fn()
  process.chdir cwd

$.Catalog.add 
  "requires-node-fibers": (method) -> "Fairmont.#{method} requires node-fibers"
  "no-active-fiber": (method) -> "Fairmont.#{method} requires a currently running Fiber"
    
# Crypto-related

Crypto = require "crypto"

$.md5 = (string) -> Crypto.createHash('md5').update(string,'utf-8').digest("hex")

$.base64 = (string) -> new Buffer(string).toString('base64')

# Attributes  

$.reader = reader = (object,name,fn) ->
  Object.defineProperty object, name,
    configurable: true
    enumerable: true
    get: fn
  object
  
$.writer = writer = (object,name,fn) ->
  Object.defineProperty object, name,
    configurable: true
    enumerable: true
    set: fn
  object

$.Attributes = 

  reader: (name, fn=null) ->
    fn ?= -> @["_#{name}"]
    reader @::, name, fn
    @

  writer: (name, fn=null) ->
    fn ?= (value) -> 
      @["_#{name}"] = value
      value
    writer @::, name, fn
    @

$.include = (object, mixins...) ->

  for mixin in mixins
    for key, value of mixin
      object[key] = value
  object

$.merge = (objects...) ->
  
  destination = {}
  for object in objects
    destination[k] = v for k, v of object
  destination
  
$.delegate = (from,to) ->
  
  for name, value of to when ($.type value) is "function"
    do (value) ->
      from[name] = (args...) -> value.call to, args...

$.abort = -> process.exit -1

# Fibers

# requireFibers = (method) ->
#   try
#     require "fiber"
#   catch e
#     throw $.error["requires-node-fibers"] method
  
assertFiber = (method) ->
  Fiber = requireFibers method
  (throw $.error["no-active-fiber"] method) unless Fiber.current?
  Fiber

$.sync = (fn) ->
  Fiber = assertFiber("sync")
  Future = require "fibers/future"
  fn = Future.wrap fn
  -> fn(arguments...).wait()

$.fiber = (fn) ->
  Fiber = requireFibers("fiber")
  (args...) -> Fiber( -> fn(args...) ).run()

$.sleep = (ms) ->
  Fiber = assertFiber()
  fiber = Fiber.current
  setTimeout (-> fiber.run()), ms
  Fiber.yield()

# Callback Management

$.streamline = (callback) ->
  (fn) ->
    (error,result) ->
      if error
        callback(error)
      else
        fn(result)

$.optimistic = (callback) ->
  (result) ->
    callback null, result
  
$.callbacks = {}

$.callbacks.logError = $.streamline (error) ->
  $.log error if error?

$.callbacks.fatalError = $.streamline (error) ->
  if error?
    $.log error
    $.abort
    
$.log = (thing) ->
  
  if thing instanceof Error
    {name,message} = thing
    process.stderr.write "#{name}: #{message}\n"
  else
    console.log "#{thing}"

$.fatalError = (error) ->
  $.log error
  $.abort()
  
$.memoize = (fn) ->
  memo = {}
  (thing) -> 
    memo[thing] ?= fn(thing)
  
module.exports = $